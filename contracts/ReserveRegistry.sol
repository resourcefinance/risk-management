// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title This contract is responsible for maintaining a list of reserves that are to be
/// analyzed and maintained by the ReSource Risk Management infrastructure.
/// @author ReSource
/// @notice enables the contract owner to add and remove reserve contracts from the registry
contract ReserveRegistry is OwnableUpgradeable {
    // address => reserve
    mapping(address => bool) public reserves;

    function initialize() external initializer {
        __Ownable_init();
    }

    /// @notice Allows owner address to add reserves to the registry
    /// @dev The caller must be the owner of the contract
    /// @param reserve address of the reserve to add
    function addReserve(address reserve) external onlyOwner {
        require(!reserves[reserve], "Registry: Reserve is already registered");
        reserves[reserve] = true;
        emit ReserveAdded(reserve);
    }

    /// @notice Allows owner address to remove reserves from the registry
    /// @dev The caller must be the owner of the contract
    /// @param reserve address of the reserve to remove
    function removeReserve(address reserve) external onlyOwner {
        require(reserves[reserve], "Registry: Reserve isn't registered");
        reserves[reserve] = false;
        emit ReserveRemoved(reserve);
    }

    event ReserveAdded(address reserve);
    event ReserveRemoved(address reserve);
}
