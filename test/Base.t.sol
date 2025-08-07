// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { ScaffoldIE } from "../contracts/ScaffoldIE.sol";
import { RetroFundingManual } from "../contracts/IEstrategies/RetroFundingManual.sol";
import { ISplitMain } from "../contracts/interfaces/ISplitMain.sol";
import { IEAS } from "eas-contracts/IEAS.sol";
import { ISchemaRegistry } from "eas-contracts/ISchemaRegistry.sol";

contract Base is Test {
    ScaffoldIE public scaffoldIE;
    RetroFundingManual public retroFunding;
    ISplitMain public splits;
    IEAS public eas;
    ISchemaRegistry public schemaRegistry;
    address public currentPrankee;
    address public admin = makeAddr("admin");
    address public splitter = makeAddr("splitter");
    address public evaluator = makeAddr("evaluator");
    address public manager = makeAddr("manager");

    address public recipient1 = address(0x1);
    address public recipient2 = address(0x2);
    address public recipient3 = address(0x3);
    address public recipient4 = address(0x4);

    function _configureChain() internal {
        uint256 chainId = block.chainid;
        if (chainId == 11_155_111) {
            splits = ISplitMain(0x54E4a6014D36c381fC43b7E24A1492F556139a6F);
            eas = IEAS(0xC2679fBD37d54388Ce493F1DB75320D236e1815e);
            schemaRegistry = ISchemaRegistry(0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0);
        }
    }

    modifier prankception(address prankee) {
        address prankBefore = currentPrankee;
        vm.stopPrank();
        vm.startPrank(prankee);
        _;
        vm.stopPrank();
        if (prankBefore != address(0)) {
            vm.startPrank(prankBefore);
        }
    }
}
