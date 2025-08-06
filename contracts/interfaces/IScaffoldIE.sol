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

    function getSplits() external view returns (address);

    function createIERoute(uint32[] memory _initialAllocations) external;

    function registerRecipients(uint256 _poolId, address[] memory _recipients, address _caller) external;

    function updateRecipients(uint256 _poolId, address[] memory _recipients, address _caller) external;

    function updateRoute(uint32[] memory _allocations) external;

    function createIE(bytes memory _data, address strategy) external;

    function getStrategy(uint256 _poolId) external view returns (address);

    function evaluate(uint256 _poolId, bytes memory _data, address _caller) external;
    function getPoolCount() external view returns (uint256);

    function getSplitterRole() external pure returns (bytes32);

    function getEvaluatorRole() external pure returns (bytes32);

    function getRootSplit() external view returns (address);
}
