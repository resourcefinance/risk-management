// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./RiskManagementTest.t.sol";

contract ReservePoolTest is RiskManagementTest {
    function setUp() public {
        setUpReSourceTest();
        vm.startPrank(deployer);
        reserveToken.approve(address(reservePool), type(uint256).max);
        vm.stopPrank();
    }

    // deposit into primary reserve updates total reserve and primary reserve
    function testDepositIntoPrimaryReserve() public {
        // deposit reserve updates reserve in reserve pool
        vm.startPrank(deployer);
        uint256 amount = 100;
        // deposit into primary reserve
        reservePool.depositIntoPrimaryReserve(amount);
        // check total reserve
        assertEq(reservePool.totalReserve(), amount);
        // check primary reserve
        assertEq(reservePool.primaryReserve(), amount);
        vm.stopPrank();
    }

    // deposit into peripheral reserve updates total reserve and peripheral reserve
    function testDepositIntoPeripheralReserve() public {
        vm.startPrank(deployer);
        uint256 amount = 100;
        // deposit into peripheral reserve
        reservePool.depositIntoPeripheralReserve(amount);
        // check total reserve
        assertEq(reservePool.totalReserve(), amount);
        // check peripheral reserve
        assertEq(reservePool.peripheralReserve(), amount);
        vm.stopPrank();
    }

    // deposit needed reserves updates excess pool when RTD is above target
    function testDepositNeededWithHighRTD() public {
        // deposit fees updates fees in reserve pool
        vm.startPrank(deployer);
        uint256 amount = 100;
        // deposit into needed reserve
        reservePool.deposit(amount);
        // check excess reserve
        assertEq(reservePool.excessReserve(), amount);
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
        // deposit into needed reserve
        reservePool.deposit(amount);
        assertEq(reservePool.totalReserve(), 20);
        assertEq(reservePool.excessReserve(), 80);
        vm.stopPrank();
    }

    function testUpdateBaseFeeRate() public {
        // update base fee rate
        vm.startPrank(deployer);
        riskOracle.setBaseFeeRate(address(reservePool), 10000);
        assertEq(riskOracle.baseFeeRate(address(reservePool)), 10000);
        vm.stopPrank();
    }
}
