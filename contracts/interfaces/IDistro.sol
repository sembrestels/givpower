// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.10;

interface IDistro {
    /**
     * @dev Emitted when someone makes a claim of tokens
     */
    event Claim(address indexed grantee, uint256 amount);
    /**
     * @dev Emitted when the DISTRIBUTOR allocate an amount to a grantee
     */
    event Allocate(address indexed distributor, address indexed grantee, uint256 amount);
    /**
     * @dev Emitted when the DEFAULT_ADMIN assign an amount to a DISTRIBUTOR
     */
    event Assign(address indexed admin, address indexed distributor, uint256 amount);
    /**
     * @dev Emitted when someone change their reception address
     */
    event ChangeAddress(address indexed oldAddress, address indexed newAddress);

    /**
     * @dev Emitted when a new startTime is set
     */
    event StartTimeChanged(uint256 newStartTime, uint256 newCliffTime);

    /**
     * @dev Returns the total amount of tokens will be streamed
     */
    function totalTokens() external view returns (uint256);

    /**
     * Function that allows the DEFAULT_ADMIN_ROLE to assign set a new startTime if it hasn't started yet
     * @param newStartTime new startTime
     *
     * Emits a {StartTimeChanged} event.
     *
     */
    function setStartTime(uint256 newStartTime) external;

    /**
     * Function that allows the DEFAULT_ADMIN_ROLE to assign tokens to an address who later can distribute them.
     * @dev It is required that the DISTRIBUTOR_ROLE is already held by the address to which an amount will be assigned
     * @param distributor the address, generally a smart contract, that will determine who gets how many tokens
     * @param amount Total amount of tokens to assign to that address for distributing
     */
    function assign(address distributor, uint256 amount) external;

    /**
     * Function to claim tokens for a specific address. It uses the current timestamp
     */
    function claim() external;

    /**
     * Function that allows to the distributor address to allocate some amount of tokens to a specific recipient
     * @dev Needs to be initialized: Nobody has the DEFAULT_ADMIN_ROLE and all available tokens have been assigned
     * @param recipient of token allocation
     * @param amount allocated amount
     * @param claim whether claim after allocate
     */
    function allocate(address recipient, uint256 amount, bool claim) external;

    /**
     * Function that allows to the distributor address to allocate some amounts of tokens to specific recipients
     * @dev Needs to be initialized: Nobody has the DEFAULT_ADMIN_ROLE and all available tokens have been assigned
     * @param recipients of token allocation
     * @param amounts allocated amount
     */
    function allocateMany(address[] memory recipients, uint256[] memory amounts) external;

    function sendGIVbacks(address[] memory recipients, uint256[] memory amounts) external;

    function sendPraiseRewards(address[] memory recipients, uint256[] memory amounts) external;

    /**
     * Function that allows a recipient to change its address
     * @dev The change can only be made to an address that has not previously received an allocation &
     * the distributor cannot change its address
     */
    function changeAddress(address newAddress) external;

    /**
     * Function to get the current timestamp from the block
     */
    function getTimestamp() external view returns (uint256);

    /**
     * Function to get the total unlocked tokes at some moment
     */
    function globallyClaimableAt(uint256 timestamp) external view returns (uint256);

    /**
     * Function to get the unlocked tokes at some moment for a specific address
     */
    function claimableAt(address recipient, uint256 timestamp) external view returns (uint256);

    /**
     * Function to get the unlocked tokens for a specific address. It uses the current timestamp
     */
    function claimableNow(address recipient) external view returns (uint256);

    function transferAllocation(address prevRecipient, address newRecipient) external;
}
