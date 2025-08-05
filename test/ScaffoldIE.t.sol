// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29 <0.9.0;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ScaffoldIE } from "../contracts/ScaffoldIE.sol";
import { IScaffoldIE } from "../contracts/interfaces/IScaffoldIE.sol";
import { ISplitMain } from "../contracts/interfaces/ISplitMain.sol";

contract ScaffoldIETest is Test {
    IScaffoldIE public scaffoldIE;
    ISplitMain public splits;

    address public currentPrankee;
    address public owner = makeAddr("owner");

    address public recipient1 = address(0x1);
    address public recipient2 = address(0x2);
    address public recipient3 = address(0x3);
    address public evaluator1 = makeAddr("evaluator1");
    address public evaluator2 = makeAddr("evaluator2");
    address public evaluator3 = makeAddr("evaluator3");

    function setUp() public {
        configureChain();

        scaffoldIE = new ScaffoldIE(owner, address(splits));
    }

    function testDeployments() public view {
        assertNotEq(address(scaffoldIE), address(0));
    }

    function configureChain() public {
        uint256 chainId = block.chainid;
        if (chainId == 11_155_111) {
            splits = ISplitMain(0x54E4a6014D36c381fC43b7E24A1492F556139a6F);
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
