// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStableCredit {
    /// @dev the reserve pool contract which holds and manages reserve tokens
    function reservePool() external view returns (address);
    /// @dev the fee manager contract which manages transaction fee collection and distribution
    function feeManager() external view returns (address);
    /// @dev the access manager contract which manages network role access control
    function access() external view returns (address);
    /// @dev the credit issuer contract which manages credit line issuance
    function creditIssuer() external view returns (address);
    /// @dev the ambassador contract which manages the network's ambassador program
    function ambassador() external view returns (address);
    /// @dev the credit pool contract which manages the network's credit pool
    function creditPool() external view returns (address);
    /// @notice transfer a given member's debt to the network
    function writeOffCreditLine(address member) external;
    /// @notice called by the underwriting layer to assign credit lines
    /// @dev If the member address is not a current member, then the address is granted membership
    /// @param member address of line holder
    /// @param _creditLimit credit limit of new line
    /// @param _balance positive balance to initialize member with (will increment network debt)
    function createCreditLine(address member, uint256 _creditLimit, uint256 _balance) external;
    /// @notice update existing credit lines
    /// @param creditLimit must be greater than given member's outstanding debt
    function updateCreditLimit(address member, uint256 creditLimit) external;
    /// @notice Calculates the a credit amount in reserve token value.
    /// @param amount credit amount to convert
    function convertCreditsToReserveToken(uint256 amount) external view returns (uint256);

    /* ========== EVENTS ========== */

    event CreditLineCreated(address member, uint256 creditLimit, uint256 balance);
    event CreditLimitUpdated(address member, uint256 creditLimit);
    event MembersDemurraged(uint256 amount);
    event CreditBalanceRepaid(address member, uint128 amount);
    event NetworkDebtBurned(address member, uint256 amount);
    event CreditLineWrittenOff(address member, uint256 amount);

    event AccessManagerUpdated(address accessManager);
    event ReservePoolUpdated(address reservePool);
    event FeeManagerUpdated(address feeManager);
    event CreditIssuerUpdated(address creditIssuer);
    event AmbassadorUpdated(address ambassador);
    event CreditPoolUpdated(address creditPool);
}
