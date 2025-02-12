// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import 'forge-std/console.sol';
import 'forge-std/Script.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import './hardcode-upgrade/UnipoolGIVpower.sol';
import './hardcode-upgrade/interfaces/IDistro.sol';

contract UpgradeGardenUnipool is Script {
    ProxyAdmin unipoolProxyAdmin;
    TransparentUpgradeableProxy unipoolProxy;
    UnipoolGIVpower implementation;
    UnipoolGIVpower givpower;
    IDistro iDistro;

    function run() public {
        unipoolProxyAdmin = ProxyAdmin(address(0x91c5C402B0B514f2D09d84b03b6C9f17Bd689e2D));
        iDistro = IDistro(address(0x8D2cBce8ea0256bFFBa6fa4bf7CEC46a1d9b43f6));
        unipoolProxy = TransparentUpgradeableProxy(payable(0x632AC305ed88817480d12155A7F1244cC182C298));
        givpower = UnipoolGIVpower(address(unipoolProxy));
        // new implementation

        uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

        vm.startBroadcast(deployerPrivateKey);
        implementation = new UnipoolGIVpower();

        unipoolProxyAdmin.upgrade(unipoolProxy, address(implementation));
        givpower.setTokenDistro(iDistro);

        vm.stopBroadcast();

        console.log('new implementation address: ', address(implementation));
    }
}
