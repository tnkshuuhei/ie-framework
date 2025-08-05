// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IScaffoldIE {
    event PoolCreated(uint256 poolId, address indexed strategy);

    event RouteCreated(address indexed route, uint32[] allocations, address _caller);
    event RouteUpdated(address indexed route, uint32[] allocations, address _caller);

    function getSplits() external view returns (address);

    function createIERoute(uint32[] memory _initialAllocations, address _caller) external;

    function updateRoute(uint32[] memory _allocations, address _caller) external;

    function createIE(bytes memory _data, address strategy) external;

    function getStrategy(uint256 _poolId) external view returns (address);

    function evaluate(uint256 _poolId, bytes memory _data, address _caller) external;
}
