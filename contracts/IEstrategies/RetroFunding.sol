// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IEAS, Attestation, AttestationRequest, AttestationRequestData } from "eas-contracts/IEAS.sol";
import { ISchemaRegistry } from "eas-contracts/ISchemaRegistry.sol";
import { SchemaResolver } from "eas-contracts/resolver/SchemaResolver.sol";
import { ISchemaResolver } from "eas-contracts/resolver/ISchemaResolver.sol";

import { BaseIEStrategy } from "./BaseIEStrategy.sol";
import { ISplitMain } from "../interfaces/ISplitMain.sol";

contract AttesterResolver is SchemaResolver {
    address private immutable _targetAttester;

    constructor(IEAS eas, address targetAttester) SchemaResolver(eas) {
        _targetAttester = targetAttester;
    }

    function onAttest(Attestation calldata attestation, uint256 /*value*/ ) internal view override returns (bool) {
        return attestation.attester == _targetAttester;
    }

    function onRevoke(Attestation calldata, /*attestation*/ uint256 /*value*/ ) internal pure override returns (bool) {
        return true;
    }
}

contract RetroFunding is BaseIEStrategy {
    constructor(
        address _scaffoldIE,
        address _eas,
        address _schemaRegistry
    )
        BaseIEStrategy(_scaffoldIE, "RetroFundingStrategy")
    {
        eas = IEAS(_eas);
        schemaRegistry = ISchemaRegistry(_schemaRegistry);
        // TODO: fix target attester
        resolver = new AttesterResolver(eas, address(this));
    }

    // "string datasets, address[] recipients, uint32[] allocations , address contract, uint256 chainId, address
    // attester"
    string public schema;
    bytes32 public schemaUID;
    uint256 public topHatId;
    uint256 public recipientHatId;
    uint256 public evaluatorHatId;
    address public splitsContract;
    address[] public recipients;

    IEAS public eas;
    ISchemaRegistry public schemaRegistry;
    ISchemaResolver public resolver;

    event AttestationCreated(bytes32 attestationUID);
    event Evaluated(address[] recipients, uint32[] allocations);

    function _beforeCreateIE(bytes memory _data) internal override {
        (string memory _schema,,,,,,,,,) =
            abi.decode(_data, (string, address[], string, string, string, string, string, string, address[], uint32[]));
        // revocable schema
        schemaUID = schemaRegistry.register(_schema, resolver, true);
        schema = _schema;
    }

    function createIE(bytes memory _data) external override returns (uint256) {
        _beforeCreateIE(_data);
        topHatId = _createIE(_data);

        return topHatId;
    }

    function _createIE(bytes memory _data) internal override returns (uint256) {
        (
            ,
            address[] memory _recipients,
            string memory _topHatMetadata,
            string memory _topHatImageURL,
            string memory _managerHatMetadata,
            string memory _managerHatImageURL,
            string memory _evaluatorMetadata,
            string memory _recipientHatMetadata,
            address[] memory _evaluators,
            uint32[] memory _initialAllocations
        ) = abi.decode(_data, (string, address[], string, string, string, string, string, string, address[], uint32[]));
        recipients = _recipients;
        IHats hats = IHats(scaffoldIE.getHats());

        topHatId = hats.mintTopHat(address(this), _topHatMetadata, _topHatImageURL);
        // create manager hats under the top hat
        uint256 managerHatId = hats.createHat(
            topHatId, // parent hatId
            _managerHatMetadata, // should be ipfs://cid for data (e.g.
                // https://ipfs.io/ipfs/bafkreigbzej36xhwpu2qt7zzmdv3yei446e2mmgv7u7hl4dfrz3dswwd6y)
            2, // max supply is the number of modules (TODO: change to actual max supply) (evaluator + recipient hats)
            0x0000000000000000000000000000000000004A75,
            0x0000000000000000000000000000000000004A75,
            true,
            _managerHatImageURL
        );
        address hatCreatorModule = IHatsModuleFactory(scaffoldIE.getHatsModuleFactory()).createHatsModule(
            scaffoldIE.getHatCreatorModuleImpl(), managerHatId, "", abi.encode(managerHatId), 0
        );
        hats.mintHat(managerHatId, hatCreatorModule);
        evaluatorHatId = IHatsHatCreatorModule(hatCreatorModule).createHat(
            managerHatId,
            _evaluatorMetadata,
            uint32(_evaluators.length),
            0x0000000000000000000000000000000000004A75, // TODO: change to actual eligibility
            0x0000000000000000000000000000000000004A75, // TODO: change to actual toggle
            true, // mutable
            "" // imageURL
        );

        recipientHatId = IHatsHatCreatorModule(hatCreatorModule).createHat(
            managerHatId,
            _recipientHatMetadata,
            uint32(recipients.length),
            0x0000000000000000000000000000000000004A75, // TODO: change to actual eligibility
            0x0000000000000000000000000000000000004A75, // TODO: change to actual toggle
            true, // mutable
            "" // imageURL
        );

        for (uint256 i = 0; i < _evaluators.length; i++) {
            address evaluator = _evaluators[i];
            hats.mintHat(evaluatorHatId, evaluator);
        }

        for (uint256 i = 0; i < _recipients.length; i++) {
            address recipient = _recipients[i];
            hats.mintHat(recipientHatId, recipient);
        }
        splitsContract =
            ISplitMain(scaffoldIE.getSplits()).createSplit(_recipients, _initialAllocations, 0, address(this));

        return topHatId;
    }

    // TODO:
    // this evaluate function behaves:
    // 1. create attestation
    // 2. update splits
    function evaluate(bytes memory _data) external override returns (bytes memory) {
        _beforeEvaluation(_data);
        bytes memory result = _evaluate(_data);

        return result;
    }

    function _evaluate(bytes memory _data) internal override returns (bytes memory) {
        (bytes memory attestationData) = abi.decode(_data, (bytes));

        // This should follow the schema
        (, address[] memory _recipients, uint32[] memory _allocations,,,) =
            abi.decode(attestationData, (string, address[], uint32[], address, uint256, address));

        ISplitMain(scaffoldIE.getSplits()).updateSplit(splitsContract, _recipients, _allocations, 0);
        emit Evaluated(_recipients, _allocations);

        return abi.encode(_recipients, _allocations);
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
}
