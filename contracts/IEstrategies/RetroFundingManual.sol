// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IEAS, Attestation, AttestationRequest, AttestationRequestData } from "eas-contracts/IEAS.sol";
import { BaseIEStrategy } from "./BaseIEStrategy.sol";
import { ISplitMain } from "../interfaces/ISplitMain.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IScaffoldIE } from "../interfaces/IScaffoldIE.sol";

contract RetroFundingManual is BaseIEStrategy, AccessControl, Pausable {
    // State variables
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant EVALUATOR_ROLE = keccak256("EVALUATOR_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // SCHEMA
    // string datasets, address[] recipients, uint32[] allocations , address contract, uint256 chainId, address attester
    string public schema;
    bytes32 public schemaUID;
    address public splitsContract;

    IEAS public eas;

    error EmptyRecipientsArray();
    error InitialAllocationsLengthMismatch();

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
        name = "RetroFundingStrategy";

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
        (address[] memory _recipients) = abi.decode(_data, (address[]));
        require(_recipients.length > 0, EmptyRecipientsArray());
        recipientsData = abi.encode(_recipients);
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
        (address[] memory _recipients) = abi.decode(_data, (address[]));
        require(_recipients.length > 0, EmptyRecipientsArray());
        recipientsData = abi.encode(_recipients);
    }

    // Internal functions

    /// @notice Create an IE
    /// @param _data The data to create the IE
    /// @dev The data is a string, address[], uint32[]
    /// @dev address[]: recipients
    /// @dev uint32[]: initial allocations
    function _createIE(bytes memory _data) internal override {
        (address[] memory _recipients, uint32[] memory _initialAllocations) = abi.decode(_data, (address[], uint32[]));

        require(_recipients.length > 0, EmptyRecipientsArray());
        require(_initialAllocations.length == _recipients.length, InitialAllocationsLengthMismatch());

        recipientsData = abi.encode(_recipients, _initialAllocations);

        _sortAddressesAndAllocations(_recipients, _initialAllocations);

        splitsContract =
            ISplitMain(scaffoldIE.getSplits()).createSplit(_recipients, _initialAllocations, 0, address(this));
    }

    function _beforeEvaluation(bytes memory _data) internal {
        AttestationRequestData memory attestationRequestData = AttestationRequestData({
            recipient: address(0),
            expirationTime: 0,
            revocable: true,
            refUID: bytes32(0),
            data: _data,
            value: 0
        });
        AttestationRequest memory request = AttestationRequest({ schema: schemaUID, data: attestationRequestData });

        eas.attest(request);
    }

    function _evaluate(bytes memory _data) internal returns (bytes memory) {
        // This should follow the schema
        (, uint32[] memory _allocations,,,) = abi.decode(_data, (string, uint32[], address, uint256, address));
        address[] memory recipients = abi.decode(recipientsData, (address[]));

        require(_allocations.length == recipients.length, InitialAllocationsLengthMismatch());

        _sortAddressesAndAllocations(recipients, _allocations);

        ISplitMain(scaffoldIE.getSplits()).updateSplit(splitsContract, recipients, _allocations, 0);

        return abi.encode(recipients, _allocations);
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
