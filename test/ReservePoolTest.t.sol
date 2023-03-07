// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./RiskManagementTest.t.sol";

contract ReservePoolTest is RiskManagementTest {
    function setUp() public {
        setUpReSourceTest();
        vm.startPrank(deployer);
        referenceToken.approve(address(reservePool), type(uint256).max);
        vm.stopPrank();
    }

    // deposit into primary reserve updates total reserve and primary reserve
    function testDepositIntoPrimaryReserve() public {
        // deposit reserve updates reserve in reserve pool
        vm.startPrank(deployer);
        uint256 amount = 100;
        // approve reference token
        referenceToken.approve(address(riskManager), amount);
        // deposit into primary reserve
        reservePool.depositIntoPrimaryReserve(address(creditToken), address(referenceToken), amount);
        // check total reserve
        assertEq(reservePool.totalReserveOf(address(creditToken), address(referenceToken)), amount);
        // check primary reserve
        assertEq(reservePool.primaryReserve(address(creditToken), address(referenceToken)), amount);
        vm.stopPrank();
    }

    // deposit into peripheral reserve updates total reserve and peripheral reserve
    function testDepositIntoPeripheralReserve() public {
        vm.startPrank(deployer);
        uint256 amount = 100;
        // approve reference token
        referenceToken.approve(address(riskManager), amount);
        // deposit into peripheral reserve
        reservePool.depositIntoPeripheralReserve(
            address(creditToken), address(referenceToken), amount
        );
        // check total reserve
        assertEq(reservePool.totalReserveOf(address(creditToken), address(referenceToken)), amount);
        // check peripheral reserve
        assertEq(
            reservePool.peripheralReserve(address(creditToken), address(referenceToken)), amount
        );
        vm.stopPrank();
    }

    // deposit needed reserves updates excess pool when RTD is above target
    function testDepositNeededWithHighRTD() public {
        // deposit fees updates fees in reserve pool
        vm.startPrank(deployer);
        uint256 amount = 100;
        // approve reference token
        referenceToken.approve(address(riskManager), amount);
        // deposit into needed reserve
        reservePool.deposit(address(creditToken), address(referenceToken), amount);
        // check excess reserve
        assertEq(reservePool.excessReserve(address(creditToken), address(referenceToken)), amount);
        vm.stopPrank();
    }

    // deposit fees updates reserve when RTD is below target
    function testDepositFeesWithLowRTD() public {
        // deposit fees updates fees in reserve pool
        vm.startPrank(alice);
        // create 100 supply of credit token
        creditToken.mint(bob, 100);
        vm.stopPrank();
        vm.startPrank(deployer);
        uint256 amount = 100;
        // approve reference token
        referenceToken.approve(address(riskManager), amount);
        // deposit into needed reserve
        reservePool.deposit(address(creditToken), address(referenceToken), amount);
        assertEq(reservePool.totalReserveOf(address(creditToken), address(referenceToken)), 20);
        assertEq(reservePool.excessReserve(address(creditToken), address(referenceToken)), 80);
        vm.stopPrank();
    }

    function testUpdateBaseFeeRate() public {
        // update base fee rate
        vm.startPrank(deployer);
        reservePool.setBaseFeeRate(address(creditToken), 10000);
        assertEq(reservePool.baseFeeRate(address(creditToken)), 10000);
        vm.stopPrank();
    }
}
