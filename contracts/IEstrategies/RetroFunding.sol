// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IEAS, Attestation, AttestationRequest, AttestationRequestData } from "eas-contracts/IEAS.sol";
import { ISchemaRegistry } from "eas-contracts/ISchemaRegistry.sol";
import { ISchemaResolver } from "eas-contracts/resolver/ISchemaResolver.sol";
import { BaseIEStrategy } from "./BaseIEStrategy.sol";
import { ISplitMain } from "../interfaces/ISplitMain.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { AttesterResolver } from "../AttesterResolver.sol";

contract RetroFunding is BaseIEStrategy, AccessControl, Pausable {
    // State variables
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant EVALUATOR_ROLE = keccak256("EVALUATOR_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // "string datasets, address[] recipients, uint32[] allocations , address contract, uint256 chainId, address
    // attester"
    string public schema;
    bytes32 public schemaUID;
    address public splitsContract;

    IEAS public eas;
    ISchemaRegistry public schemaRegistry;
    ISchemaResolver public schemaResolver;

    // Events
    event AttestationCreated(bytes32 attestationUID);
    event Evaluated(address[] recipients, uint32[] allocations);

    // Errors
    error InvalidEvaluator(address _caller);
    error InvalidManager(address _caller);

    // Constructor
    constructor(
        address _admin,
        address _scaffoldIE,
        address _eas,
        address _schemaRegistry
    )
        BaseIEStrategy(_scaffoldIE, "RetroFundingStrategy")
    {
        // TODO: consider using hypercerts v2 attestations for eval, measurement
        eas = IEAS(_eas);
        schemaRegistry = ISchemaRegistry(_schemaRegistry);

        // only this contract can attest
        schemaResolver = new AttesterResolver(eas, address(this));

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
    }

    // Public/External functions
    function getAddress() external view returns (address) {
        return splitsContract;
    }

    function initialize(uint256 _poolId, bytes memory _data) external override onlyScaffoldIE {
        _beforeCreateIE(_data);
    }

    function createIE(bytes memory _data) external override onlyScaffoldIE {
        _beforeCreateIE(_data);
        _createIE(_data);
    }

    function evaluate(bytes memory _data, address _caller) external override onlyEvaluator(_caller) onlyScaffoldIE {
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
    {
        _updateRecipients(_recipients);
    }

    function _updateRecipients(address[] memory _recipients) internal {
        recipients = _recipients;
    }

    // Internal functions
    function _beforeCreateIE(bytes memory _data) internal override {
        (string memory _schema) = abi.decode(_data, (string));

        schemaUID = schemaRegistry.register(_schema, schemaResolver, true);
        schema = _schema;
    }

    function _createIE(bytes memory _data) internal override {
        (, address[] memory _recipients, uint32[] memory _initialAllocations) =
            abi.decode(_data, (string, address[], uint32[]));
        recipients = _recipients;

        splitsContract =
            ISplitMain(scaffoldIE.getSplits()).createSplit(_recipients, _initialAllocations, 0, address(this));
    }

    function _beforeEvaluation(bytes memory _data) internal override {
        (bytes memory attestationData) = abi.decode(_data, (bytes));
        AttestationRequestData memory attestationRequestData = AttestationRequestData({
            recipient: address(0),
            expirationTime: 0,
            revocable: true,
            refUID: 0x0,
            data: attestationData,
            value: 0
        });
        AttestationRequest memory request = AttestationRequest({ schema: schemaUID, data: attestationRequestData });

        bytes32 attestationUID = eas.attest(request);
        emit AttestationCreated(attestationUID);
    }

    function _evaluate(bytes memory _data) internal override {
        (bytes memory attestationData) = abi.decode(_data, (bytes));

        // This should follow the schema
        (, address[] memory _recipients, uint32[] memory _allocations,,,) =
            abi.decode(attestationData, (string, address[], uint32[], address, uint256, address));

        ISplitMain(scaffoldIE.getSplits()).updateSplit(splitsContract, _recipients, _allocations, 0);
        emit Evaluated(_recipients, _allocations);

        // TODO: return attestation data
    }

    function _afterEvaluation(bytes memory _data) internal override {
        revert NotImplemented();
    }

    function getRecipients() external view override returns (address[] memory) {
        return recipients;
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
}
