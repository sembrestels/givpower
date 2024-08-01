// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import './interfaces/IDistro.sol';

/**
 * Contract responsible for managing the release of tokens over time.
 * The distributor is in charge of releasing the corresponding amounts to its recipients.
 * This distributor is expected to be another smart contract, such as a merkledrop or the liquidity mining smart contract
 */
contract TokenDistro is Initializable, IDistro, AccessControlEnumerableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = 0xfbd454f36a7e1a388bd6fc3ab10d434aa4578f811acbbcf33afb1c697486313c;

    // Structure to of the accounting for each account
    struct accountStatus {
        uint256 allocatedTokens;
        uint256 claimed;
    }

    mapping(address => accountStatus) public balances; // Mapping with all accounts that have received an allocation

    uint256 public override totalTokens; // total tokens to be distribute
    uint256 public startTime; // Instant of time in which distribution begins
    uint256 public cliffTime; // Instant of time in which tokens will begin to be released
    uint256 public duration;
    uint256 public initialAmount; // Initial amount that will be available from startTime
    uint256 public lockedAmount; // Amount that will be released over time from cliffTime

    IERC20Upgradeable public token; // Token to be distribute
    bool public cancelable; // Variable that allows the ADMIN_ROLE to cancel an allocation

    /**
     * @dev Emitted when the DISTRIBUTOR allocate an amount of givBack to a recipient
     */
    event GivBackPaid(address distributor);

    /**
     * @dev Emitted when the DISTRIBUTOR allocate an amount of praise rewards to a recipient
     */
    event PraiseRewardPaid(address distributor);

    /**
     * @dev Emitted when the duration is changed
     */
    event DurationChanged(uint256 newDuration);

    modifier onlyDistributor() {
        require(hasRole(DISTRIBUTOR_ROLE, msg.sender), 'TokenDistro::onlyDistributor: ONLY_DISTRIBUTOR_ROLE');

        require(balances[msg.sender].claimed == 0, 'TokenDistro::onlyDistributor: DISTRIBUTOR_CANNOT_CLAIM');
        _;
    }

    /**
     * @dev Initially the deployer of the contract will be able to assign the tokens to one or several addresses,
     *      these addresses (EOA or Smart Contracts) are responsible to allocate tokens to specific addresses which can
     *      later claim them
     * @param _totalTokens Total amount of tokens to distribute
     * @param _startTime Unix time that the distribution begins
     * @param _cliffPeriod Number of seconds to delay the claiming period for the tokens not initially released
     * @param _duration Time it will take for all tokens to be distributed
     * @param _initialPercentage Percentage of tokens initially released (2 decimals, 1/10000)
     * @param _token Address of the token to distribute
     * @param _cancelable In case the owner wants to have the power to cancel an assignment
     */
    function initialize(
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _cliffPeriod,
        uint256 _duration,
        uint256 _initialPercentage,
        IERC20Upgradeable _token,
        bool _cancelable
    ) public initializer {
        require(_duration >= _cliffPeriod, 'TokenDistro::constructor: DURATION_LESS_THAN_CLIFF');
        require(_initialPercentage <= 10000, 'TokenDistro::constructor: INITIALPERCENTAGE_GREATER_THAN_100');
        __AccessControlEnumerable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        uint256 _initialAmount = (_totalTokens * _initialPercentage) / 10000;

        token = _token;
        duration = _duration;
        startTime = _startTime;
        totalTokens = _totalTokens;
        initialAmount = _initialAmount;
        cliffTime = _startTime + _cliffPeriod;
        lockedAmount = _totalTokens - _initialAmount;
        balances[address(this)].allocatedTokens = _totalTokens;
        cancelable = _cancelable;
    }

    /**
     * Function that allows the DEFAULT_ADMIN_ROLE to assign set a new startTime if it hasn't started yet
     * @param newStartTime new startTime
     *
     * Emits a {StartTimeChanged} event.
     *
     */
    function setStartTime(uint256 newStartTime) external override {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'TokenDistro::setStartTime: ONLY_ADMIN_ROLE');
        require(
            startTime > getTimestamp() && newStartTime > getTimestamp(),
            'TokenDistro::setStartTime: IF_HAS_NOT_STARTED_YET'
        );

        uint256 _cliffPeriod = cliffTime - startTime;
        startTime = newStartTime;
        cliffTime = newStartTime + _cliffPeriod;

        emit StartTimeChanged(startTime, cliffTime);
    }

    /**
     * Function that allows the DEFAULT_ADMIN_ROLE to assign tokens to an address who later can distribute them.
     * @dev It is required that the DISTRIBUTOR_ROLE is already held by the address to which an amount will be assigned
     * @param distributor the address, generally a smart contract, that will determine who gets how many tokens
     * @param amount Total amount of tokens to assign to that address for distributing
     *
     * Emits a {Assign} event.
     *
     */
    function assign(address distributor, uint256 amount) external override {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'TokenDistro::assign: ONLY_ADMIN_ROLE');
        require(hasRole(DISTRIBUTOR_ROLE, distributor), 'TokenDistro::assign: ONLY_TO_DISTRIBUTOR_ROLE');

        balances[address(this)].allocatedTokens = balances[address(this)].allocatedTokens - amount;
        balances[distributor].allocatedTokens = balances[distributor].allocatedTokens + amount;

        emit Assign(msg.sender, distributor, amount);
    }

    /**
     * Function to claim tokens for a specific address. It uses the current timestamp
     *
     * Emits a {claim} event.
     *
     */
    function claimTo(address account) external {
        // This check is not necessary as it does not break anything, just changes the claimed value
        // for this contract
        //require(address(this) != account, "TokenDistro::claimTo: CANNOT_CLAIM_FOR_CONTRACT_ITSELF");
        _claim(account);
    }

    /**
     * Function to claim tokens for a specific address. It uses the current timestamp
     *
     * Emits a {claim} event.
     *
     */
    function claim() external override {
        _claim(msg.sender);
    }

    /**
     * Function that allows to the distributor address to allocate some amount of tokens to a specific recipient
     * @param recipient of token allocation
     * @param amount allocated amount
     * @param claim whether claim after allocate
     *
     * Emits a {Allocate} event.
     *
     */
    function _allocate(address recipient, uint256 amount, bool claim) internal {
        require(!hasRole(DISTRIBUTOR_ROLE, recipient), 'TokenDistro::allocate: DISTRIBUTOR_NOT_VALID_RECIPIENT');
        balances[msg.sender].allocatedTokens = balances[msg.sender].allocatedTokens - amount;

        balances[recipient].allocatedTokens = balances[recipient].allocatedTokens + amount;

        if (claim && claimableNow(recipient) > 0) {
            _claim(recipient);
        }

        emit Allocate(msg.sender, recipient, amount);
    }

    function allocate(address recipient, uint256 amount, bool claim) external override onlyDistributor {
        _allocate(recipient, amount, claim);
    }

    /**
     * Function that allows to the distributor address to allocate some amounts of tokens to specific recipients
     * @dev Needs to be initialized: Nobody has the DEFAULT_ADMIN_ROLE and all available tokens have been assigned
     * @param recipients of token allocation
     * @param amounts allocated amount
     *
     * Unlike allocate method it doesn't claim recipients available balance
     */
    function _allocateMany(address[] memory recipients, uint256[] memory amounts) internal onlyDistributor {
        uint256 length = recipients.length;
        require(length == amounts.length, 'TokenDistro::allocateMany: INPUT_LENGTH_NOT_MATCH');

        for (uint256 i = 0; i < length; i++) {
            _allocate(recipients[i], amounts[i], false);
        }
    }

    function allocateMany(address[] memory recipients, uint256[] memory amounts) external override {
        _allocateMany(recipients, amounts);
    }

    function sendGIVbacks(address[] memory recipients, uint256[] memory amounts) external override {
        _allocateMany(recipients, amounts);
        emit GivBackPaid(msg.sender);
    }

    function sendPraiseRewards(address[] memory recipients, uint256[] memory amounts) external override {
        _allocateMany(recipients, amounts);
        emit PraiseRewardPaid(msg.sender);
    }

    /**
     * Function that allows a recipient to change its address
     * @dev The change can only be made to an address that has not previously received an allocation &
     * the distributor cannot change its address
     *
     * Emits a {ChangeAddress} event.
     *
     */
    function changeAddress(address newAddress) external override {
        _transferAllocation(msg.sender, newAddress);
    }

    /**
     * Function to get the current timestamp from the block
     */
    function getTimestamp() public view virtual override returns (uint256) {
        return block.timestamp;
    }

    /**
     * Function to get the total claimable tokens at some moment
     * @param timestamp Unix time to check the number of tokens claimable
     * @return Number of tokens claimable at that timestamp
     */
    function globallyClaimableAt(uint256 timestamp) public view override returns (uint256) {
        if (timestamp < startTime) return 0;
        if (timestamp < cliffTime) return initialAmount;
        if (timestamp > startTime + duration) return totalTokens;

        uint256 deltaTime = timestamp - startTime;
        return initialAmount + (deltaTime * lockedAmount) / duration;
    }

    /**
     * Function to get the unlocked tokes at some moment for a specific address
     * @param recipient account to query
     * @param timestamp Instant of time in which the calculation is made
     */
    function claimableAt(address recipient, uint256 timestamp) public view override returns (uint256) {
        require(!hasRole(DISTRIBUTOR_ROLE, recipient), 'TokenDistro::claimableAt: DISTRIBUTOR_ROLE_CANNOT_CLAIM');
        require(timestamp >= getTimestamp(), 'TokenDistro::claimableAt: NOT_VALID_PAST_TIMESTAMP');
        uint256 unlockedAmount = (globallyClaimableAt(timestamp) * balances[recipient].allocatedTokens) / totalTokens;

        return unlockedAmount - balances[recipient].claimed;
    }

    /**
     * Function to get the unlocked tokens for a specific address. It uses the current timestamp
     * @param recipient account to query
     */
    function claimableNow(address recipient) public view override returns (uint256) {
        return claimableAt(recipient, getTimestamp());
    }

    /**
     * Function that allows the DEFAULT_ADMIN_ROLE to change a recipient in case it wants to cancel an allocation
     * @dev The change can only be made when cancelable is true and to an address that has not previously received
     * an allocation and the distributor cannot change its address
     *
     * Emits a {ChangeAddress} event.
     *
     * Formerly called cancelAllocation, this is an admin only function and should only be called manually
     */
    function transferAllocation(address prevRecipient, address newRecipient) external override {
        require(cancelable, 'TokenDistro::transferAllocation: NOT_CANCELABLE');

        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'TokenDistro::transferAllocation: ONLY_ADMIN_ROLE');
        _transferAllocation(prevRecipient, newRecipient);
    }

    /**
     * Function to claim tokens for a specific address. It uses the current timestamp
     *
     * Emits a {claim} event.
     *
     */
    function _claim(address recipient) private {
        uint256 remainingToClaim = claimableNow(recipient);

        require(remainingToClaim > 0, 'TokenDistro::claim: NOT_ENOUGH_TOKENS_TO_CLAIM');

        balances[recipient].claimed = balances[recipient].claimed + remainingToClaim;

        token.safeTransfer(recipient, remainingToClaim);

        emit Claim(recipient, remainingToClaim);
    }

    /**
     * Function to change the duration
     */
    function setDuration(uint256 newDuration) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'TokenDistro::setDuration: ONLY_ADMIN_ROLE');

        require(startTime > getTimestamp(), 'TokenDistro::setDuration: IF_HAS_NOT_STARTED_YET');

        duration = newDuration;

        emit DurationChanged(newDuration);
    }

    function _transferAllocation(address prevRecipient, address newRecipient) internal {
        require(
            balances[prevRecipient].allocatedTokens > 0, 'TokenDistro::transferAllocation: NO_ALLOCATION_TO_TRANSFER'
        );
        require(
            !hasRole(DISTRIBUTOR_ROLE, prevRecipient) && !hasRole(DISTRIBUTOR_ROLE, newRecipient),
            'TokenDistro::transferAllocation: DISTRIBUTOR_ROLE_NOT_A_VALID_ADDRESS'
        );
        // balance adds instead of overwrites
        balances[newRecipient].allocatedTokens =
            balances[prevRecipient].allocatedTokens + balances[newRecipient].allocatedTokens;
        balances[prevRecipient].allocatedTokens = 0;

        balances[newRecipient].claimed = balances[prevRecipient].claimed + balances[newRecipient].claimed;
        balances[prevRecipient].claimed = 0;

        emit ChangeAddress(prevRecipient, newRecipient);
    }
}
