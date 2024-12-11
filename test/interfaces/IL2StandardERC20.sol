// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.10;

import '@openzeppelin/contracts/interfaces/IERC20.sol';

interface IL2StandardERC20 is IERC20 {
    function mint(address, uint256) external;
    function burn(address, uint256) external;
}
