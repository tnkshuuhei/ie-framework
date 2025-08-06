// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import { ISplitMain } from "./interfaces/ISplitMain.sol";
import { IScaffoldIE } from "./interfaces/IScaffoldIE.sol";
import { IStrategy } from "./interfaces/IStrategy.sol";

contract ScaffoldIE is IScaffoldIE, AccessControl, Pausable {
    ISplitMain public splits;

    bytes32 public constant SPLITTER_ROLE = keccak256("SPLITTER_ROLE");
    bytes32 public constant EVALUATOR_ROLE = keccak256("EVALUATOR_ROLE");
    uint256 public poolCount;
    address public rootSplit;

    // poolId => strategy
    mapping(uint256 => address) public poolIdToStrategy;

    constructor(address _admin, address _splits) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        splits = ISplitMain(_splits);
    }

    function createIERoute(uint32[] memory _initialAllocations, address _caller) external onlyRole(SPLITTER_ROLE) {
        require(msg.sender == _caller, InvalidCaller(_caller));

        address[] memory IEs = new address[](poolCount);

        for (uint256 i = 0; i < poolCount; i++) {
            IEs[i] = IStrategy(poolIdToStrategy[i]).getAddress();
        }

        rootSplit = splits.createSplit(IEs, _initialAllocations, 0, address(this));

        emit RouteCreated(rootSplit, _initialAllocations, _caller);
    }

    function updateRoute(uint32[] memory _allocations, address _caller) external onlyRole(SPLITTER_ROLE) {
        require(msg.sender == _caller, InvalidCaller(_caller));

        address[] memory IEs = new address[](poolCount);

        for (uint256 i = 0; i < poolCount; i++) {
            IEs[i] = IStrategy(poolIdToStrategy[i]).getAddress();
        }

        splits.updateSplit(rootSplit, IEs, _allocations, 0);

        emit RouteUpdated(rootSplit, _allocations, _caller);
    }

    function createIE(bytes memory _data, address strategy) external {
        _createIE(_data, strategy);
        poolIdToStrategy[poolCount] = strategy;
        poolCount++;

        emit PoolCreated(poolCount, strategy);
    }

    function _createIE(bytes memory _data, address strategy) internal {
        IStrategy(strategy).initialize(poolCount, _data);
        IStrategy(strategy).createIE(_data);
    }

    function registerRecipients(uint256 _poolId, address[] memory _recipients, address _caller) external {
        require(msg.sender == _caller, InvalidCaller(_caller));
        require(poolIdToStrategy[_poolId] != address(0), PoolNotFound(_poolId));
        IStrategy(poolIdToStrategy[_poolId]).registerRecipients(_recipients, _caller);
    }

    function updateRecipients(uint256 _poolId, address[] memory _recipients, address _caller) external {
        require(msg.sender == _caller, InvalidCaller(_caller));
        require(poolIdToStrategy[_poolId] != address(0), PoolNotFound(_poolId));
        IStrategy(poolIdToStrategy[_poolId]).updateRecipients(_recipients, _caller);
    }

    function evaluate(uint256 _poolId, bytes memory _data, address _caller) external {
        require(msg.sender == _caller, InvalidCaller(_caller));
        require(poolIdToStrategy[_poolId] != address(0), PoolNotFound(_poolId));
        IStrategy(poolIdToStrategy[_poolId]).evaluate(_data, _caller);
    }

    function getSplits() external view returns (address) {
        return address(splits);
    }

    function getStrategy(uint256 _poolId) external view returns (address) {
        return poolIdToStrategy[_poolId];
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function getSplitterRole() external pure returns (bytes32) {
        return keccak256("SPLITTER_ROLE");
    }

    function getEvaluatorRole() external pure returns (bytes32) {
        return keccak256("EVALUATOR_ROLE");
    }

    function getPoolCount() external view returns (uint256) {
        return poolCount;
    }

    function getRootSplit() external view returns (address) {
        return rootSplit;
    }
}
