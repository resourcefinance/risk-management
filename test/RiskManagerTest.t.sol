// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./ReSourceRiskManagerTest.t.sol";

contract RiskManagerTest is ReSourceRiskManagerTest {
    address alice;
    address bob;

    function setUp() public {
        setUpRiskManagement();
        alice = address(2);
        bob = address(3);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.startPrank(deployer);
        stableCredit.createCreditLine(alice, 100, 0);
        vm.stopPrank();
    }

    // deposit fees updates reserve
    function testDepositFeesFillsOperatorPool() public {
        // deposit fees updates fees in reserve pool
        vm.startPrank(deployer);
        uint256 amount = 100;
        stableCredit.referenceToken().approve(address(riskManager), amount);
        riskManager.depositFees(address(stableCredit), amount);
        assertEq(reservePool.operatorPool(address(stableCredit)), amount);
        vm.stopPrank();
    }

    // deposit payment updates payment reserve in reserve pool
    function testDepositPaymentFillsPaymentReserve() public {
        // deposit fees updates fees in reserve pool
        vm.startPrank(deployer);
        uint256 amount = 100;
        stableCredit.referenceToken().approve(address(riskManager), amount);
        riskManager.depositPayment(address(stableCredit), amount);
        assertEq(reservePool.reserveOf(address(stableCredit)), amount);
        assertEq(reservePool.paymentReserve(address(stableCredit)), amount);
        vm.stopPrank();
    }

    // syncRisk uses predicted default rate updates baseFeeRate and targetRTD
    // TODO:
}
