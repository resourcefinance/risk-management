// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interface/IRiskOracle.sol";

contract RiskOracle is IRiskOracle, OwnableUpgradeable {
    uint256 public constant SCALING_FACTOR = 10e10;

    mapping(address => uint256) public baseFeeRate;

    mapping(address => uint256) public reserveConversionRate;

    function initialize() external virtual initializer {
        __Ownable_init();
    }

    /// @notice Enables the risk manager to update the given credit token's base fee rate. This
    /// rate is supposed to be the calculated price of risk for the given credit token.
    /// @param creditToken address of the credit token.
    /// @param _baseFeeRate new base fee rate for the given credit token measured in PRECISION.
    function setBaseFeeRate(address creditToken, uint256 _baseFeeRate) external onlyOwner {
        baseFeeRate[creditToken] = _baseFeeRate;
        emit BaseFeeRateUpdated(creditToken, _baseFeeRate);
    }

    /// @notice Enables the caller to update the given reserve pool's conversion rate. This
    /// conversion rate dictates the desired rate between the credit currency and the reference currency.
    /// @dev if the conversion rate is unset, the default conversion rate is 1 to 1.
    /// @param reservePool address of the reserve pool.
    /// @param _conversionRate new conversion rate for the given reserve pool .
    function setReserveConversionRate(address reservePool, uint256 _conversionRate)
        external
        onlyOwner
    {
        reserveConversionRate[reservePool] = _conversionRate;
        emit ConversionRateUpdated(reservePool, _conversionRate);
    }

    function reserveConversionRateOf(address reservePool)
        external
        view
        override
        returns (uint256)
    {
        // if the conversion rate is unset, the default conversion rate is 1 to 1.
        if (reserveConversionRate[reservePool] == 0) return SCALING_FACTOR;
        return reserveConversionRate[reservePool];
    }

    event BaseFeeRateUpdated(address creditToken, uint256 baseFeeRate);
    event ConversionRateUpdated(address creditToken, uint256 conversionRate);
}
