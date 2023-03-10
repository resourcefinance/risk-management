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

    /* ========== STATE VARIABLES ========== */

    address public riskManager;
    IRiskOracle public riskOracle;

    IERC20Upgradeable public creditToken;
    IERC20Upgradeable public reserveToken;
    uint256 public primaryReserve;
    uint256 public peripheralReserve;
    uint256 public excessReserve;
    uint256 public targetRTD;
    mapping(address => uint256) public deposits;

    /* ========== INITIALIZER ========== */

    function initialize(
        address _creditToken,
        address _reserveToken,
        address _riskManager,
        address _riskOracle
    ) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        creditToken = IERC20Upgradeable(_creditToken);
        reserveToken = IERC20Upgradeable(_reserveToken);
        riskOracle = IRiskOracle(_riskOracle);
        riskManager = _riskManager;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice enables caller to deposit a given reserve token into the primary reserve.
    /// @param amount amount of reserve token to deposit.
    function depositIntoPrimaryReserve(uint256 amount) public {
        require(amount > 0, "ReservePool: Cannot deposit 0");
        // add deposit to primary reserve
        primaryReserve += amount;
        // collect reserve token deposit from caller
        IERC20Upgradeable(reserveToken).safeTransferFrom(_msgSender(), address(this), amount);
        emit PrimaryReserveDeposited(amount);
    }

    /// @notice enables caller to deposit a given reserve token into the peripheral reserve.
    /// @param amount amount of reserve token to deposit.
    function depositIntoPeripheralReserve(uint256 amount) public override nonReentrant {
        require(amount > 0, "ReservePool: Cannot deposit 0");
        // add deposit to peripheral reserve
        peripheralReserve += amount;
        // collect reserve token deposit from caller
        IERC20Upgradeable(reserveToken).safeTransferFrom(_msgSender(), address(this), amount);
        emit PeripheralReserveDeposited(amount);
    }

    /// @notice enables caller to deposit a given reserve token into the excess reserve.
    /// @param amount amount of reserve token to deposit.
    function depositIntoExcessReserve(uint256 amount) public {
        // collect remaining amount from caller
        IERC20Upgradeable(reserveToken).safeTransferFrom(_msgSender(), address(this), amount);
        // deposit remaining amount into excess reserve
        excessReserve += amount;
        emit ExcessReserveDeposited(amount);
    }

    /// @notice enables caller to deposit a given reserve token into a credit token's
    /// needed reserve. Deposits flow into the primary reserve until the the target RTD
    // threshold has been reached, after which the remaining amount is deposited into the excess reserve.
    /// @param amount amount of reserve token to deposit.
    function deposit(uint256 amount) public override nonReentrant {
        deposits[_msgSender()] += amount;
        uint256 neededReserves = getNeededReserves();
        // if neededReserve is greater than amount, deposit full amount into primary reserve
        if (neededReserves > amount) {
            depositIntoPrimaryReserve(amount);
            return;
        }
        // deposit neededReserves into primary reserve
        if (neededReserves > 0) {
            depositIntoPrimaryReserve(neededReserves);
        }
        // deposit remaining amount into excess reserve
        depositIntoExcessReserve(amount - neededReserves);
    }

    /// @notice enables caller to withdraw a given reserve token from a credit token's excess reserve.
    /// @dev The credit token implementation should expose an access controlled function that federates
    /// calls to this function.
    /// @param amount amount reference tokens to withdraw from given credit token's excess reserve.
    function withdraw(uint256 amount) public nonReentrant {
        require(deposits[_msgSender()] >= amount, "ReservePool: Insufficient deposit amount");
        require(amount > 0, "ReservePool: Cannot withdraw 0");
        require(amount <= excessReserve, "ReservePool: Insufficient excess reserve");
        // reduce excess reserve
        excessReserve -= amount;
        // transfer reserve token to caller
        IERC20Upgradeable(reserveToken).safeTransferFrom(_msgSender(), address(this), amount);
        // update deposited amount
        deposits[_msgSender()] -= amount;
        emit ExcessReserveWithdrawn(amount);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice Called by the credit token implementation to reimburse an account from the credit token's
    /// reserves. If the amount is covered by the peripheral reserve, the peripheral reserve is depleted first,
    /// followed by the primary reserve.
    /// @dev The credit token implementation should not expose this function to the public as it could be
    /// exploited to drain the credit token's reserves.
    /// @param account address to reimburse from credit token's reserves.
    /// @param amount amount reference tokens to withdraw from given credit token's excess reserve.
    function reimburseAccount(address account, uint256 amount)
        external
        override
        onlyCreditToken
        nonReentrant
    {
        // if no reserves, return
        if (totalReserve() == 0) return;
        // if amount is covered by peripheral, reimburse only from peripheral
        if (amount < peripheralReserve) {
            peripheralReserve -= amount;
            // check if total amount can be covered by reserve
        } else if (amount < totalReserve()) {
            // use both reserves to cover amount
            primaryReserve -= amount - peripheralReserve;
            peripheralReserve = 0;
        } else {
            // use entire reserve to cover amount
            uint256 reserveAmount = totalReserve();
            // empty both reserves
            peripheralReserve = 0;
            primaryReserve = 0;
            // set amount to available reserves
            amount = reserveAmount;
        }
        // transfer given amount to account
        IERC20Upgradeable(reserveToken).transfer(account, amount);
        emit AccountReimbursed(account, amount);
    }

    /// @notice This function allows the risk manager to set the target RTD for a given credit token.
    /// If the target RTD is increased and there is excess reserve, the excess reserve is reallocated
    /// to the primary reserve to attempt to reach the new target RTD.
    /// @param _targetRTD new target RTD.
    function setTargetRTD(uint256 _targetRTD) external override onlyRiskManager {
        // if increasing target RTD and there is excess reserves, reallocate excess reserve to primary
        if (_targetRTD > targetRTD && excessReserve > 0) {
            reallocateExcessReserve();
        }
        // update target RTD
        targetRTD = _targetRTD;
        emit TargetRTDUpdated(_targetRTD);
    }

    function setReserveToken(address _reserveToken) external onlyRiskManager {
        reserveToken = IERC20Upgradeable(_reserveToken);
        emit ReserveTokenUpdated(_reserveToken);
    }

    /* ========== VIEW FUNCTIONS ========== */

    /// @notice returns the total amount of reserve tokens in the primary and peripheral reserves.
    /// @return total amount of reserve tokens in the credit token's primary and peripheral reserves.
    function totalReserve() public view returns (uint256) {
        return primaryReserve + peripheralReserve;
    }

    /// @notice returns the ratio of primary reserve to total debt denominated in parts per million (PPM).
    /// @return ratio of primary reserve to total debt denominated in parts per million (PPM).
    function RTD() public view returns (uint256) {
        // if primary reserve is empty return 0% RTD ratio
        if (primaryReserve == 0) return 0;
        // if credit token has no debt, return 0% RTD ratio
        if (IERC20Upgradeable(creditToken).totalSupply() == 0) return 0;
        // return primary reserve amount divided by total debt amount
        return (primaryReserve * riskOracle.SCALING_FACTOR())
            / convertCreditTokenToReserveToken(creditToken.totalSupply());
    }

    /// @notice returns true if the credit token's primary reserve is greater than or equal to the target RTD.
    /// @dev returns true if the credit token's primary reserve is greater than or equal to the target RTD.
    /// @return true if the credit token's primary reserve is greater than or equal to the target RTD.
    function hasValidRTD() public view returns (bool) {
        // if current RTD is greater than target RTD, return false
        return RTD() >= targetRTD;
    }

    /// @notice returns the amount of reserve tokens needed for the primary reserve to reach the
    //  target RTD.
    /// @dev the returned amount is denominated in the reserve token
    /// @return amount of reserve tokens needed for the primary reserve to reach the target RTD.
    function getNeededReserves() public view returns (uint256) {
        if (hasValidRTD()) return 0;
        // (target RTD - current RTD) * total debt amount
        return ((targetRTD - RTD()) * convertCreditTokenToReserveToken(creditToken.totalSupply()))
            / riskOracle.SCALING_FACTOR();
    }

    /// @notice converts the given credit token amount to the reserve token denomination.
    /// @param creditAmount credit token amount to convert to reserve currency denomination.
    /// @return credit token amount converted to reserve currency denomination
    function convertCreditTokenToReserveToken(uint256 creditAmount) public view returns (uint256) {
        if (creditAmount == 0) return creditAmount;
        // create decimal conversion
        uint256 reserveDecimals = IERC20Metadata(address(reserveToken)).decimals();
        uint256 creditDecimals = IERC20Metadata(address(creditToken)).decimals();
        uint256 decimalConversion = creditDecimals < reserveDecimals
            ? ((creditAmount * 10 ** (reserveDecimals - creditDecimals)))
            : ((creditAmount / 10 ** (creditDecimals - reserveDecimals)));

        // if no risk oracle or conversion rate is unset, return decimal conversion
        if (address(riskOracle) == address(0)) {
            return decimalConversion;
        }
        return decimalConversion * riskOracle.reserveConversionRateOf(address(this))
            / riskOracle.SCALING_FACTOR();
    }
    /* ========== PRIVATE ========== */

    /// @notice this function reallocates needed reserves from the excess reserve to the
    /// primary reserve to attempt to reach the target RTD.
    function reallocateExcessReserve() private {
        uint256 neededReserves = getNeededReserves();
        if (neededReserves > excessReserve) {
            primaryReserve += excessReserve;
            excessReserve = 0;
        } else {
            primaryReserve += neededReserves;
            excessReserve -= neededReserves;
        }
        emit ExcessReallocated(excessReserve, primaryReserve);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyCreditToken() {
        require(
            _msgSender() == address(creditToken) || _msgSender() == owner(),
            "ReservePool: Caller is not reserve owner"
        );
        _;
    }

    modifier onlyRiskManager() {
        require(
            _msgSender() == riskManager || _msgSender() == owner(),
            "ReservePool: Caller is not risk manager"
        );
        _;
    }
}
