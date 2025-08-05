// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IScaffoldIE } from "../interfaces/IScaffoldIE.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";

abstract contract BaseIEStrategy is IStrategy {
    IScaffoldIE public scaffoldIE;

    string public name;

    address[] public recipients;

    mapping(uint256 => bool) private initialized;

    error NotImplemented();

    error AlreadyInitialized();
    error OnlyScaffoldIE();

    modifier onlyScaffoldIE() {
        require(msg.sender == address(scaffoldIE), OnlyScaffoldIE());
        _;
    }

    constructor(address _scaffoldIE, string memory _name) {
        scaffoldIE = IScaffoldIE(_scaffoldIE);
        name = _name;
    }

    function createIE(bytes memory _data) external virtual { }

    function _beforeCreateIE(bytes memory _data) internal virtual { }

    function _afterCreateIE(bytes memory _data) internal virtual { }

    function _createIE(bytes memory _data) internal virtual { }

    /// @param _data The data for the evaluation
    function evaluate(bytes memory _data, address _caller) external virtual { }

    function registerRecipients(address[] memory _recipients, address _caller) external virtual { }

    function updateRecipients(address[] memory _recipients, address _caller) external virtual { }

    function _registerRecipients(address[] memory _recipients) internal virtual { }

    function getRecipients() external view returns (address[] memory) { }

    function _evaluate(bytes memory _data) internal virtual { }

    function _beforeEvaluation(bytes memory _data) internal virtual { }

    function _afterEvaluation(bytes memory _data) internal virtual { }

    function initialize(uint256 _poolId, bytes memory _data) external virtual onlyScaffoldIE {
        __BaseStrategyInit(_poolId, _data);
    }

    function __BaseStrategyInit(uint256 _poolId, bytes memory _data) internal virtual {
        if (initialized[_poolId]) {
            revert AlreadyInitialized();
        }
        initialized[_poolId] = true;
    }
}
