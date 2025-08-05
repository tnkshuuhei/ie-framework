// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import { ISplitMain } from "./interfaces/ISplitMain.sol";
import { IScaffoldIE } from "./interfaces/IScaffoldIE.sol";
import { IStrategy } from "./interfaces/IStrategy.sol";

contract ScaffoldIE is IScaffoldIE, Ownable, Pausable {
    ISplitMain public splits;

    uint256 public poolCount;

    error InvalidCaller(address _caller);

    // poolId => strategy
    mapping(uint256 => address) public poolIdToStrategy;

    constructor(address _owner, address _splits) Ownable(_owner) {
        splits = ISplitMain(_splits);
    }

    function createIE(bytes memory _data, address strategy) external {
        poolCount++;
        poolIdToStrategy[poolCount] = strategy;

        _createIE(_data, strategy);

        emit PoolCreated(poolCount, strategy);
    }

    function _createIE(bytes memory _data, address strategy) internal {
        IStrategy(strategy).initialize(poolCount, _data);
        IStrategy(strategy).createIE(_data);
    }

    function registerRecipients(uint256 _poolId, address[] memory _recipients, address _caller) external {
        require(msg.sender == _caller, InvalidCaller(_caller));
        IStrategy(poolIdToStrategy[_poolId]).registerRecipients(_recipients, _caller);
    }

    function updateRecipients(uint256 _poolId, address[] memory _recipients, address _caller) external {
        require(msg.sender == _caller, InvalidCaller(_caller));
        IStrategy(poolIdToStrategy[_poolId]).updateRecipients(_recipients, _caller);
    }

    function evaluate(uint256 _poolId, bytes memory _data, address _caller) external {
        require(msg.sender == _caller, InvalidCaller(_caller));
        IStrategy(poolIdToStrategy[_poolId]).evaluate(_data, _caller);
    }

    function getSplits() external view returns (address) {
        return address(splits);
    }

    function getStrategy(uint256 _poolId) external view returns (address) {
        return poolIdToStrategy[_poolId];
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
