// SPDX-License-Identifier: GPL-3.0
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

    ProxyAdmin proxyAdmin;
    IERC20Upgradeable givToken;
    address givethMultisig;
    address distributor;
    address firstRecipient;
    address secondRecipient;
    address thirdRecipient;

    // deploy the token distro
    TransparentUpgradeableProxy tokenDistroProxy;
    IDistro tokenDistroInterface;
    TokenDistro tokenDistro;
    TokenDistro tokenDistroImplementation;
    uint256 assignedAmount = 10000000000000000000000000;
    uint256 forkBlock = 22501098;

    constructor() {
        uint256 forkId = vm.createFork('https://rpc.ankr.com/gnosis', forkBlock); //https://xdai-archive.blockscout.com/
        vm.selectFork(forkId);
        proxyAdmin = ProxyAdmin(address(0x076C250700D210e6cf8A27D1EB1Fd754FB487986));
        tokenDistro = TokenDistro(address(0xc0dbDcA66a0636236fAbe1B3C16B1bD4C84bB1E1));
        tokenDistroProxy = TransparentUpgradeableProxy(payable(address(0xc0dbDcA66a0636236fAbe1B3C16B1bD4C84bB1E1)));
        givethMultisig = 0x4D9339dd97db55e3B9bCBE65dE39fF9c04d1C2cd;
        givToken = IERC20Upgradeable(address(0x4f4F9b8D5B4d0Dc10506e5551B0513B61fD59e75));
        distributor = address(5);
        firstRecipient = address(6);
        secondRecipient = address(7);
        thirdRecipient = address(8);
    }

    function setUp() public {
        vm.startPrank(givethMultisig);
        tokenDistroImplementation = new TokenDistro();
        proxyAdmin.upgrade(tokenDistroProxy, address(tokenDistroImplementation));
        tokenDistro.grantRole(keccak256('DISTRIBUTOR_ROLE'), distributor);
        tokenDistro.assign(distributor, assignedAmount);
        vm.stopPrank();

        vm.label(address(tokenDistro), 'tokenDistroContract');
        vm.label(address(tokenDistroImplementation), 'tokenDistroImplementation');
        vm.label(address(tokenDistroProxy), 'tokenDistroProxy');
        vm.label(address(givToken), 'givToken');
        vm.label(address(givethMultisig), 'givethMultisig');
        vm.label(address(distributor), 'distributor');
        vm.label(address(firstRecipient), 'firstRecipient');
        vm.label(address(secondRecipient), 'secondRecipient');
        vm.label(address(thirdRecipient), 'thirdRecipient');
    }

    function testTransferAllocation(uint256 amount1, uint256 amount2, uint256 amount3) public {
        // bound the amounts to be between 1 and 1/3 of the assigned amount so it cannot go over the assigned amount
        amount1 = bound(amount1, 1, assignedAmount.div(3));
        amount2 = bound(amount2, 1, assignedAmount.div(3));
        amount3 = bound(amount3, 1, assignedAmount.div(3));
        // setup the distribution arrays for allocation
        address[] memory recipients = new address[](3);
        recipients[0] = firstRecipient;
        recipients[1] = secondRecipient;
        recipients[2] = thirdRecipient;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = amount1;
        amounts[1] = amount2;
        amounts[2] = amount3;

        // give some starting allocations to the recipients
        vm.prank(distributor);
        tokenDistro.allocateMany(recipients, amounts);

        // save balance values
        (uint256 firstRecipientAllocatedTokens,) = tokenDistro.balances(firstRecipient);
        (uint256 secondRecipientAllocatedTokens,) = tokenDistro.balances(secondRecipient);
        // make first transfer from first recipient to second recipient
        vm.prank(givethMultisig);
        tokenDistro.transferAllocation(firstRecipient, secondRecipient);

        // save balance values after first transfer
        (uint256 secondRecipientAllocatedTokensAfterTransfer,) = tokenDistro.balances(secondRecipient);
        (uint256 firstRecipientAllocatedTokensAfterTransfer,) = tokenDistro.balances(firstRecipient);
        // log some stuff
        console.log('secondRecipientAllocatedTokensAfterTransfer: ', secondRecipientAllocatedTokensAfterTransfer);
        console.log('secondRecipientAllocatedTokens: ', secondRecipientAllocatedTokens);
        console.log('firstRecipientAllocatedTokensAfterTransfer: ', firstRecipientAllocatedTokensAfterTransfer);
        console.log('firstRecipientAllocatedTokens: ', firstRecipientAllocatedTokens);
        // assertions
        assertEq(
            secondRecipientAllocatedTokensAfterTransfer,
            (firstRecipientAllocatedTokens.add(secondRecipientAllocatedTokens))
        );
        assertEq(firstRecipientAllocatedTokensAfterTransfer, 0);

        // do second transfer from second recip to third recip
        vm.prank(givethMultisig);
        tokenDistro.transferAllocation(secondRecipient, thirdRecipient);

        // save balance values after second transfer
        (uint256 thirdRecipientAllocatedTokensAfterTransfer,) = tokenDistro.balances(thirdRecipient);
        (uint256 secondRecipientAllocatedTokensAfterSecondTransfer,) = tokenDistro.balances(secondRecipient);
        // expected amount should be the sum of all three amounts
        uint256 expectedAmount = amount1.add(amount2.add(amount3));
        // log some stuff
        console.log('thirdRecipientAllocatedTokensAfterTransfer: ', thirdRecipientAllocatedTokensAfterTransfer);
        console.log('expectedAmount: ', expectedAmount);
        // assertions
        assertEq(thirdRecipientAllocatedTokensAfterTransfer, expectedAmount);
        assertEq(secondRecipientAllocatedTokensAfterSecondTransfer, 0);
    }

    function testTransferAllocationWithClaim(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 10, (assignedAmount - 1).div(2));
        amount2 = bound(amount2, 10, assignedAmount.div(2));

        address[] memory recipients = new address[](2);
        recipients[0] = firstRecipient;
        recipients[1] = secondRecipient;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        vm.prank(distributor);
        tokenDistro.allocateMany(recipients, amounts);

        // skip ahead some time and then claim tokens
        skip(14 days);
        console.log('claimable for first recipient', tokenDistro.claimableNow(firstRecipient));
        console.log('claimable for second recipient', tokenDistro.claimableNow(secondRecipient));

        vm.prank(firstRecipient);
        tokenDistro.claim();
        vm.prank(secondRecipient);
        tokenDistro.claim();

        // save balance values
        (, uint256 secondRecipientClaimedTokens) = tokenDistro.balances(secondRecipient);
        (, uint256 firstRecipientClaimedTokens) = tokenDistro.balances(firstRecipient);
        // transfer allocation to second recipient
        vm.prank(givethMultisig);
        tokenDistro.transferAllocation(firstRecipient, secondRecipient);
        // check values of second recipient after transfer
        (uint256 secondAllocatedAfterTransfer, uint256 secondClaimedAfterTransfer) =
            tokenDistro.balances(secondRecipient);
        (uint256 firstAllocatedAfterTransfer, uint256 firstClaimedAfterTransfer) = tokenDistro.balances(firstRecipient);
        // assertions
        assertEq(secondAllocatedAfterTransfer, (amount1.add(amount2)));
        assertEq(secondClaimedAfterTransfer, (secondRecipientClaimedTokens.add(firstRecipientClaimedTokens)));
        assertEq(firstAllocatedAfterTransfer, 0);
        assertEq(firstClaimedAfterTransfer, 0);
    }

    function testChangeAddress(uint256 amount1, uint256 amount2, uint256 amount3) public {
        // bound the amounts to be between 1 and 1/3 of the assigned amount so it cannot go over the assigned amount
        amount1 = bound(amount1, 1, assignedAmount.div(3));
        amount2 = bound(amount2, 1, assignedAmount.div(3));
        amount3 = bound(amount3, 1, assignedAmount.div(3));
        // setup the distribution arrays for allocation
        address[] memory recipients = new address[](3);
        recipients[0] = firstRecipient;
        recipients[1] = secondRecipient;
        recipients[2] = thirdRecipient;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = amount1;
        amounts[1] = amount2;
        amounts[2] = amount3;

        // give some starting allocations to the recipients
        vm.prank(distributor);
        tokenDistro.allocateMany(recipients, amounts);

        // save balance values
        (uint256 firstRecipientAllocatedTokens,) = tokenDistro.balances(firstRecipient);
        (uint256 secondRecipientAllocatedTokens,) = tokenDistro.balances(secondRecipient);
        // make first transfer from first recipient to second recipient
        vm.prank(firstRecipient);
        tokenDistro.changeAddress(secondRecipient);

        // save balance values after first transfer
        (uint256 secondRecipientAllocatedTokensAfterTransfer,) = tokenDistro.balances(secondRecipient);
        (uint256 firstRecipientAllocatedTokensAfterTransfer,) = tokenDistro.balances(firstRecipient);
        // log some stuff
        console.log('secondRecipientAllocatedTokensAfterTransfer: ', secondRecipientAllocatedTokensAfterTransfer);
        console.log('secondRecipientAllocatedTokens: ', secondRecipientAllocatedTokens);
        console.log('firstRecipientAllocatedTokensAfterTransfer: ', firstRecipientAllocatedTokensAfterTransfer);
        console.log('firstRecipientAllocatedTokens: ', firstRecipientAllocatedTokens);
        // assertions
        assertEq(
            secondRecipientAllocatedTokensAfterTransfer,
            (firstRecipientAllocatedTokens.add(secondRecipientAllocatedTokens))
        );
        assertEq(firstRecipientAllocatedTokensAfterTransfer, 0);

        // do second transfer from second recip to third recip
        vm.prank(secondRecipient);
        tokenDistro.changeAddress(thirdRecipient);

        // save balance values after second transfer
        (uint256 thirdRecipientAllocatedTokensAfterTransfer,) = tokenDistro.balances(thirdRecipient);
        (uint256 secondRecipientAllocatedTokensAfterSecondTransfer,) = tokenDistro.balances(secondRecipient);
        // expected amount should be the sum of all three amounts
        uint256 expectedAmount = amount1.add(amount2.add(amount3));
        // log some stuff
        console.log('thirdRecipientAllocatedTokensAfterTransfer: ', thirdRecipientAllocatedTokensAfterTransfer);
        console.log('expectedAmount: ', expectedAmount);
        // assertions
        assertEq(thirdRecipientAllocatedTokensAfterTransfer, expectedAmount);
        assertEq(secondRecipientAllocatedTokensAfterSecondTransfer, 0);
    }

    function testChangeAddressWithClaim(uint256 amount1, uint256 amount2) public {
        /// @aminlatifi for some reason this does not want to work with the min bound as 1 - throws no tokens to claim error
        amount1 = bound(amount1, 10, (assignedAmount - 1).div(2));
        amount2 = bound(amount2, 10, assignedAmount.div(2));

        address[] memory recipients = new address[](2);
        recipients[0] = firstRecipient;
        recipients[1] = secondRecipient;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        vm.prank(distributor);
        tokenDistro.allocateMany(recipients, amounts);

        // skip ahead some time and then claim tokens
        skip(14 days);
        console.log('claimable for first recipient', tokenDistro.claimableNow(firstRecipient));
        console.log('claimable for second recipient', tokenDistro.claimableNow(secondRecipient));

        vm.prank(firstRecipient);
        tokenDistro.claim();
        vm.prank(secondRecipient);
        tokenDistro.claim();

        // save balance values
        (, uint256 secondRecipientClaimedTokens) = tokenDistro.balances(secondRecipient);
        (, uint256 firstRecipientClaimedTokens) = tokenDistro.balances(firstRecipient);
        // transfer allocation to second recipient
        vm.prank(firstRecipient);
        tokenDistro.changeAddress(secondRecipient);
        // check values of second recipient after transfer
        (uint256 secondAllocatedAfterTransfer, uint256 secondClaimedAfterTransfer) =
            tokenDistro.balances(secondRecipient);
        (uint256 firstAllocatedAfterTransfer, uint256 firstClaimedAfterTransfer) = tokenDistro.balances(firstRecipient);
        // assertions
        assertEq(secondAllocatedAfterTransfer, (amount1.add(amount2)));
        assertEq(secondClaimedAfterTransfer, (secondRecipientClaimedTokens.add(firstRecipientClaimedTokens)));
        assertEq(firstAllocatedAfterTransfer, 0);
        assertEq(firstClaimedAfterTransfer, 0);
    }
}
