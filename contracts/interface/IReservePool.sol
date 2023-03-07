// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReservePool {
    /// @notice Called by the credit token implementation to reimburse an account from the credit token's
    /// reserves. If the amount is covered by the peripheral reserve, the peripheral reserve is depleted first,
    /// followed by the primary reserve.
    /// @dev The credit token implementation should not expose this function to the public as it could be
    /// exploited to drain the credit token's reserves.
    /// @param creditToken address of the credit token.
    /// @param reserveToken address of the reserve token.
    /// @param account address to reimburse from credit token's reserves.
    /// @param amount amount reference tokens to withdraw from given credit token's excess reserve.
    function reimburseAccount(
        address creditToken,
        address reserveToken,
        address account,
        uint256 amount
    ) external;

    /// @notice enables caller to deposit a given reserve token into a credit token's
    /// needed reserve. Deposits flow into the primary reserve until the the target RTD
    // threshold has been reached, after which the remaining amount is deposited into the excess reserve.
    /// @param creditToken address of the credit token.
    /// @param reserveToken address of the reserve token.
    /// @param amount amount of reserve token to deposit.
    function deposit(address creditToken, address reserveToken, uint256 amount) external;

    /// @notice enables caller to deposit a given reserve token into a credit token's
    /// peripheral reserve.
    /// @param creditToken address of the credit token.
    /// @param reserveToken address of the reserve token.
    /// @param amount amount of reserve token to deposit.
    function depositIntoPeripheralReserve(address creditToken, address reserveToken, uint256 amount)
        external;

    /// @notice This function allows the risk manager to set the target RTD for a given credit token.
    /// If the target RTD is increased and there is excess reserve, the excess reserve is reallocated
    /// to the primary reserve to attempt to reach the new target RTD.
    /// @param creditToken address of the credit token.
    /// @param reserveToken address of the reserve token.
    /// @param _targetRTD new target RTD.
    function setTargetRTD(address creditToken, address reserveToken, uint256 _targetRTD) external;

    /// @notice Returns the given credit token's base fee rate in parts per million (PPM).
    /// This rate is supposed to be the calculated price of risk for the given credit token.
    /// @param creditToken address of the credit token.
    /// @return base fee rate of the given credit token.
    function baseFeeRateOf(address creditToken) external view returns (uint256);

    /* ========== EVENTS ========== */

    event ExcessReallocated(
        address creditToken, address reserveToken, uint256 excessReserve, uint256 primaryReserve
    );
    event PrimaryReserveDeposited(address creditToken, address reserveToken, uint256 amount);
    event PeripheralReserveDeposited(address creditToken, address reserveToken, uint256 amount);
    event ExcessReserveDeposited(address creditToken, address reserveToken, uint256 amount);
    event ExcessReserveWithdrawn(address creditToken, address reserveToken, uint256 amount);
    event AccountReimbursed(
        address creditToken, address reserveToken, address account, uint256 amount
    );
    event TargetRTDUpdated(address creditToken, address reserveToken, uint256 newTargetRTD);
    event BaseFeeRateUpdated(address creditToken, uint256 baseFeeRate);
}
