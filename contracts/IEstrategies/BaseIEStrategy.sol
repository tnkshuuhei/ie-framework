// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IScaffoldIE } from "../interfaces/IScaffoldIE.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";

abstract contract BaseIEStrategy is IStrategy {
    IScaffoldIE public scaffoldIE;
    uint256 public poolId;
    string public name;
    bytes public recipientsData;
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

    /// @param _data The data for registering the recipients
    /// @param _caller The caller address
    function registerRecipients(bytes memory _data, address _caller) external virtual { }

    /// @param _data The data for updating the recipients
    /// @param _caller The caller address
    function updateRecipients(bytes memory _data, address _caller) external virtual { }

    /// @param _data The data for registering the recipients
    function _registerRecipients(bytes memory _data) internal virtual { }

    /// @param _data The data for updating the recipients
    function _updateRecipients(bytes memory _data) internal virtual { }

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

    /// @param _addresses The addresses to sort
    /// @param _allocations The allocations to sort
    function _sortAddressesAndAllocations(address[] memory _addresses, uint32[] memory _allocations) internal pure {
        uint256 length = _addresses.length;
        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                if (_addresses[j] > _addresses[j + 1]) {
                    address tempAddress = _addresses[j];
                    _addresses[j] = _addresses[j + 1];
                    _addresses[j + 1] = tempAddress;

                    uint32 tempAllocation = _allocations[j];
                    _allocations[j] = _allocations[j + 1];
                    _allocations[j + 1] = tempAllocation;
                }
            }
        }
    }
}
