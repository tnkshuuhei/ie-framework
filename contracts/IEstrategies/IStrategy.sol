// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IStrategy {
    function createIE(bytes memory _data) external;
    function evaluate(bytes memory _data) external returns (bytes memory);
}
