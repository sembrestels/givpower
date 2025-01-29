// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import 'forge-std/console.sol';
import 'forge-std/Script.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'contracts/GIVbacksRelayer.sol';
import 'contracts/TokenDistro.sol';

contract deployRelayer is Script {
    GIVbacksRelayer implementation;
    GIVbacksRelayer givbacksRelayer;
    ProxyAdmin masterProxyAdmin;
    ProxyAdmin givpowerProxyAdmin;
    ProxyAdmin givbacksRelayerProxyAdmin;
    TransparentUpgradeableProxy givbacksRelayerProxy;
    TransparentUpgradeableProxy givpowerProxy;
    // token distro address

    function run() external {
        uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

        vm.startBroadcast(deployerPrivateKey);
        ProxyAdmin masterProxyAdmin = ProxyAdmin(0x2f2c819210191750F2E11F7CfC5664a0eB4fd5e6);
        ProxyAdmin givpowerProxyAdmin = ProxyAdmin(0x383C34c04cA46A322454Ff483EA8Ccc16bC34434);
        ProxyAdmin givbacksRelayerProxyAdmin = ProxyAdmin(0x9194B6CcdBD27bD3738772eFFf3DD571A9bACbBd);
        TransparentUpgradeableProxy givpowerProxy =
            TransparentUpgradeableProxy(payable(0x301C739CF6bfb6B47A74878BdEB13f92F13Ae5E7));
        TransparentUpgradeableProxy givbacksRelayerProxy =
            TransparentUpgradeableProxy(payable(0xf13e93aF5e706AB3073E393e77bb2d7ce7BEc01f));

        givpowerProxyAdmin.changeProxyAdmin(givpowerProxy, address(masterProxyAdmin));
        givbacksRelayerProxyAdmin.changeProxyAdmin(givbacksRelayerProxy, address(masterProxyAdmin));
    }
}
