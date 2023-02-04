// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./ReSourceTest.t.sol";

contract ReservePoolTest is ReSourceTest {
    address alice;
    address bob;

    function setUp() public {
        setUpReSourceTest();
        alice = address(2);
        bob = address(3);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.startPrank(deployer);
        stableCredit.createCreditLine(alice, 100, 0);
        stableCredit.referenceToken().approve(address(reservePool), type(uint256).max);
        vm.stopPrank();
    }

    // deposit reserve updates reserve in reserve pool
    function testDepositReserve() public {
        // deposit reserve updates reserve in reserve pool
        vm.startPrank(deployer);
        uint256 amount = 100;
        stableCredit.referenceToken().approve(address(riskManager), amount);
        reservePool.depositReserve(address(stableCredit), amount);
        assertEq(reservePool.reserveOf(address(stableCredit)), amount);
        assertEq(reservePool.reserve(address(stableCredit)), amount);
        vm.stopPrank();
    }

    // deposit payment updates payment updates payment reserve
    function testDepositPayment() public {
        // deposit reserve updates reserve in reserve pool
        vm.startPrank(deployer);
        uint256 amount = 100;
        stableCredit.referenceToken().approve(address(riskManager), amount);
        reservePool.depositPayment(address(stableCredit), amount);
        assertEq(reservePool.reserveOf(address(stableCredit)), amount);
        assertEq(reservePool.paymentReserve(address(stableCredit)), amount);
        vm.stopPrank();
    }

    // deposit fees updates oeprator pool when RTD is above target
    function testDepositFeesWithHighRTD() public {
        // deposit fees updates fees in reserve pool
        vm.startPrank(deployer);
        uint256 amount = 100;
        stableCredit.referenceToken().approve(address(riskManager), amount);
        riskManager.depositFees(address(stableCredit), amount);
        assertEq(reservePool.operatorPool(address(stableCredit)), amount);
        vm.stopPrank();
    }

    // deposit fees updates reserve when RTD is below target
    function testDepositFeesWithLowRTD() public {
        // deposit fees updates fees in reserve pool
        vm.startPrank(alice);
        stableCredit.transfer(bob, 100);
        vm.stopPrank();
        vm.startPrank(deployer);
        uint256 amount = 100;
        stableCredit.referenceToken().approve(address(riskManager), amount);
        riskManager.depositFees(address(stableCredit), amount);
        assertEq(reservePool.reserveOf(address(stableCredit)), amount);
        vm.stopPrank();
    }
}