// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10;

import 'forge-std/console.sol';
import './TokenDistroTest.sol';

contract TokenDistroClaimTest is TokenDistroTest {
    address _distributor = address(0x1);
    address _recipient = address(0x2);

    uint256 _amount = 100 ether;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public override {
        super.setUp();

        vm.startPrank(givethMultisig);
        _tokenDistro.grantRole(_tokenDistro.DISTRIBUTOR_ROLE(), _distributor);
        _tokenDistro.assign(_distributor, _amount);
        vm.stopPrank();

        vm.startPrank(_distributor);
        _tokenDistro.allocate(_recipient, 100, false);
        vm.stopPrank();
    }

    function testSuccessfulClaimWithEnoughGIV() public {
        vm.startPrank(optimismL2Bridge);
        bridgedGivToken.mint(tokenDistroAddressOptimism, _amount);
        vm.stopPrank();

        assertGe(bridgedGivToken.balanceOf(tokenDistroAddressOptimism), _amount);

        vm.startPrank(_recipient);
        // test it was successful claim with GIV transfer
        vm.expectEmit(true, true, true, false);
        emit Transfer(tokenDistroAddressOptimism, _recipient, _amount);
        _tokenDistro.claim();
        vm.stopPrank();
    }

    // test token distro balance is zero
    function testRevertWithNotEnoughGIV() public {
        // burn all token distro balance
        vm.startPrank(optimismL2Bridge);
        bridgedGivToken.burn(tokenDistroAddressOptimism, bridgedGivToken.balanceOf(tokenDistroAddressOptimism));
        vm.stopPrank();

        assertEq(bridgedGivToken.balanceOf(tokenDistroAddressOptimism), 0);

        vm.startPrank(_recipient);
        // test it was successful claim with GIV transfer
        vm.expectRevert();
        _tokenDistro.claim();
        vm.stopPrank();
        // grant distributor role and assign balance to the _distributor
    }
}
