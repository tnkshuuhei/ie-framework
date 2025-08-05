// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29;

import { ISplitMain } from "./interfaces/ISplitMain.sol";
import { IScaffoldIE } from "./interfaces/IScaffoldIE.sol";
import { IStrategy } from "./interfaces/IStrategy.sol";

contract ScaffoldIE is IScaffoldIE {
    ISplitMain public splits;

    address public owner;

    uint256 public poolCount;

    // poolId => strategy
    mapping(uint256 => address) public poolIdToStrategy;

    constructor(address _owner, address _splits) {
        splits = ISplitMain(_splits);

        owner = _owner;
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

    function evaluate(uint256 _poolId, bytes memory _data) external returns (bytes memory) {
        return IStrategy(poolIdToStrategy[_poolId]).evaluate(_data);
    }


    function getSplits() external view returns (address) {
        return address(splits);
    }
}
