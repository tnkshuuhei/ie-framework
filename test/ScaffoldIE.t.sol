// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29 <0.9.0;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { ScaffoldIE } from "../contracts/ScaffoldIE.sol";
import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { ISplitMain } from "../contracts/interfaces/ISplitMain.sol";
import { IHatsModuleFactory } from "../contracts/interfaces/IHatsModuleFactory.sol";
import { IHatsHatCreatorModule } from "../contracts/Hats/IHatCreatorModule.sol";
import { IHatsTimeControlModule } from "../contracts/Hats/ITimeControlModule.sol";
import { HatsHatCreatorModule } from "../contracts/Hats/HatCreatorModule.sol";
import { HatsTimeControlModule } from "../contracts/Hats/TimeControlModule.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract ScaffoldIETest is Test {
    ScaffoldIE public scaffoldIE;

    IHatsModuleFactory public hatsModuleFactory;
    IHats public hats;
    ISplitMain public splits;

    address public creatorModuleImpl;
    address public timeControlModuleImpl;
    address public owner = makeAddr("owner");

    function setUp() public {
        configureChain();

        creatorModuleImpl = address(new HatsHatCreatorModule("v0.1.0"));
        timeControlModuleImpl = address(new HatsTimeControlModule("v0.1.0"));

        scaffoldIE = new ScaffoldIE(
            owner,
            address(hats),
            address(splits),
            "ipfs://TopHatMetadata",
            "ipfs://TopHatImageURL",
            hatsModuleFactory,
            address(creatorModuleImpl),
            address(timeControlModuleImpl)
        );
    }

    function testDeployments() public view {
        assertEq(address(scaffoldIE.hatsModuleFactory()), address(hatsModuleFactory));
        assertEq(address(scaffoldIE.hats()), address(hats));
        assertEq(address(scaffoldIE.splits()), address(splits));
        assertEq(address(scaffoldIE.hatCreatorModuleImpl()), address(creatorModuleImpl));
        assertEq(address(scaffoldIE.timeControlModuleImpl()), address(timeControlModuleImpl));
        assertNotEq(address(scaffoldIE), address(0));
    }

    function configureChain() public {
        uint256 chainId = block.chainid;
        if (chainId == 11_155_111) {
            hatsModuleFactory = IHatsModuleFactory(0x0a3f85fa597B6a967271286aA0724811acDF5CD9);
            hats = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137);
            splits = ISplitMain(0x54E4a6014D36c381fC43b7E24A1492F556139a6F);
        }
    }
}
