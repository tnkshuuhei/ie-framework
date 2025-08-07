// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

interface IScaffoldIE is IAccessControl {
    event PoolCreated(uint256 poolId, address indexed strategy);
    event RouteCreated(address indexed route, uint32[] allocations, address _caller);
    event RouteUpdated(address indexed route, uint32[] allocations, address _caller);

    error InvalidCaller();
    error PoolNotFound(uint256 _poolId);
    error InvalidStrategy();

    /// @return The splits contract address
    function getSplits() external view returns (address);

    /// @param _initialAllocations The initial allocations for the route
    function createIERoute(uint32[] memory _initialAllocations) external;

    /// @param _poolId The pool ID
    /// @param _data The data for registering the recipients
    /// @param _caller The caller address
    function registerRecipients(uint256 _poolId, bytes memory _data, address _caller) external;

    /// @param _poolId The pool ID
    /// @param _data The data for updating the recipients
    /// @param _caller The caller address
    function updateRecipients(uint256 _poolId, bytes memory _data, address _caller) external;

    /// @param _allocations The new allocations for the route
    function updateRoute(uint32[] memory _allocations) external;

    /// @param _data The data for creating the IE
    /// @param _initializeData The initialization data
    /// @param strategy The strategy address
    function createIE(bytes memory _data, bytes memory _initializeData, address strategy) external;

    /// @param _poolId The pool ID
    /// @return The strategy address
    function getStrategy(uint256 _poolId) external view returns (address);

    /// @param _poolId The pool ID
    /// @param _data The evaluation data
    /// @param _caller The caller address
    function evaluate(uint256 _poolId, bytes memory _data, address _caller) external;

    /// @return The pool count
    function getPoolCount() external view returns (uint256);

    /// @return The splitter role
    function getSplitterRole() external pure returns (bytes32);

    /// @return The evaluator role
    function getEvaluatorRole() external pure returns (bytes32);

    /// @return The root split address
    function getRootSplit() external view returns (address);

    /// @param _strategy The strategy address
    /// @param _cloneable Whether the strategy is cloneable
    function setCloneableStrategy(address _strategy, bool _cloneable) external;
}
