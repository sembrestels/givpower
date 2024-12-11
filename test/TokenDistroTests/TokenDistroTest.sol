// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10;

import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import 'solmate/utils/FixedPointMathLib.sol';
import '../../contracts/TokenDistro.sol';
import '../interfaces/IL2StandardERC20.sol';

contract TokenDistroTest is Test {
    TokenDistro _tokenDistro;
    IERC20Upgradeable givToken;
    IL2StandardERC20 bridgedGivToken;
    // token
    address givTokenAddressOptimism = 0x528CDc92eAB044E1E39FE43B9514bfdAB4412B98;
    address optimismL2Bridge = 0x4200000000000000000000000000000000000010;
    address tokenDistroAddressOptimism = 0xE3Ac7b3e6B4065f4765d76fDC215606483BF3bD1;
    address givethMultisig = 0x4D9339dd97db55e3B9bCBE65dE39fF9c04d1C2cd;

    constructor() {
        uint256 forkId = vm.createFork('https://mainnet.optimism.io');
        vm.selectFork(forkId);
    }

    function setUp() public virtual {
        _tokenDistro = TokenDistro(tokenDistroAddressOptimism);
        givToken = IERC20Upgradeable(givTokenAddressOptimism);
        bridgedGivToken = IL2StandardERC20(givTokenAddressOptimism);
    }
}
