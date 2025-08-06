// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IEAS, Attestation, AttestationRequest, AttestationRequestData } from "eas-contracts/IEAS.sol";
import { BaseIEStrategy } from "./BaseIEStrategy.sol";
import { ISplitMain } from "../interfaces/ISplitMain.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { AttesterResolver } from "../AttesterResolver.sol";
import { IScaffoldIE } from "../interfaces/IScaffoldIE.sol";

contract RetroFunding is BaseIEStrategy, AccessControl, Pausable {
    // State variables
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant EVALUATOR_ROLE = keccak256("EVALUATOR_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    string public schema;
    bytes32 public schemaUID;
    address public splitsContract;

    IEAS public eas;

    // Events
    event AttestationCreated(bytes32 attestationUID);
    event Evaluated(address[] recipients, uint32[] allocations);

    // Errors
    error InvalidEvaluator(address _caller);
    error InvalidManager(address _caller);

    function initialize(uint256 _poolId, bytes memory _initializeData, address _scaffoldIE) external override {
        // Check that the caller is the ScaffoldIE contract
        require(msg.sender == _scaffoldIE, OnlyScaffoldIE(msg.sender));

        scaffoldIE = IScaffoldIE(_scaffoldIE);

        __BaseStrategyInit(_poolId, _initializeData);
    }

    function _initialize(bytes memory _initializeData) internal override {
        name = "RetroFundingStrategy";

        (address _eas, bytes32 _schemaUID, address _admin) = abi.decode(_initializeData, (address, bytes32, address));
        eas = IEAS(_eas);
        schemaUID = _schemaUID;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
    }

    // Public/External functions
    function getAddress() external view returns (address) {
        return splitsContract;
    }

    function createIE(bytes memory _data) external override onlyScaffoldIE onlyInitialized {
        _createIE(_data);
    }

    function evaluate(
        bytes memory _data,
        address _caller
    )
        external
        override
        onlyEvaluator(_caller)
        onlyScaffoldIE
        onlyInitialized
    {
        _beforeEvaluation(_data);
        _evaluate(_data);
    }

    function registerRecipients(
        address[] memory _recipients,
        address _caller
    )
        external
        override
        onlyManager(_caller)
        onlyScaffoldIE
        onlyInitialized
    {
        _registerRecipients(_recipients);
    }

    function _registerRecipients(address[] memory _recipients) internal override {
        recipients = _recipients;
    }

    function updateRecipients(
        address[] memory _recipients,
        address _caller
    )
        external
        override
        onlyManager(_caller)
        onlyScaffoldIE
        onlyInitialized
    {
        _updateRecipients(_recipients);
    }

    function _updateRecipients(address[] memory _recipients) internal {
        recipients = _recipients;
    }

    // Internal functions

    /// @notice Create an IE
    /// @param _data The data to create the IE
    /// @dev The data is a string, address[], uint32[]
    /// @dev address[]: recipients
    /// @dev uint32[]: initial allocations
    function _createIE(bytes memory _data) internal override {
        (address[] memory _recipients, uint32[] memory _initialAllocations) = abi.decode(_data, (address[], uint32[]));
        recipients = _recipients;

        splitsContract =
            ISplitMain(scaffoldIE.getSplits()).createSplit(_recipients, _initialAllocations, 0, address(this));
    }

    function _beforeEvaluation(bytes memory _data) internal override {
        AttestationRequestData memory attestationRequestData = AttestationRequestData({
            recipient: address(0),
            expirationTime: 0,
            revocable: true,
            refUID: bytes32(0),
            data: _data,
            value: 0
        });
        AttestationRequest memory request = AttestationRequest({ schema: schemaUID, data: attestationRequestData });

        bytes32 attestationUID = eas.attest(request);
        emit AttestationCreated(attestationUID);
    }

    function _evaluate(bytes memory _data) internal override {
        // This should follow the schema
        (, address[] memory _recipients, uint32[] memory _allocations,,,) =
            abi.decode(_data, (string, address[], uint32[], address, uint256, address));

        ISplitMain(scaffoldIE.getSplits()).updateSplit(splitsContract, _recipients, _allocations, 0);
        emit Evaluated(_recipients, _allocations);
    }

    function _beforeCreateIE(bytes memory _data) internal override {
        revert NotImplemented();
    }

    function _afterEvaluation(bytes memory _data) internal override {
        revert NotImplemented();
    }

    function getRecipients() external view override returns (address[] memory) {
        return recipients;
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
