// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IScaffoldIE } from "../interfaces/IScaffoldIE.sol";

abstract contract BaseIEStrategy {
    IScaffoldIE public scaffoldIE;

    string public name;

    error NotImplemented();

    constructor(address _scaffoldIE, string memory _name) {
        scaffoldIE = IScaffoldIE(_scaffoldIE);
        name = _name;
    }

    // inside scaffoldIE
    // strategy.createIE(data)
    // poolId ++;
    // emit PoolCreated();
    // return poolId;
    function createIE(bytes memory _data) external virtual returns (uint256 id) {
        _beforeCreateIE(_data);
        id = _createIE(_data);
        _afterCreateIE(_data);
    }

    function _beforeCreateIE(bytes memory _data) internal virtual { }

    function _afterCreateIE(bytes memory _data) internal virtual { }

    function _createIE(bytes memory _data) internal virtual returns (uint256 id) { }

    /// @param _data The data for the evaluation
    function evaluate(bytes memory _data) external virtual returns (bytes memory result) {
        _beforeEvaluation(_data);
        result = _evaluate(_data);
        _afterEvaluation(_data);
        return result;
    }

    function _evaluate(bytes memory _data) internal virtual returns (bytes memory) { }

    function _beforeEvaluation(bytes memory _data) internal virtual { }

    function _afterEvaluation(bytes memory _data) internal virtual { }
}
