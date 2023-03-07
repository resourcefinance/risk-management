// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./interface/IReservePool.sol";

/// @title ReservePool
/// @author ReSource
/// @notice Stores and manages reserve tokens according to reserve
/// configurations set by the RiskManager.
contract ReservePool is IReservePool, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== CONSTANTS ========== */

    /// @dev Maximum parts per million
    uint32 private constant MAX_PPM = 1000000;

    /* ========== STATE VARIABLES ========== */

    address public riskManager;

    /// @notice primary reserve of a given credit token
    /// @dev credit token => reserve token => reserve
    mapping(address => mapping(address => uint256)) public primaryReserve;
    /// @notice peripheral reserve of a given credit token
    /// @dev credit token => reserve token => peripheral reserve
    mapping(address => mapping(address => uint256)) public peripheralReserve;
    /// @notice excess reserve of a given credit token
    /// @dev credit token => reserve token => excess reserve
    mapping(address => mapping(address => uint256)) public excessReserve;
    /// @notice target reserve to debt ratio of a given credit token
    /// @dev credit token => reserve token => target RTD
    mapping(address => mapping(address => uint256)) public targetRTD;
    /// @notice base fee rate of a given credit token transfer
    /// @dev credit token => base fee rate
    mapping(address => uint256) public baseFeeRate;

    /* ========== INITIALIZER ========== */

    function initialize(address _riskManager) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        riskManager = _riskManager;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice enables caller to deposit a given reserve token into a credit token's
    /// primary reserve.
    /// @param creditToken address of the credit token.
    /// @param reserveToken address of the reserve token.
    /// @param amount amount of reserve token to deposit.
    function depositIntoPrimaryReserve(address creditToken, address reserveToken, uint256 amount)
        public
    {
        require(amount > 0, "ReservePool: Cannot deposit 0");
        // add deposit to primary reserve
        primaryReserve[creditToken][reserveToken] += amount;
        // collect reserve token deposit from caller
        IERC20Upgradeable(reserveToken).safeTransferFrom(msg.sender, address(this), amount);
        emit PrimaryReserveDeposited(creditToken, reserveToken, amount);
    }

    /// @notice enables caller to deposit a given reserve token into a credit token's
    /// peripheral reserve.
    /// @param creditToken address of the credit token.
    /// @param reserveToken address of the reserve token.
    /// @param amount amount of reserve token to deposit.
    function depositIntoPeripheralReserve(address creditToken, address reserveToken, uint256 amount)
        public
        override
        nonReentrant
    {
        require(amount > 0, "ReservePool: Cannot deposit 0");
        // add deposit to peripheral reserve
        peripheralReserve[creditToken][reserveToken] += amount;
        // collect reserve token deposit from caller
        IERC20Upgradeable(reserveToken).safeTransferFrom(msg.sender, address(this), amount);
        emit PeripheralReserveDeposited(creditToken, reserveToken, amount);
    }

    /// @notice enables caller to deposit a given reserve token into a credit token's
    /// excess reserve.
    /// @param creditToken address of the credit token.
    /// @param reserveToken address of the reserve token.
    /// @param amount amount of reserve token to deposit.
    function depositIntoExcessReserve(address creditToken, address reserveToken, uint256 amount)
        public
    {
        // collect remaining amount from caller
        IERC20Upgradeable(reserveToken).safeTransferFrom(msg.sender, address(this), amount);
        // deposit remaining amount into excess reserve
        excessReserve[creditToken][reserveToken] += amount;
        emit ExcessReserveDeposited(creditToken, reserveToken, amount);
    }

    /// @notice enables caller to deposit a given reserve token into a credit token's
    /// needed reserve. Deposits flow into the primary reserve until the the target RTD
    // threshold has been reached, after which the remaining amount is deposited into the excess reserve.
    /// @param creditToken address of the credit token.
    /// @param reserveToken address of the reserve token.
    /// @param amount amount of reserve token to deposit.
    function deposit(address creditToken, address reserveToken, uint256 amount)
        public
        override
        nonReentrant
    {
        uint256 neededReserves = getNeededReserves(creditToken, reserveToken);
        // if neededReserve is greater than amount, deposit full amount into primary reserve
        if (neededReserves > amount) {
            depositIntoPrimaryReserve(creditToken, reserveToken, amount);
            return;
        }
        // deposit neededReserves into primary reserve
        if (neededReserves > 0) {
            depositIntoPrimaryReserve(creditToken, reserveToken, neededReserves);
        }
        // deposit remaining amount into excess reserve
        depositIntoExcessReserve(creditToken, reserveToken, amount - neededReserves);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice enables caller to withdraw a given reserve token from a credit token's excess reserve.
    /// @dev The credit token implementation should expose an access controlled function that federates
    /// calls to this function.
    /// @param creditToken address of the credit token.
    /// @param reserveToken address of the reserve token.
    /// @param amount amount reference tokens to withdraw from given credit token's excess reserve.
    function withdraw(address creditToken, address reserveToken, uint256 amount)
        public
        nonReentrant
    {
        require(amount > 0, "ReservePool: Cannot withdraw 0");
        require(
            amount <= excessReserve[creditToken][reserveToken],
            "ReservePool: Insufficient excess reserve"
        );
        // reduce excess reserve
        excessReserve[creditToken][reserveToken] -= amount;
        // transfer reserve token to caller
        IERC20Upgradeable(reserveToken).safeTransferFrom(msg.sender, address(this), amount);
        emit ExcessReserveWithdrawn(creditToken, reserveToken, amount);
    }

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
    ) external override onlyCreditToken(creditToken) nonReentrant {
        // if no reserves, return
        if (totalReserveOf(creditToken, reserveToken) == 0) return;
        // if amount is covered by peripheral, reimburse only from peripheral
        if (amount < peripheralReserve[creditToken][reserveToken]) {
            peripheralReserve[creditToken][reserveToken] -= amount;
            // if amount is covered by primary, reimburse only from primary
        } else if (amount < totalReserveOf(creditToken, reserveToken)) {
            primaryReserve[creditToken][reserveToken] -=
                amount - peripheralReserve[creditToken][reserveToken];
            peripheralReserve[creditToken][reserveToken] = 0;
            // use both reserves to cover amount
        } else {
            // get total reserve amount
            uint256 reserveAmount = totalReserveOf(creditToken, reserveToken);
            // empty both reserves
            peripheralReserve[creditToken][reserveToken] = 0;
            primaryReserve[creditToken][reserveToken] = 0;
            // set amount to available reserves
            amount = reserveAmount;
        }
        // transfer given amount to account
        IERC20Upgradeable(reserveToken).transfer(account, amount);
        emit AccountReimbursed(creditToken, reserveToken, account, amount);
    }

    /// @notice This function allows the risk manager to set the target RTD for a given credit token.
    /// If the target RTD is increased and there is excess reserve, the excess reserve is reallocated
    /// to the primary reserve to attempt to reach the new target RTD.
    /// @param creditToken address of the credit token.
    /// @param reserveToken address of the reserve token.
    /// @param _targetRTD new target RTD.
    function setTargetRTD(address creditToken, address reserveToken, uint256 _targetRTD)
        external
        override
        onlyRiskManager
    {
        // if increasing target RTD and there is excess reserves, reallocate excess reserve to primary
        if (
            _targetRTD > targetRTD[creditToken][reserveToken]
                && excessReserve[creditToken][reserveToken] > 0
        ) {
            reallocateExcessReserve(creditToken, reserveToken);
        }
        // update target RTD
        targetRTD[creditToken][reserveToken] = _targetRTD;
        emit TargetRTDUpdated(creditToken, reserveToken, _targetRTD);
    }

    /// @notice Enables the risk manager to update the given credit token's base fee rate. This
    /// rate is supposed to be the calculated price of risk for the given credit token.
    /// @param creditToken address of the credit token.
    /// @param _baseFeeRate new base fee rate for the given credit token.
    function setBaseFeeRate(address creditToken, uint256 _baseFeeRate) external onlyRiskManager {
        baseFeeRate[creditToken] = _baseFeeRate;
        emit BaseFeeRateUpdated(creditToken, _baseFeeRate);
    }

    /* ========== VIEW FUNCTIONS ========== */

    /// @notice returns the total amount of reserve tokens in the credit token's primary and peripheral reserves.
    /// @param creditToken address of the credit token.
    /// @return total amount of reserve tokens in the credit token's primary and peripheral reserves.
    function totalReserveOf(address creditToken, address reserveToken)
        public
        view
        returns (uint256)
    {
        return
            primaryReserve[creditToken][reserveToken] + peripheralReserve[creditToken][reserveToken];
    }

    /// @notice returns the ratio of primary reserve to total debt denominated in parts per million (PPM).
    /// @param creditToken address of the credit token.
    /// @param reserveToken address of the reserve token.
    /// @return ratio of primary reserve to total debt denominated in parts per million (PPM).
    function RTD(address creditToken, address reserveToken) public view returns (uint256) {
        // if primary reserve is empty return 0% RTD ratio
        if (primaryReserve[creditToken][reserveToken] == 0) return 0;
        // if credit token has no debt, return 0% RTD ratio
        if (IERC20Upgradeable(creditToken).totalSupply() == 0) return 0;
        // return primary reserve amount divided by total debt amount
        return (primaryReserve[creditToken][reserveToken] * MAX_PPM)
            / convertCreditTokenToReserveToken(
                creditToken, reserveToken, IERC20Upgradeable(creditToken).totalSupply()
            );
    }

    /// @notice returns true if the credit token's primary reserve is greater than or equal to the target RTD.
    /// @dev returns true if the credit token's primary reserve is greater than or equal to the target RTD.
    /// @param creditToken address of the credit token.
    /// @param reserveToken address of the reserve token.
    /// @return true if the credit token's primary reserve is greater than or equal to the target RTD.
    function hasValidRTD(address creditToken, address reserveToken) public view returns (bool) {
        // if current RTD is greater than target RTD, return false
        return RTD(creditToken, reserveToken) >= targetRTD[creditToken][reserveToken];
    }

    /// @notice returns the amount of reserve tokens needed for the primary reserve to reach the
    //  target RTD.
    /// @dev the returned amount is denominated in the reserve token
    /// @param creditToken address of the credit token.
    /// @param reserveToken address of the reserve token.
    /// @return amount of reserve tokens needed for the primary reserve to reach the target RTD.
    function getNeededReserves(address creditToken, address reserveToken)
        public
        view
        returns (uint256)
    {
        if (hasValidRTD(creditToken, reserveToken)) return 0;
        // (target RTD - current RTD) * total debt amount
        return (
            (targetRTD[creditToken][reserveToken] - RTD(creditToken, reserveToken))
                * convertCreditTokenToReserveToken(
                    creditToken, reserveToken, IERC20Upgradeable(creditToken).totalSupply()
                )
        ) / MAX_PPM;
    }

    /// @notice converts the given credit token amount to the reserve token denomination.
    /// @param creditToken address of the credit token.
    /// @param reserveToken address of the reserve token.
    /// @param amount credit token amount to convert to reserve currency denomination.
    /// @return credit token amount converted to reserve currency denomination
    function convertCreditTokenToReserveToken(
        address creditToken,
        address reserveToken,
        uint256 amount
    ) public view returns (uint256) {
        if (amount == 0) return amount;
        uint256 reserveDecimals = IERC20Metadata(reserveToken).decimals();
        uint256 creditDecimals = IERC20Metadata(creditToken).decimals();
        return creditDecimals < reserveDecimals
            ? ((amount * 10 ** (reserveDecimals - creditDecimals)))
            : ((amount / 10 ** (creditDecimals - reserveDecimals)));
    }

    /// @notice Returns the given credit token's base fee rate in parts per million (PPM).
    /// This rate is supposed to be the calculated price of risk for the given credit token.
    /// @param creditToken address of the credit token.
    /// @return base fee rate of the given credit token.
    function baseFeeRateOf(address creditToken) external view override returns (uint256) {
        return baseFeeRate[creditToken];
    }

    /* ========== PRIVATE ========== */

    /// @notice this function reallocates needed reserves from the excess reserve to the
    /// primary reserve to attempt to reach the target RTD.
    /// @param creditToken address of the credit token.
    /// @param reserveToken address of the reserve token.
    function reallocateExcessReserve(address creditToken, address reserveToken) private {
        uint256 neededReserves = getNeededReserves(creditToken, reserveToken);
        if (neededReserves > excessReserve[creditToken][reserveToken]) {
            primaryReserve[creditToken][reserveToken] += excessReserve[creditToken][reserveToken];
            excessReserve[creditToken][reserveToken] = 0;
        } else {
            primaryReserve[creditToken][reserveToken] += neededReserves;
            excessReserve[creditToken][reserveToken] -= neededReserves;
        }
        emit ExcessReallocated(
            creditToken,
            reserveToken,
            excessReserve[creditToken][reserveToken],
            primaryReserve[creditToken][reserveToken]
            );
    }

    /* ========== MODIFIERS ========== */

    modifier onlyCreditToken(address creditToken) {
        require(
            creditToken == msg.sender || msg.sender == owner(),
            "ReservePool: Caller is not reserve owner"
        );
        _;
    }

    modifier onlyRiskManager() {
        require(
            msg.sender == riskManager || msg.sender == owner(),
            "ReservePool: Caller is not risk manager"
        );
        _;
    }
}
