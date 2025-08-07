// SPDX-License-Identifier: MIT
pragma solidity >=0.8.29;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { ISplitMain } from "./interfaces/ISplitMain.sol";
import { IScaffoldIE } from "./interfaces/IScaffoldIE.sol";
import { IStrategy } from "./interfaces/IStrategy.sol";

contract ScaffoldIE is IScaffoldIE, AccessControl, Pausable {
    ISplitMain public splits;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SPLITTER_ROLE = keccak256("SPLITTER_ROLE");
    bytes32 public constant EVALUATOR_ROLE = keccak256("EVALUATOR_ROLE");
    uint256 public poolCount;
    address public rootSplit;

    // poolId => strategy
    mapping(uint256 => address) public poolIdToStrategy;

    // strategy => cloneable
    mapping(address => bool) public cloneableStrategy;

    /// @param _admin The admin address
    /// @param _splits The splits contract address
    constructor(address _admin, address _splits) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(SPLITTER_ROLE, _admin);
        _grantRole(EVALUATOR_ROLE, _admin);
        splits = ISplitMain(_splits);
    }

    /// @param _initialAllocations The initial allocations for the route
    function createIERoute(uint32[] memory _initialAllocations) external onlyRole(SPLITTER_ROLE) {
        address[] memory IEs = new address[](poolCount);
        uint32[] memory allocations = new uint32[](poolCount);

        for (uint256 i = 0; i < poolCount; i++) {
            require(poolIdToStrategy[i] != address(0), InvalidStrategy());
            IEs[i] = IStrategy(poolIdToStrategy[i]).getAddress();
            allocations[i] = _initialAllocations[i];
        }

        // Sort IEs and allocations together in ascending order (required by SplitMain)
        _sortAddressesAndAllocations(IEs, allocations);

        rootSplit = splits.createSplit(IEs, allocations, 0, address(this));

        emit RouteCreated(rootSplit, allocations, msg.sender);
    }

    /// @param _allocations The new allocations for the route
    function updateRoute(uint32[] memory _allocations) external onlyRole(SPLITTER_ROLE) {
        address[] memory IEs = new address[](poolCount);
        uint32[] memory allocations = new uint32[](poolCount);

        for (uint256 i = 0; i < poolCount; i++) {
            require(poolIdToStrategy[i] != address(0), InvalidStrategy());
            IEs[i] = IStrategy(poolIdToStrategy[i]).getAddress();
            allocations[i] = _allocations[i];
        }

        // Sort IEs and allocations together in ascending order (required by SplitMain)
        _sortAddressesAndAllocations(IEs, allocations);

        splits.updateSplit(rootSplit, IEs, allocations, 0);

        emit RouteUpdated(rootSplit, allocations, msg.sender);
    }

    /// @param _data The data for creating the IE
    /// @param _initializeData The initialization data
    /// @param strategy The strategy address
    function createIE(bytes memory _data, bytes memory _initializeData, address strategy) external {
        require(strategy != address(0), InvalidStrategy());
        require(_isCloneableStrategy(strategy), InvalidStrategy());

        address clone = Clones.clone(strategy);

        _createIE(_data, _initializeData, clone);
        poolIdToStrategy[poolCount] = clone;
        emit IECreated(poolCount, clone);
        poolCount++;
    }

    /// @param _data The data for creating the IE
    /// @param _initializeData The initialization data
    /// @param strategy The strategy address
    function _createIE(bytes memory _data, bytes memory _initializeData, address strategy) internal {
        IStrategy(strategy).initialize(poolCount, _initializeData, address(this));
        IStrategy(strategy).createIE(_data);
    }

    /// @param _poolId The pool ID
    /// @param _data The data for registering the recipients
    /// @param _caller The caller address
    function registerRecipients(uint256 _poolId, bytes memory _data, address _caller) external {
        require(msg.sender == _caller, InvalidCaller());
        require(poolIdToStrategy[_poolId] != address(0), PoolNotFound(_poolId));

        // access control is handled in the strategy
        // only check if the msg.sender is equal to the caller
        IStrategy(poolIdToStrategy[_poolId]).registerRecipients(_data, _caller);
    }

    /// @param _poolId The pool ID
    /// @param _data The data for updating the recipients
    /// @param _caller The caller address
    function updateRecipients(uint256 _poolId, bytes memory _data, address _caller) external {
        require(msg.sender == _caller, InvalidCaller());
        require(poolIdToStrategy[_poolId] != address(0), PoolNotFound(_poolId));

        // access control is handled in the strategy
        // only check if the msg.sender is equal to the caller
        IStrategy(poolIdToStrategy[_poolId]).updateRecipients(_data, _caller);
    }

    /// @param _poolId The pool ID
    /// @param _data The evaluation data
    /// @param _caller The caller address
    function evaluate(uint256 _poolId, bytes memory _data, address _caller) external {
        require(msg.sender == _caller, InvalidCaller());
        require(poolIdToStrategy[_poolId] != address(0), PoolNotFound(_poolId));
        IStrategy(poolIdToStrategy[_poolId]).evaluate(_data, _caller);
    }

    /// @return The splits contract address
    function getSplits() external view returns (address) {
        return address(splits);
    }

    /// @param _poolId The pool ID
    /// @return The strategy address
    function getStrategy(uint256 _poolId) external view returns (address) {
        return poolIdToStrategy[_poolId];
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @return The splitter role
    function getSplitterRole() external pure returns (bytes32) {
        return SPLITTER_ROLE;
    }

    /// @return The evaluator role
    function getEvaluatorRole() external pure returns (bytes32) {
        return EVALUATOR_ROLE;
    }

    /// @return The pool count
    function getPoolCount() external view returns (uint256) {
        return poolCount;
    }

    /// @return The root split address
    function getRootSplit() external view returns (address) {
        return rootSplit;
    }

    /// @param _poolId The pool ID
    /// @param _evaluator The evaluator address
    /// @param _caller The caller address
    function addEvaluator(uint256 _poolId, address _evaluator, address _caller) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(msg.sender == _caller, InvalidCaller());
        require(poolIdToStrategy[_poolId] != address(0), PoolNotFound(_poolId));
        IStrategy(poolIdToStrategy[_poolId]).addEvaluator(_evaluator, _caller);
    }

    /// @param _poolId The pool ID
    /// @param _evaluator The evaluator address
    /// @param _caller The caller address
    function removeEvaluator(
        uint256 _poolId,
        address _evaluator,
        address _caller
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(msg.sender == _caller, InvalidCaller());
        require(poolIdToStrategy[_poolId] != address(0), PoolNotFound(_poolId));
        IStrategy(poolIdToStrategy[_poolId]).removeEvaluator(_evaluator, _caller);
    }

    /// @param _poolId The pool ID
    /// @param _manager The manager address
    /// @param _caller The caller address
    function addManager(uint256 _poolId, address _manager, address _caller) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(msg.sender == _caller, InvalidCaller());
        IStrategy(poolIdToStrategy[_poolId]).addManager(_manager, _caller);
    }

    /// @param _poolId The pool ID
    /// @param _manager The manager address
    /// @param _caller The caller address
    function removeManager(uint256 _poolId, address _manager, address _caller) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(msg.sender == _caller, InvalidCaller());
        IStrategy(poolIdToStrategy[_poolId]).removeManager(_manager, _caller);
    }

    /// @param _strategy The strategy address
    /// @param _cloneable Whether the strategy is cloneable
    function setCloneableStrategy(address _strategy, bool _cloneable) external onlyRole(DEFAULT_ADMIN_ROLE) {
        cloneableStrategy[_strategy] = _cloneable;
    }

    /// @param _strategy The strategy address
    /// @return Whether the strategy is cloneable
    function isCloneableStrategy(address _strategy) external view returns (bool) {
        return _isCloneableStrategy(_strategy);
    }

    /// @param _strategy The strategy address
    /// @return Whether the strategy is cloneable
    function _isCloneableStrategy(address _strategy) internal view returns (bool) {
        return cloneableStrategy[_strategy];
    }

    /// @param _addresses The addresses to sort
    /// @param _allocations The allocations to sort
    function _sortAddressesAndAllocations(address[] memory _addresses, uint32[] memory _allocations) internal pure {
        uint256 length = _addresses.length;
        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                if (_addresses[j] > _addresses[j + 1]) {
                    address tempAddress = _addresses[j];
                    _addresses[j] = _addresses[j + 1];
                    _addresses[j + 1] = tempAddress;

                    uint32 tempAllocation = _allocations[j];
                    _allocations[j] = _allocations[j + 1];
                    _allocations[j + 1] = tempAllocation;
                }
            }
        }
    }
}
