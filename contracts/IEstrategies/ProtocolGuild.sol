// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IEAS, Attestation, AttestationRequest, AttestationRequestData } from "eas-contracts/IEAS.sol";
import { BaseIEStrategy } from "./BaseIEStrategy.sol";
import { ISplitMain } from "../interfaces/ISplitMain.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { AttesterResolver } from "../AttesterResolver.sol";
import { IScaffoldIE } from "../interfaces/IScaffoldIE.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";

contract ProtocolGuild is BaseIEStrategy, AccessControl, Pausable {
    // State variables
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant EVALUATOR_ROLE = keccak256("EVALUATOR_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    string public schema;
    bytes32 public schemaUID;
    address public splitsContract;

    mapping(address => uint256) public startDate;
    mapping(address => bool) public isActive;
    mapping(address => WorkType) public workType;

    error RecipientsAndWorkTypesLengthMismatch();
    error InitialAllocationsLengthMismatch();
    error InvalidAllocation();

    enum WorkType {
        FULL,
        PARTIAL
    }

    mapping(WorkType => uint256) public workTypeToMultiplier;

    IEAS public eas;

    // Errors
    error InvalidEvaluator(address _caller);
    error InvalidManager(address _caller);

    /// @param _poolId The pool ID
    /// @param _initializeData The initialization data
    /// @param _scaffoldIE The scaffold IE address
    function initialize(uint256 _poolId, bytes memory _initializeData, address _scaffoldIE) external override {
        // Check that the caller is the ScaffoldIE contract
        require(msg.sender == _scaffoldIE, OnlyScaffoldIE(msg.sender));

        scaffoldIE = IScaffoldIE(_scaffoldIE);

        __BaseStrategyInit(_poolId, _initializeData);
    }

    /// @param _initializeData The initialization data
    function _initialize(bytes memory _initializeData) internal override {
        name = "ProtocolGuild";

        (address _eas, bytes32 _schemaUID, address _admin) = abi.decode(_initializeData, (address, bytes32, address));
        eas = IEAS(_eas);
        schemaUID = _schemaUID;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
    }

    // Public/External functions

    /// @return The splits contract address
    function getAddress() external view returns (address) {
        return splitsContract;
    }

    /// @param _data The data for creating the IE
    function createIE(bytes memory _data) external override onlyScaffoldIE onlyInitialized {
        _createIE(_data);
    }

    /// @param _data The evaluation data
    /// @param _caller The caller address
    function evaluate(
        bytes memory _data,
        address _caller
    )
        external
        override
        onlyEvaluator(_caller)
        onlyScaffoldIE
        onlyInitialized
        returns (bytes memory)
    {
        return _evaluate(_data);
    }

    /// @param _data The data for registering the recipients
    /// @param _caller The caller address
    function registerRecipients(
        bytes memory _data,
        address _caller
    )
        external
        override
        onlyManager(_caller)
        onlyScaffoldIE
        onlyInitialized
    {
        _registerRecipients(_data);
    }

    /// @param _data The data for registering the recipients
    function _registerRecipients(bytes memory _data) internal override {
        (address[] memory _recipients, WorkType[] memory _workTypes) = abi.decode(_data, (address[], WorkType[]));
        recipientsData = abi.encode(_recipients, _workTypes);
        for (uint256 i = 0; i < _recipients.length; i++) {
            workType[_recipients[i]] = _workTypes[i];
        }
    }

    /// @param _data The data for updating the recipients
    /// @param _caller The caller address
    function updateRecipients(
        bytes memory _data,
        address _caller
    )
        external
        override
        onlyManager(_caller)
        onlyScaffoldIE
        onlyInitialized
    {
        _updateRecipients(_data);
    }

    /// @param _data The data for updating the recipients
    function _updateRecipients(bytes memory _data) internal override {
        (address[] memory _recipients, WorkType[] memory _workTypes) = abi.decode(_data, (address[], WorkType[]));
        recipientsData = abi.encode(_recipients, _workTypes);
        for (uint256 i = 0; i < _recipients.length; i++) {
            if (startDate[_recipients[i]] == 0) {
                startDate[_recipients[i]] = block.timestamp;
                isActive[_recipients[i]] = true;
                workType[_recipients[i]] = _workTypes[i];
            }
        }
    }

    // Internal functions

    /// @notice Create an IE
    /// @param _data The data to create the IE
    /// @dev The data is a string, address[], uint32[]
    /// @dev address[]: recipients
    /// @dev uint32[]: initial allocations
    function _createIE(bytes memory _data) internal override {
        (address[] memory _recipients, WorkType[] memory _workTypes, uint32[] memory _initialAllocations) =
            abi.decode(_data, (address[], WorkType[], uint32[]));

        require(_recipients.length == _workTypes.length, RecipientsAndWorkTypesLengthMismatch());
        require(_recipients.length == _initialAllocations.length, InitialAllocationsLengthMismatch());

        recipientsData = abi.encode(_recipients, _workTypes);

        for (uint256 i = 0; i < _recipients.length; i++) {
            workType[_recipients[i]] = _workTypes[i];
            startDate[_recipients[i]] = block.timestamp;
        }

        splitsContract =
            ISplitMain(scaffoldIE.getSplits()).createSplit(_recipients, _initialAllocations, 0, address(this));
    }

    function _evaluate(bytes memory _data) internal returns (bytes memory) {
        (address[] memory recipients, WorkType[] memory workTypes) = abi.decode(recipientsData, (address[], WorkType[]));
        uint32[] memory allocations = _calculateAllocations(recipients, workTypes);
        _processEvaluation(_data, recipients, allocations);

        return abi.encode(recipients, allocations);
    }

    function _calculateAllocations(
        address[] memory recipients,
        WorkType[] memory workTypes
    )
        internal
        view
        returns (uint32[] memory)
    {
        uint32[] memory allocations = new uint32[](recipients.length);
        uint256 timestamp = block.timestamp;
        uint256 totalAllocations = 0;

        // First pass: calculate total allocations
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 timeDiff = timestamp - startDate[recipients[i]];
            // if (timeDiff > 365 days) timeDiff = 365 days;
            uint256 sqrtTimeDiff = Math.sqrt(timeDiff);
            uint256 weighted = workTypes[i] == WorkType.FULL ? sqrtTimeDiff * 10 : sqrtTimeDiff * 5;
            totalAllocations += weighted;
        }

        require(totalAllocations > 0, InvalidAllocation());

        // Second pass: calculate scaled allocations
        uint256 totalScaled = 0;
        for (uint256 i = 0; i < recipients.length - 1; i++) {
            uint256 timeDiff = timestamp - startDate[recipients[i]];
            // if (timeDiff > 365 days) timeDiff = 365 days;
            uint256 sqrtTimeDiff = Math.sqrt(timeDiff);
            uint256 weighted = workTypes[i] == WorkType.FULL ? sqrtTimeDiff * 10 : sqrtTimeDiff * 5;

            uint256 scaledAllocation = (weighted * 1_000_000) / totalAllocations;
            require(scaledAllocation <= type(uint32).max, InvalidAllocation());
            allocations[i] = uint32(scaledAllocation);
            totalScaled += scaledAllocation;
        }

        // Last element gets remaining allocation
        uint256 remainingAllocation = 1_000_000 - totalScaled;
        require(remainingAllocation <= type(uint32).max, InvalidAllocation());
        allocations[recipients.length - 1] = uint32(remainingAllocation);

        return allocations;
    }

    function _processEvaluation(
        bytes memory _data,
        address[] memory recipients,
        uint32[] memory allocations
    )
        internal
    {
        _sortAddressesAndAllocations(recipients, allocations);

        (string memory _dataset, address contractAddress, uint256 chainId, address evaluator) =
            abi.decode(_data, (string, address, uint256, address));

        bytes memory attestationData =
            abi.encode(_dataset, recipients, allocations, contractAddress, chainId, evaluator);

        AttestationRequestData memory attestationRequestData = AttestationRequestData({
            recipient: address(0),
            expirationTime: 0,
            revocable: true,
            refUID: bytes32(0),
            data: attestationData,
            value: 0
        });
        AttestationRequest memory request = AttestationRequest({ schema: schemaUID, data: attestationRequestData });

        eas.attest(request);

        ISplitMain(scaffoldIE.getSplits()).updateSplit(splitsContract, recipients, allocations, 0);
    }

    function getStartDate(address _recipient) external view returns (uint256) {
        return startDate[_recipient];
    }

    function getWorkType(address _recipient) external view returns (WorkType) {
        return workType[_recipient];
    }

    function getWorkTime(address _recipient) external view returns (uint256) {
        return block.timestamp - startDate[_recipient];
    }

    function setWorkTypeToMultiplier(WorkType _workType, uint256 _multiplier) external onlyAdmin(msg.sender) {
        workTypeToMultiplier[_workType] = _multiplier;
    }

    function getRecipients() external view returns (bytes memory) {
        return recipientsData;
    }

    function addEvaluator(address _evaluator, address _caller) external onlyAdmin(_caller) onlyInitialized {
        _grantRole(EVALUATOR_ROLE, _evaluator);
    }

    function removeEvaluator(address _evaluator, address _caller) external onlyAdmin(_caller) onlyInitialized {
        _revokeRole(EVALUATOR_ROLE, _evaluator);
    }

    function addManager(address _manager, address _caller) external onlyAdmin(_caller) onlyInitialized {
        _grantRole(MANAGER_ROLE, _manager);
    }

    function removeManager(address _manager, address _caller) external onlyAdmin(_caller) onlyInitialized {
        _revokeRole(MANAGER_ROLE, _manager);
    }

    // Modifiers
    modifier onlyEvaluator(address _caller) {
        require(hasRole(EVALUATOR_ROLE, _caller), InvalidEvaluator(_caller));
        _;
    }

    modifier onlyManager(address _caller) {
        require(hasRole(MANAGER_ROLE, _caller), InvalidManager(_caller));
        _;
    }

    modifier onlyAdmin(address _caller) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _caller), "Not admin");
        _;
    }
}
