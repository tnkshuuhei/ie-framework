// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29;

// Ref: https://github.com/0xSplits/splits-contracts/blob/main/contracts/interfaces/ISplitMain.sol
interface ISplitMain {
    /// @param accounts The accounts addresses
    /// @param percentAllocations The percentage allocations
    /// @param distributorFee The distributor fee
    /// @param controller The controller address
    /// @return The split address
    function createSplit(
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address controller
    )
        external
        returns (address);

    /// @param accounts The accounts addresses
    /// @param percentAllocations The percentage allocations
    /// @param distributorFee The distributor fee
    /// @return The predicted split address
    function predictImmutableSplitAddress(
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee
    )
        external
        view
        returns (address);

    /// @param split The split address
    /// @param accounts The accounts addresses
    /// @param percentAllocations The percentage allocations
    /// @param distributorFee The distributor fee
    function updateSplit(
        address split,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee
    )
        external;

    /// @param split The split address
    /// @param accounts The accounts addresses
    /// @param percentAllocations The percentage allocations
    /// @param distributorFee The distributor fee
    /// @param distributorAddress The distributor address
    function distributeETH(
        address split,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address distributorAddress
    )
        external;

    /// @param split The split address
    /// @return The controller address
    function getController(address split) external view returns (address);
}
