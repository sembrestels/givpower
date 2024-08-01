// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '../interfaces/IDistro.sol';

contract UniswapV3RewardToken is IERC20, OwnableUpgradeable {
    uint256 public initialBalance;

    string public constant name = 'Giveth Uniswap V3 Reward Token';
    string public constant symbol = 'GUR';
    uint8 public constant decimals = 18;

    IDistro public tokenDistro;
    address public uniswapV3Staker;
    uint256 public override totalSupply;

    bool public disabled;

    event RewardPaid(address indexed user, uint256 reward);

    /// @dev Event emitted when an account tried to claim a reward (via calling `trasnfer) while the contract
    // is disabled.
    /// @param user The account that called `transfer`
    /// @param reward The amount that was tried to claim
    event InvalidRewardPaid(address indexed user, uint256 reward);

    /// @dev Event emitted when the contract is disabled
    /// @param account The account that disabled the contract
    event Disabled(address account);

    /// @dev Event emittd when the contract is enabled
    /// @param account The account that enabled the contract
    event Enabled(address account);

    function initialize(IDistro _tokenDistribution, address _uniswapV3Staker) public initializer {
        __Ownable_init();
        tokenDistro = _tokenDistribution;
        uniswapV3Staker = _uniswapV3Staker;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (account == uniswapV3Staker) return totalSupply;
        return 0;
    }

    function approve(address, uint256) external pure override returns (bool) {
        return true;
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        require(msg.sender == uniswapV3Staker, 'GivethUniswapV3Reward:transfer:ONLY_STAKER');

        totalSupply = totalSupply - value;
        if (!disabled) {
            tokenDistro.allocate(to, value, true);
            emit RewardPaid(to, value);
        } else {
            emit InvalidRewardPaid(to, value);
        }

        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        require(from == owner(), 'GivethUniswapV3Reward:transferFrom:ONLY_OWNER_CAN_ADD_INCENTIVES');

        // Only uniswapV3Staker can do the transferFrom
        require(msg.sender == uniswapV3Staker, 'GivethUniswapV3Reward:transferFrom:ONLY_STAKER');

        // Only to uniswapV3Staker is allowed
        require(to == uniswapV3Staker, 'GivethUniswapV3Reward:transferFrom:ONLY_TO_STAKER');

        totalSupply = totalSupply + value;

        emit Transfer(address(0), to, value);
        return true;
    }

    function allowance(address, address spender) external view override returns (uint256) {
        if (spender == uniswapV3Staker) return type(uint256).max;
        return 0;
    }

    /// @notice Disable the token. If disabled, rewards are not payable.
    /// @dev Can only be called by the Owner.
    function disable() external onlyOwner {
        disabled = true;
        emit Disabled(msg.sender);
    }

    /// @notice Enable the token. If enabled, rewards are payable.
    /// @dev Can only be called by the Owner.
    function enable() external onlyOwner {
        disabled = false;
        emit Enabled(msg.sender);
    }
}
