// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRiskOracle {
    function baseFeeRate(address creditToken) external view returns (uint256);

    function reserveConversionRateOf(address creditToken) external view returns (uint256);

    function SCALING_FACTOR() external view returns (uint256);
}
