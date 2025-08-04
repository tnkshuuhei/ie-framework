// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IScaffoldIE {
    event PoolCreated(uint256 poolId, address indexed strategy);

    function getHats() external view returns (address);
    function getSplits() external view returns (address);
    function getHatsModuleFactory() external view returns (address);
    function getHatCreatorModuleImpl() external view returns (address);

    function createIE(bytes memory _data, address strategy) external returns (uint256 topHatId, uint256 poolId);
    function evaluate(uint256 _poolId, bytes memory _data) external returns (bytes memory);
}
