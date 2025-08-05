// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IScaffoldIE {
    event PoolCreated(uint256 poolId, address indexed strategy);

    function getSplits() external view returns (address);

    function createIE(bytes memory _data, address strategy) external;

    function getStrategy(uint256 _poolId) external view returns (address);

    function evaluate(uint256 _poolId, bytes memory _data) external;
}
