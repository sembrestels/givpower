// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10;

import './UnipoolGIVpowerTest.sol';
import '../../contracts/TokenDistro.sol';

contract UnipoolNotifyReward is UnipoolGIVpowerTest {
    // uint256 givPowerInitialTotalSupply;

    TokenDistro tokenDistro;

    function setUp() public override {
        super.setUp();
        tokenDistro = TokenDistro(address(iDistro));

        vm.startPrank(givethMultisig);
        tokenDistro.grantRole(tokenDistro.DISTRIBUTOR_ROLE(), address(givPower));
        vm.stopPrank();
    }

    function testInBudgetNotifyReward() public {
        uint256 _rewardBudget = 1_000 ether;

        vm.startPrank(givethMultisig);
        tokenDistro.assign(address(givPower), _rewardBudget);
        vm.stopPrank();

        vm.startPrank(rewardDistributor);
        givPower.notifyRewardAmount(_rewardBudget);
        vm.stopPrank();

        assertEq(givPower.rewardRate(), _rewardBudget / givPower.ROUND_DURATION());
    }

    function testOutOfBudgetNotifyReward() public {
        uint256 _rewardBudget = 1_000 ether;

        vm.startPrank(givethMultisig);
        tokenDistro.assign(address(givPower), _rewardBudget);
        vm.stopPrank();

        vm.startPrank(rewardDistributor);
        vm.expectRevert('UnipoolTokenDistributor: NOT_ENOUGH_TOKEND_ISTRO_BALANCE');
        givPower.notifyRewardAmount(_rewardBudget + 1);
        vm.stopPrank();
    }

    function testInBudgetNotifyRewardWithLeftover() public {
        uint256 _rewardBudget = 1_000 ether;

        vm.startPrank(givethMultisig);
        tokenDistro.assign(address(givPower), _rewardBudget);
        vm.stopPrank();

        vm.startPrank(rewardDistributor);
        givPower.notifyRewardAmount(_rewardBudget / 2);
        givPower.notifyRewardAmount(_rewardBudget / 2);
        vm.stopPrank();

        assertEq(givPower.rewardRate(), _rewardBudget / givPower.ROUND_DURATION());
    }

    function testOutOfBudgetNotifyRewardWithLeftover() public {
        uint256 _rewardBudget = 1_000 ether;

        vm.startPrank(givethMultisig);
        tokenDistro.assign(address(givPower), _rewardBudget);
        vm.stopPrank();

        vm.startPrank(rewardDistributor);
        givPower.notifyRewardAmount(_rewardBudget / 2);
        vm.expectRevert('UnipoolTokenDistributor: NOT_ENOUGH_TOKEND_ISTRO_BALANCE');
        givPower.notifyRewardAmount((_rewardBudget / 2) + 1 ether);
        vm.stopPrank();
    }
}
