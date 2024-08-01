// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import 'forge-std/console.sol';
import 'forge-std/Script.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'contracts/UnipoolGIVpower.sol';

contract deployUnipoolGIVpower is Script {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    UnipoolGIVpower implementation;
    UnipoolGIVpower givPower;
    // ProxyAdmin unipoolGIVpowerProxyAdmin;
    TransparentUpgradeableProxy unipoolGIVpowerProxy;
    IERC20Upgradeable givToken;
    IDistro iDistro;

    // token
    // address givTokenAddressOptimismGoerli = 0xc916Ce4025Cb479d9BA9D798A80094a449667F5D;
    address givTokenAddressOptimismSepolia = 0x2f2c819210191750F2E11F7CfC5664a0eB4fd5e6;
    // address tokenDistroOptimismMainnet = 0xE3Ac7b3e6B4065f4765d76fDC215606483BF3bD1;
    address tokenDistroOptimismSepolia = 0x301C739CF6bfb6B47A74878BdEB13f92F13Ae5E7;
    ProxyAdmin unipoolGIVpowerProxyAdmin = ProxyAdmin(address(0x3b197F5cDa3516bD49e193df6F1273f3f16d414a));

    function run() external {
        uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

        vm.startBroadcast(deployerPrivateKey);
        givToken = IERC20Upgradeable(givTokenAddressOptimismSepolia);
        iDistro = IDistro(tokenDistroOptimismSepolia);
        // unipoolGIVpowerProxyAdmin = new ProxyAdmin();
        // new implementation
        implementation = new UnipoolGIVpower();
        unipoolGIVpowerProxy = new TransparentUpgradeableProxy(
            payable(address(implementation)),
            address(unipoolGIVpowerProxyAdmin),
            abi.encodeWithSelector(UnipoolGIVpower(givPower).initialize.selector, iDistro, givToken, 14 days)
        );
        // givPower = UnipoolGIVpower(address(unipoolGIVpowerProxy));

        // console.log('unipoolproxyadmin' , address(unipoolGIVpowerProxyAdmin));
        // console.log('givpower', address(givPower));
        console.log('givpower implementation', address(implementation));
    }
}
