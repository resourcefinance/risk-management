// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interface/IRiskOracle.sol";

contract RiskOracle is IRiskOracle, OwnableUpgradeable {
    /// @dev used to specify the precision for point based calculations.
    uint256 public constant SCALING_FACTOR = 10e10;

    /// @dev The address able to call set functions.
    address public operator;

    /// @dev The base fee rate used to manipulate the total fees charged by credit networks,
    /// depending on credit risk.
    mapping(address => uint256) public baseFeeRate;
    /// @dev The conversion rate between credit currency and reference currency.
    /// If left unset, the default conversion rate will be 1 to 1.
    mapping(address => uint256) public reserveConversionRate;

    function initialize(address _operator) external initializer {
        __Ownable_init();
        operator = _operator;
    }

    /// @notice Enables the risk manager to update the given credit token's base fee rate. This
    /// rate is supposed to be the calculated price of risk for the given credit token.
    /// @param creditToken address of the credit token.
    /// @param _baseFeeRate new base fee rate for the given credit token denominated in the SCALING_FACTOR.
    function setBaseFeeRate(address creditToken, uint256 _baseFeeRate) external onlyOperator {
        baseFeeRate[creditToken] = _baseFeeRate;
        emit BaseFeeRateUpdated(creditToken, _baseFeeRate);
    }

    /// @notice Enables the caller to update the given reserve pool's conversion rate. This
    /// conversion rate dictates the desired rate between the credit currency and the reference currency.
    /// @dev if the conversion rate is unset, the default conversion rate is 1 to 1.
    /// @param reservePool address of the reserve pool.
    /// @param _conversionRate new conversion rate for the given reserve pool denominated in the SCALING_FACTOR.
    function setReserveConversionRate(address reservePool, uint256 _conversionRate)
        external
        onlyOperator
    {
        reserveConversionRate[reservePool] = _conversionRate;
        emit ConversionRateUpdated(reservePool, _conversionRate);
    }

    /// @notice Returns the conversion rate between a reserve's currency and its credit network currency.
    /// @param reservePool address of the reserve pool to retrieve the conversion rate for.
    /// @return Conversion rate between credit currency and reference currency measured in the SCALING_FACTOR.
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

    /// @notice enables the contract owner to set the operator address.
    /// @param _operator address of the operator.
    function setOperator(address _operator) external onlyOwner {
        operator = _operator;
        emit OperatorUpdated(_operator);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOperator() {
        require(
            _msgSender() == operator || _msgSender() == owner(),
            "ReservePool: Caller is not the operator"
        );
        _;
    }
}
