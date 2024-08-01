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
    ProxyAdmin givbacksRelayerProxyAdmin;
    TransparentUpgradeableProxy givbacksRelayerProxy;
    IDistro iDistro;
    TokenDistro tokenDistro;

    // token distro address
    address tokenDistroAddress = 0xE3Ac7b3e6B4065f4765d76fDC215606483BF3bD1;
    // admin of contract who is allowed to add batchers
    // address givethMultiSig = 0x4D9339dd97db55e3B9bCBE65dE39fF9c04d1C2cd;
    address deployer = 0xe1ce7720f9b434ec98382f776e5C3A48C8BA6673;
    // address of initial batcher - should be agent or multisig who will be approving sending GIVbacks
    address batcherAgent = 0xB99Aae15ACE6509930760f1bde96c60542d2c0c1;
    address batcherApp = 0xe8E7b58Fe406893986C33DdB809538b6c988680b;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

        vm.startBroadcast(deployerPrivateKey);
        tokenDistro = TokenDistro(tokenDistroAddress);
        givbacksRelayerProxyAdmin = new ProxyAdmin();
        // new implementation
        implementation = new GIVbacksRelayer();
        givbacksRelayerProxy = new TransparentUpgradeableProxy(
            payable(address(implementation)),
            address(givbacksRelayerProxyAdmin),
            abi.encodeWithSelector(
                GIVbacksRelayer(givbacksRelayer).initialize.selector, tokenDistro, deployer, batcherAgent
            )
        );
        givbacksRelayer = GIVbacksRelayer(address(givbacksRelayerProxy));
        tokenDistro.grantRole(keccak256('DISTRIBUTOR_ROLE'), address(givbacksRelayer));
        tokenDistro.assign(address(givbacksRelayer), 2500000 ether);
        tokenDistro.revokeRole(keccak256('DISTRIBUTOR_ROLE'), address(batcherApp));
        tokenDistro.transferAllocation(address(batcherApp), 0x0000000000000000000000000000000000000000);

        console.log('proxy admin', address(givbacksRelayerProxyAdmin));
        console.log('givbacks relayer', address(givbacksRelayer));
        console.log('givbacks relayer implementation', address(implementation));
    }
}
