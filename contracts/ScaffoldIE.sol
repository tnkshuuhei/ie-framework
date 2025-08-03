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
    uint256 public topHatId;

    // poolId => strategy
    mapping(uint256 => address) public poolIdToStrategy;

    constructor(
        address _owner,
        address _hats,
        address _splits,
        string memory _topHatMetadata,
        string memory _topHatImageURL,
        IHatsModuleFactory _hatsModuleFactory,
        address _hatCreatorModuleImpl
    ) {
        hats = IHats(_hats);
        splits = ISplitMain(_splits);

        // mint tophat to this contract
        // https://github.com/hats-protocol/hats-protocol/blob/b23340f825a2cdf9f5758462f8161d7076ad7f6f/src/Hats.sol#L168
        topHatId = hats.mintTopHat(address(this), _topHatMetadata, _topHatImageURL);
        // TODO: manage owner address on tophat and correcponding hat
        owner = _owner;

        hatsModuleFactory = _hatsModuleFactory;
        hatCreatorModuleImpl = IHatsHatCreatorModule(_hatCreatorModuleImpl);
    }

    function createIE(bytes memory _data, address strategy) external returns (uint256) {
        _createIE(_data, strategy);

        poolCount++;

        emit PoolCreated(poolCount, strategy);
        return poolCount;
    }

    function _createIE(bytes memory _data, address strategy) internal {
        IStrategy(strategy).createIE(_data);

        poolIdToStrategy[poolCount] = strategy;
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

    function getTopHatId() external view returns (uint256) {
        return topHatId;
    }

    function getSplits() external view returns (address) {
        return address(splits);
    }
}
