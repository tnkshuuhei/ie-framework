// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IScaffoldIE } from "../interfaces/IScaffoldIE.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";

abstract contract BaseIEStrategy is IStrategy {
    IScaffoldIE public scaffoldIE;
    uint256 public poolId;
    string public name;
    address[] public recipients;

    modifier onlyScaffoldIE() {
        require(msg.sender == address(scaffoldIE), OnlyScaffoldIE());
        _;
    }

    constructor(address _scaffoldIE, string memory _name) {
        scaffoldIE = IScaffoldIE(_scaffoldIE);
        name = _name;
    }

    function getPoolId() external view returns (uint256) {
        return poolId;
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

    function getRecipients() external view virtual returns (address[] memory) { }

    function _evaluate(bytes memory _data) internal virtual { }

    function _beforeEvaluation(bytes memory _data) internal virtual { }

    function _afterEvaluation(bytes memory _data) internal virtual { }

    function initialize(uint256 _poolId, bytes memory _data) external {
        __BaseStrategyInit(_poolId, _data);
    }

    function __BaseStrategyInit(uint256 _poolId, bytes memory _data) internal {
        // TODO: check if the poolId is already initialized
        poolId = _poolId;
    }
}
