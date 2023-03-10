// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IRiskOracle.sol";

interface IReservePool {
    /// @notice Called by the credit token implementation to reimburse an account from the credit token's
    /// reserves. If the amount is covered by the peripheral reserve, the peripheral reserve is depleted first,
    /// followed by the primary reserve.
    /// @dev The credit token implementation should not expose this function to the public as it could be
    /// exploited to drain the credit token's reserves.
    /// @param account address to reimburse from credit token's reserves.
    /// @param amount amount reference tokens to withdraw from given credit token's excess reserve.
    function reimburseAccount(address account, uint256 amount) external;

    /// @notice enables caller to deposit a given reserve token into a credit token's
    /// needed reserve. Deposits flow into the primary reserve until the the target RTD
    // threshold has been reached, after which the remaining amount is deposited into the excess reserve.
    /// @param amount amount of reserve token to deposit.
    function deposit(uint256 amount) external;

    /// @notice enables caller to deposit a given reserve token into a credit token's
    /// peripheral reserve.
    /// @param amount amount of reserve token to deposit.
    function depositIntoPeripheralReserve(uint256 amount) external;

    /// @notice This function allows the risk manager to set the target RTD for a given credit token.
    /// If the target RTD is increased and there is excess reserve, the excess reserve is reallocated
    /// to the primary reserve to attempt to reach the new target RTD.
    /// @param _targetRTD new target RTD.
    function setTargetRTD(uint256 _targetRTD) external;

    /// @notice converts the given credit token amount to the reserve token denomination.
    /// @param amount credit token amount to convert to reserve currency denomination.
    /// @return credit token amount converted to reserve currency denomination
    function convertCreditTokenToReserveToken(uint256 amount) external view returns (uint256);

    /// @notice Returns the risk oracle interface of the reserve pool.
    /// @return the risk oracle interface of the reserve pool
    function riskOracle() external view returns (IRiskOracle);

    /* ========== EVENTS ========== */

    event ExcessReallocated(uint256 excessReserve, uint256 primaryReserve);
    event PrimaryReserveDeposited(uint256 amount);
    event PeripheralReserveDeposited(uint256 amount);
    event ExcessReserveDeposited(uint256 amount);
    event ExcessReserveWithdrawn(uint256 amount);
    event AccountReimbursed(address account, uint256 amount);
    event TargetRTDUpdated(uint256 newTargetRTD);
    event ReserveTokenUpdated(address newReserveToken);
}
