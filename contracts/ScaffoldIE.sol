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

    function createIERoute(uint32[] memory _initialAllocations) external onlyRole(SPLITTER_ROLE) {
        address[] memory IEs = new address[](poolCount);

        for (uint256 i = 0; i < poolCount; i++) {
            require(poolIdToStrategy[i] != address(0), InvalidStrategy());
            IEs[i] = IStrategy(poolIdToStrategy[i]).getAddress();
        }

        rootSplit = splits.createSplit(IEs, _initialAllocations, 0, address(this));

        emit RouteCreated(rootSplit, _initialAllocations, msg.sender);
    }

    function updateRoute(uint32[] memory _allocations) external onlyRole(SPLITTER_ROLE) {
        address[] memory IEs = new address[](poolCount);

        for (uint256 i = 0; i < poolCount; i++) {
            require(poolIdToStrategy[i] != address(0), InvalidStrategy());
            IEs[i] = IStrategy(poolIdToStrategy[i]).getAddress();
        }

        splits.updateSplit(rootSplit, IEs, _allocations, 0);

        emit RouteUpdated(rootSplit, _allocations, msg.sender);
    }

    function createIE(bytes memory _data, address strategy) external {
        require(strategy != address(0), InvalidStrategy());
        // TODO: strategy contract should be a clone
        _createIE(_data, strategy);
        poolIdToStrategy[poolCount] = strategy;
        emit PoolCreated(poolCount, strategy);
        poolCount++;
    }

    function _createIE(bytes memory _data, address strategy) internal {
        IStrategy(strategy).initialize(poolCount, _data);
        IStrategy(strategy).createIE(_data);
    }

    function registerRecipients(uint256 _poolId, address[] memory _recipients, address _caller) external {
        require(msg.sender == _caller, InvalidCaller());
        require(poolIdToStrategy[_poolId] != address(0), PoolNotFound(_poolId));
        IStrategy(poolIdToStrategy[_poolId]).registerRecipients(_recipients, _caller);
    }

    function updateRecipients(uint256 _poolId, address[] memory _recipients, address _caller) external {
        require(msg.sender == _caller, InvalidCaller());
        require(poolIdToStrategy[_poolId] != address(0), PoolNotFound(_poolId));
        IStrategy(poolIdToStrategy[_poolId]).updateRecipients(_recipients, _caller);
    }

    function evaluate(uint256 _poolId, bytes memory _data, address _caller) external {
        require(msg.sender == _caller, InvalidCaller());
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
        return SPLITTER_ROLE;
    }

    function getEvaluatorRole() external pure returns (bytes32) {
        return EVALUATOR_ROLE;
    }

    function getPoolCount() external view returns (uint256) {
        return poolCount;
    }

    function getRootSplit() external view returns (address) {
        return rootSplit;
    }

    function addEvaluator(uint256 _poolId, address _evaluator, address _caller) external {
        require(msg.sender == _caller, InvalidCaller());
        require(poolIdToStrategy[_poolId] != address(0), PoolNotFound(_poolId));
        IStrategy(poolIdToStrategy[_poolId]).addEvaluator(_evaluator, _caller);
    }

    function removeEvaluator(uint256 _poolId, address _evaluator, address _caller) external {
        require(msg.sender == _caller, InvalidCaller());
        require(poolIdToStrategy[_poolId] != address(0), PoolNotFound(_poolId));
        IStrategy(poolIdToStrategy[_poolId]).removeEvaluator(_evaluator, _caller);
    }

    function addManager(uint256 _poolId, address _manager, address _caller) external {
        require(msg.sender == _caller, InvalidCaller());
        IStrategy(poolIdToStrategy[_poolId]).addManager(_manager, _caller);
    }

    function removeManager(uint256 _poolId, address _manager, address _caller) external {
        require(msg.sender == _caller, InvalidCaller());
        IStrategy(poolIdToStrategy[_poolId]).removeManager(_manager, _caller);
    }
}
