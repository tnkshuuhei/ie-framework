// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IStrategy {
    error NotImplemented();
    error AlreadyInitialized();
    error OnlyScaffoldIE(address _caller);
    error NotInitialized();

    /// @param _data The data for creating the IE
    function createIE(bytes memory _data) external;

    /// @param _data The evaluation data
    /// @param _caller The caller address
    function evaluate(bytes memory _data, address _caller) external;

    /// @param _poolId The pool ID
    /// @param _initializeData The initialization data
    /// @param _scaffoldIE The scaffold IE address
    function initialize(uint256 _poolId, bytes memory _initializeData, address _scaffoldIE) external;

    /// @param _recipients The recipients addresses
    /// @param _caller The caller address
    function registerRecipients(address[] memory _recipients, address _caller) external;

    /// @param _recipients The recipients addresses
    /// @param _caller The caller address
    function updateRecipients(address[] memory _recipients, address _caller) external;

    /// @return The recipients addresses
    function getRecipients() external view returns (address[] memory);

    /// @param _evaluator The evaluator address
    /// @param _caller The caller address
    function addEvaluator(address _evaluator, address _caller) external;

    /// @param _evaluator The evaluator address
    /// @param _caller The caller address
    function removeEvaluator(address _evaluator, address _caller) external;

    /// @param _manager The manager address
    /// @param _caller The caller address
    function addManager(address _manager, address _caller) external;

    /// @param _manager The manager address
    /// @param _caller The caller address
    function removeManager(address _manager, address _caller) external;

    /// @return The strategy address
    function getAddress() external view returns (address);
}
