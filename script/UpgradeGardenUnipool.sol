// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import 'forge-std/console.sol';
import 'forge-std/Script.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'contracts/GIVpower.sol';

contract UpgradeGardenUnipool is Script {
    ProxyAdmin gardenUnipoolProxyAdmin;
    TransparentUpgradeableProxy gardenUnipool;
    GIVpower implementation;

    function run() public {
        gardenUnipoolProxyAdmin = ProxyAdmin(address(0x076C250700D210e6cf8A27D1EB1Fd754FB487986));

        gardenUnipool = TransparentUpgradeableProxy(payable(0xD93d3bDBa18ebcB3317a57119ea44ed2Cf41C2F2));

        // new implementation
        implementation = new GIVpower();

        vm.startBroadcast(gardenUnipoolProxyAdmin.owner());

        gardenUnipoolProxyAdmin.upgrade(gardenUnipool, address(implementation));

        vm.stopBroadcast();

        console.log('new implementation address: ', address(implementation));
    }
}
