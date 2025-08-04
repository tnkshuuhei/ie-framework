// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29;

import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { ISplitMain } from "./interfaces/ISplitMain.sol";
import { IHatsModuleFactory } from "./interfaces/IHatsModuleFactory.sol";
import { IHatsHatCreatorModule } from "./Hats/IHatCreatorModule.sol";
import { IScaffoldIE } from "./interfaces/IScaffoldIE.sol";
import { IStrategy } from "./IEstrategies/IStrategy.sol";

contract ScaffoldIE is IScaffoldIE {
    IHats public hats;
    ISplitMain public splits;
    IHatsModuleFactory public hatsModuleFactory;
    IHatsHatCreatorModule public hatCreatorModuleImpl;

    address public owner;

    uint256 public poolCount;

    // poolId => strategy
    mapping(uint256 => address) public poolIdToStrategy;

    constructor(
        address _owner,
        address _hats,
        address _splits,
        IHatsModuleFactory _hatsModuleFactory,
        address _hatCreatorModuleImpl
    ) {
        hats = IHats(_hats);
        splits = ISplitMain(_splits);

        owner = _owner;

        hatsModuleFactory = _hatsModuleFactory;
        hatCreatorModuleImpl = IHatsHatCreatorModule(_hatCreatorModuleImpl);
    }

    function createIE(bytes memory _data, address strategy) external returns (uint256 topHatId, uint256 poolId) {
        topHatId = _createIE(_data, strategy);

        poolCount++;
        poolIdToStrategy[poolCount] = strategy;

        emit PoolCreated(poolCount, strategy);
        return (topHatId, poolCount);
    }

    function _createIE(bytes memory _data, address strategy) internal returns (uint256 topHatId) {
        topHatId = IStrategy(strategy).createIE(_data);
    }

    function getHats() external view returns (address) {
        return address(hats);
    }

    function evaluate(uint256 _poolId, bytes memory _data) external returns (bytes memory) {
        return IStrategy(poolIdToStrategy[_poolId]).evaluate(_data);
    }

    function getHatsModuleFactory() external view returns (address) {
        return address(hatsModuleFactory);
    }

    function getHatCreatorModuleImpl() external view returns (address) {
        return address(hatCreatorModuleImpl);
    }

    function getSplits() external view returns (address) {
        return address(splits);
    }
}
