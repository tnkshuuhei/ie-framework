// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { SchemaResolver } from "eas-contracts/resolver/SchemaResolver.sol";

import { IEAS, Attestation } from "eas-contracts/IEAS.sol";

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
