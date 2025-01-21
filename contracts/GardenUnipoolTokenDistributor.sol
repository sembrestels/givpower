/**
 * Contract has the most of the functionalities of UnipoolTokenDistributor contract, but is updated
 * to be compatible with token-manager-app of 1Hive.
 * 1. Stake/Withdraw methods are updated to internal type.
 * 2. Methods related to permit are removed.
 * 3. Stake/Withdraw are update based on 1Hive unipool (https://github.com/1Hive/unipool/blob/master/contracts/Unipool.sol).
 * This PR was the guide: https://github.com/1Hive/unipool/pull/7/files
 */

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol';
import './interfaces/IDistro.sol';
import './TokenManagerHook.sol';

// Based on: https://github.com/Synthetixio/Unipool/tree/master/contracts
/*
 * changelog:
 *      * Added SPDX-License-Identifier
 *      * Update to solidity ^0.8.0
 *      * Update openzeppelin imports
 *      * IRewardDistributionRecipient integrated in Unipool and removed
 *      * Added virtual and override to stake and withdraw methods
 *      * Added constructors to LPTokenWrapper and Unipool
 *      * Change transfer to allocate (TokenVesting)
 *      * Added `stakeWithPermit` function for NODE and the BridgeToken
 */
contract LPTokenWrapper is Initializable {
    using SafeMathUpgradeable for uint256;

    uint256 private _totalStaked;
    mapping(address => uint256) private _balances;

    function __LPTokenWrapper_initialize() public initializer {}

    function _totalSupply() internal view returns (uint256) {
        return _totalStaked;
    }

    function _balanceOf(address account) internal view returns (uint256) {
        return _balances[account];
    }

    function stake(address user, uint256 amount) internal virtual {
        _totalStaked = _totalStaked.add(amount);
        _balances[user] = _balances[user].add(amount);
    }

    function withdraw(address user, uint256 amount) internal virtual {
        _totalStaked = _totalStaked.sub(amount);
        _balances[user] = _balances[user].sub(amount);
    }
}

contract GardenUnipoolTokenDistributor is LPTokenWrapper, TokenManagerHook, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    IDistro public tokenDistro;
    uint256 public duration;

    address public rewardDistribution;
    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    modifier onlyRewardDistribution() {
        require(_msgSender() == rewardDistribution, 'Caller is not reward distribution');
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = claimableStream(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function initialize(IDistro _tokenDistribution, uint256 _duration, address tokenManager) public initializer {
        __Ownable_init();
        __LPTokenWrapper_initialize();
        __TokenManagerHook_initialize(tokenManager);
        tokenDistro = _tokenDistribution;
        duration = _duration;
        periodFinish = 0;
        rewardRate = 0;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return MathUpgradeable.min(getTimestamp(), periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored.add(
            lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply())
        );
    }

    /**
     * Function to get the current timestamp from the block
     */
    function getTimestamp() public view virtual returns (uint256) {
        return block.timestamp;
    }

    /**
     * Function to get the amount of tokens is transferred in the claim tx
     * @notice The difference between what this returns and what the claimableStream function returns
     * will be locked in TokenDistro to be streamed and released gradually
     */
    function earned(address account) external view returns (uint256) {
        uint256 _totalEarned = claimableStream(account);
        uint256 _tokenDistroReleasedTokens = tokenDistro.globallyClaimableAt(getTimestamp());
        uint256 _tokenDistroTotalTokens = tokenDistro.totalTokens();

        return (_totalEarned * _tokenDistroReleasedTokens) / _tokenDistroTotalTokens;
    }

    // @dev This does the same thing the earned function of UnipoolTokenDistributor contract does.
    // Returns the exact amount will be allocated on TokenDistro
    function claimableStream(address account) public view returns (uint256) {
        return _balanceOf(account).mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(
            rewards[account]
        );
    }

    function stake(address user, uint256 amount) internal override updateReward(user) {
        require(amount > 0, 'Cannot stake 0');
        super.stake(user, amount);
        emit Staked(user, amount);
    }

    function withdraw(address user, uint256 amount) internal override updateReward(user) {
        require(amount > 0, 'Cannot withdraw 0');
        super.withdraw(user, amount);
        if (_balanceOf(user) == 0) {
            _getReward(user);
        }
        emit Withdrawn(user, amount);
    }

    function getReward() public updateReward(msg.sender) {
        _getReward(msg.sender);
    }

    function _getReward(address user) internal {
        uint256 reward = claimableStream(user);
        if (reward > 0) {
            rewards[user] = 0;
            //token.safeTransfer(msg.sender, reward);
            tokenDistro.allocate(user, reward, true);
            emit RewardPaid(user, reward);
        }
    }

    function notifyRewardAmount(uint256 reward) external onlyRewardDistribution updateReward(address(0)) {
        uint256 _timestamp = getTimestamp();
        uint256 _reward;
        if (_timestamp >= periodFinish) {
            _reward = reward;
        } else {
            uint256 remaining = periodFinish.sub(_timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            _reward = reward.add(leftover);
        }

        (bool success, bytes memory data) =
            address(tokenDistro).call(abi.encodeWithSignature('balances(address)', address(this)));
        require(success, 'UnipoolTokenDistributor: CALL_FAILED');
        (uint256 allocatedTokens,) = abi.decode(data, (uint256, uint256));

        require(allocatedTokens >= _reward, 'UnipoolTokenDistributor: NOT_ENOUGH_TOKEND_ISTRO_BALANCE');

        rewardRate = _reward.div(duration);
        lastUpdateTime = _timestamp;
        periodFinish = _timestamp.add(duration);
        emit RewardAdded(reward);
    }

    function setRewardDistribution(address _rewardDistribution) external onlyOwner {
        rewardDistribution = _rewardDistribution;
    }

    /**
     * @dev Overrides TokenManagerHook's `_onTransfer`
     * @notice this function is a complete copy/paste from
     * https://github.com/1Hive/unipool/blob/master/contracts/Unipool.sol
     */
    function _onTransfer(address _from, address _to, uint256 _amount) internal virtual override returns (bool) {
        if (_from == address(0)) {
            // Token mintings (wrapping tokens)
            stake(_to, _amount);
            return true;
        } else if (_to == address(0)) {
            // Token burning (unwrapping tokens)
            withdraw(_from, _amount);
            return true;
        } else {
            // Standard transfer
            withdraw(_from, _amount);
            stake(_to, _amount);
            return true;
        }
    }
}
