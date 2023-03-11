// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../contracts/ReservePool.sol";
import "../contracts/RiskOracle.sol";
import "./MockERC20.sol";

contract RiskManagementTest is Test {
    address alice;
    address bob;
    address deployer;

    ReservePool public reservePool;
    RiskOracle public riskOracle;
    MockERC20 public reserveToken;
    MockERC20 public creditToken;

    function setUpReSourceTest() public {
        alice = address(2);
        bob = address(3);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        deployer = address(1);
        vm.startPrank(deployer);

        // deploy reserve token
        reserveToken = new MockERC20(1000000 * (10e18), "Reference Token", "REF");
        // deploy credit token
        creditToken = new MockERC20(0, "Credit Token", "CRD");
        // deploy riskOracle
        riskOracle = new RiskOracle();
        riskOracle.initialize(deployer);
        // deploy reservePool
        reservePool = new ReservePool();
        reservePool.initialize(
            address(creditToken), address(reserveToken), deployer, address(riskOracle)
        );
        reservePool.setTargetRTD(20 * 10e8); // set targetRTD to 20%
        riskOracle.setBaseFeeRate(address(reservePool), 50000); // set base fee rate to 5%
        vm.stopPrank();
    }
}
