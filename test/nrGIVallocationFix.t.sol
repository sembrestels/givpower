pragma solidity ^0.8.6;

import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import '../contracts/TokenDistro.sol';

contract TokenDistroTransferAllocation is Test {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMath for uint256;

    address givethMultisig;
    address nrGIVmultisig;
    address givbacksDistributor;
    // deploy the token distro
    TransparentUpgradeableProxy tokenDistroProxy;
    IDistro tokenDistroInterface;
    TokenDistro tokenDistro;
    TokenDistro tokenDistroImplementation;
    uint256 forkBlock = 37740800;
    address[] recipients;
    uint256[] amounts;
    bytes32 distributorRole = 0xfbd454f36a7e1a388bd6fc3ab10d434aa4578f811acbbcf33afb1c697486313c;

    constructor() {
        uint256 forkId = vm.createFork('https://rpc.ankr.com/gnosis', forkBlock); //https://xdai-archive.blockscout.com/
        vm.selectFork(forkId);
        tokenDistro = TokenDistro(address(0xc0dbDcA66a0636236fAbe1B3C16B1bD4C84bB1E1));
        givethMultisig = 0x4D9339dd97db55e3B9bCBE65dE39fF9c04d1C2cd;
        nrGIVmultisig = 0x0018C6413BFE5430ff9ba4bD7ac3B6AA89BEBD9b;
        givbacksDistributor = 0xE053C2fd90eD503CF17F19221AbB49433ffF152B;

    }

    function setUp() public {
        recipients = new address[](4);
        recipients[0] = givbacksDistributor;
        recipients[1] = nrGIVmultisig;
        recipients[2] = givbacksDistributor;
        recipients[3] = nrGIVmultisig;

        amounts = new uint256[](4);
        amounts[0] = 500 * 10**18;
        amounts[1] = 500 * 10**18;
        amounts[2] = 500 * 10**18;
        amounts[3] = 500 * 10**18;
        vm.label(givbacksDistributor, 'givbacksDistributor');
        vm.label(nrGIVmultisig, 'nrGIVmultisig');
        vm.label(givethMultisig, 'givethMultisig');
        vm.label(address(tokenDistro), 'tokenDistro');

    }


    function test_nrGIVallocationFix() public {
        vm.startPrank(givethMultisig);
        tokenDistro.revokeRole(distributorRole, givbacksDistributor);
        tokenDistro.grantRole(distributorRole, nrGIVmultisig);
        vm.stopPrank();

        bool givbacksDistributorRoleBefore = tokenDistro.hasRole(distributorRole, givbacksDistributor);
        bool nrGIVmultisigRoleBefore = tokenDistro.hasRole(distributorRole, nrGIVmultisig);
        assertEq(givbacksDistributorRoleBefore, false);
        assertEq(nrGIVmultisigRoleBefore, true);
        // failing here - says DISTRIBUTOR_CANNOT_CLAIM
        vm.prank(nrGIVmultisig);
        tokenDistro.allocate(givbacksDistributor, 5000000 * 10**18, false);

        vm.startPrank(givethMultisig);
         tokenDistro.revokeRole(distributorRole, nrGIVmultisig);
        tokenDistro.grantRole(distributorRole, givbacksDistributor);
        vm.stopPrank();

        


        vm.prank(nrGIVmultisig);
        tokenDistro.claim();

        vm.prank(givbacksDistributor);
        tokenDistro.allocateMany(recipients, amounts);

        vm.expectRevert();
        vm.prank(givbacksDistributor);
        tokenDistro.claim();

        // should not be distributor anymore
        vm.expectRevert();
        vm.prank(nrGIVmultisig);
        tokenDistro.allocateMany(recipients, amounts);
    }


}