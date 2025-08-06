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

    /// @return The pool ID
    function getPoolId() external view returns (uint256) {
        return poolId;
    }

    /// @param _data The data for creating the IE
    function createIE(bytes memory _data) external virtual { }

    /// @param _data The data for creating the IE
    function _beforeCreateIE(bytes memory _data) internal virtual { }

    /// @param _data The data for creating the IE
    function _afterCreateIE(bytes memory _data) internal virtual { }

    /// @param _data The data for creating the IE
    function _createIE(bytes memory _data) internal virtual { }

    /// @param _data The data for the evaluation
    /// @param _caller The caller address
    function evaluate(bytes memory _data, address _caller) external virtual { }

    /// @param _recipients The recipients addresses
    /// @param _caller The caller address
    function registerRecipients(address[] memory _recipients, address _caller) external virtual { }

    /// @param _recipients The recipients addresses
    /// @param _caller The caller address
    function updateRecipients(address[] memory _recipients, address _caller) external virtual { }

    /// @param _recipients The recipients addresses
    function _registerRecipients(address[] memory _recipients) internal virtual { }

    /// @return The recipients addresses
    function getRecipients() external view virtual returns (address[] memory) { }

    /// @param _data The evaluation data
    function _evaluate(bytes memory _data) internal virtual { }

    /// @param _data The evaluation data
    function _beforeEvaluation(bytes memory _data) internal virtual { }

    /// @param _data The evaluation data
    function _afterEvaluation(bytes memory _data) internal virtual { }

    /// @param _poolId The pool ID
    /// @param _initializeData The initialization data
    /// @param _scaffoldIE The scaffold IE address
    function initialize(uint256 _poolId, bytes memory _initializeData, address _scaffoldIE) external virtual { }

    /// @param _initializeData The initialization data
    function _initialize(bytes memory _initializeData) internal virtual { }

    /// @param _poolId The pool ID
    /// @param _initializeData The initialization data
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
