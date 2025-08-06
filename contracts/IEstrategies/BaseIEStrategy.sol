// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IScaffoldIE } from "../interfaces/IScaffoldIE.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";

abstract contract BaseIEStrategy is IStrategy {
    IScaffoldIE public scaffoldIE;
    uint256 public poolId;
    string public name;
    address[] public recipients;
    bool public initialized;

    modifier onlyScaffoldIE() {
        require(msg.sender == address(scaffoldIE), OnlyScaffoldIE(msg.sender));
        _;
    }

    modifier onlyInitialized() {
        require(initialized, NotInitialized());
        _;
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

    function initialize(uint256 _poolId, bytes memory _initializeData, address _scaffoldIE) external {
        scaffoldIE = IScaffoldIE(_scaffoldIE);

        __BaseStrategyInit(_poolId, _initializeData);
    }

    function _initialize(bytes memory _initializeData) internal virtual { }

    function __BaseStrategyInit(uint256 _poolId, bytes memory _initializeData) internal {
        require(!initialized, AlreadyInitialized());
        _initialize(_initializeData);
        poolId = _poolId;
        _setInitialized();
    }

    function _setInitialized() internal {
        initialized = true;
    }
}
