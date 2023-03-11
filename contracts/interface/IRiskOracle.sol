// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRiskOracle {
    /// @dev The scaling factor is used to specify the precision for point based calculations.
    function baseFeeRate(address creditToken) external view returns (uint256);
    /// @dev The conversion rate between credit currency and reference currency.
    /// If left unset, the default conversion rate will be 1 to 1.
    function reserveConversionRateOf(address creditToken) external view returns (uint256);
    /// @dev used to specify the precision for point based calculations.
    function SCALING_FACTOR() external view returns (uint256);

    /* ========== EVENTS ========== */

    event BaseFeeRateUpdated(address creditToken, uint256 baseFeeRate);
    event ConversionRateUpdated(address creditToken, uint256 conversionRate);
    event OperatorUpdated(address operator);
}
