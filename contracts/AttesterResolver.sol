// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { SchemaResolver } from "eas-contracts/resolver/SchemaResolver.sol";

import { IEAS, Attestation } from "eas-contracts/IEAS.sol";

contract AttesterResolver is SchemaResolver {
    address private immutable _targetAttester;

    /// @param eas The EAS contract address
    /// @param targetAttester The target attester address
    constructor(IEAS eas, address targetAttester) SchemaResolver(eas) {
        _targetAttester = targetAttester;
    }

    /// @param attestation The attestation data
    /// @return Whether the attestation is valid
    function onAttest(Attestation calldata attestation, uint256 /*value*/ ) internal view override returns (bool) {
        return attestation.attester == _targetAttester;
    }

    /// @return Always returns true
    function onRevoke(Attestation calldata, /*attestation*/ uint256 /*value*/ ) internal pure override returns (bool) {
        return true;
    }
}
