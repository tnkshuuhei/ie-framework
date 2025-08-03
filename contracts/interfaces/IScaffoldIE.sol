// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IScaffoldIE {
    enum RecipientType {
        FullTime,
        PartTime
    }

    struct Recipient {
        address recipient;
        RecipientType recipientType;
    }

    event PoolCreated(
        uint256 poolId,
        uint256 managerHatId,
        address indexed splitsContract,
        uint256 evaluatorHatId,
        uint256 recipientHatId
    );

    struct PoolConfig {
        address admin;
        Recipient[] recipients;
        uint32[] initialAllocations;
        address[] evaluators;
        address splitsContract;
    }

    function createPool(bytes memory _data) external returns (uint256);
    function evaluate(uint256 _poolId) external returns (uint32[] memory);

    function getHatsModuleFactory() external view returns (address);
    function getHatCreatorModuleImpl() external view returns (address);
    function getTimeControlModuleImpl() external view returns (address);

    function getPoolIdToTimeControlModule(uint256 _poolId) external view returns (address);
    function getPoolIdToRecipientHat(uint256 _poolId) external view returns (uint256);
    function getPoolIdToSplitsContract(uint256 _poolId) external view returns (address);
    function getPoolIdToManagerHat(uint256 _poolId) external view returns (uint256);
}
