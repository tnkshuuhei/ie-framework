// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IStrategy {
    function createIE(bytes memory _data) external;
    function evaluate(bytes memory _data, address _caller) external;
    function initialize(uint256 _poolId, bytes memory _data) external;

    function registerRecipients(address[] memory _recipients, address _caller) external;

    function updateRecipients(address[] memory _recipients, address _caller) external;

    function getRecipients() external view returns (address[] memory);
}
