// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { BaseScript } from "./Base.s.sol";
import { console2 } from "forge-std/src/console2.sol";

import { ScaffoldIE } from "../contracts/ScaffoldIE.sol";
import { RetroFunding } from "../contracts/IEstrategies/RetroFunding.sol";
import { ISplitMain } from "../contracts/interfaces/ISplitMain.sol";
import { IEAS } from "eas-contracts/IEAS.sol";
import { ISchemaRegistry } from "eas-contracts/ISchemaRegistry.sol";

contract Deploy is BaseScript {
    ISplitMain public splits;
    IEAS public eas;
    ISchemaRegistry public schemaRegistry;
    ScaffoldIE public scaffoldIE;
    RetroFunding public retroFunding;
    bytes32 public schemaUID;

    function configureChain() public {
        uint256 chainId = block.chainid;
        if (chainId == 11_155_111) {
            splits = ISplitMain(0x54E4a6014D36c381fC43b7E24A1492F556139a6F);
            eas = IEAS(0xC2679fBD37d54388Ce493F1DB75320D236e1815e);
            schemaRegistry = ISchemaRegistry(0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0);
            schemaUID = 0x78add97290831dd54d5e4599a0a1dc1ada8278264c93c801d72adddea395e26f;
        }
    }

    function run() public broadcast {
        configureChain();

        scaffoldIE = new ScaffoldIE(broadcaster, address(splits));
        console2.log("ScaffoldIE deployed");
        console2.log("ScaffoldIE address: %s", address(scaffoldIE));

        retroFunding = new RetroFunding();
        console2.log("RetroFunding deployed");
        console2.log("RetroFunding address: %s", address(retroFunding));

        console2.log("Setting cloneable strategy");
        scaffoldIE.setCloneableStrategy(address(retroFunding), true);
        console2.log("Cloneable strategy set");

        address[] memory _recipients = new address[](2);
        _recipients[0] = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
        _recipients[1] = 0xc3593524E2744E547f013E17E6b0776Bc27Fc614;

        uint32[] memory _initialAllocations = new uint32[](2);
        _initialAllocations[0] = 5e5;
        _initialAllocations[1] = 5e5;
        bytes memory data = abi.encode(_recipients, _initialAllocations);

        bytes memory initializeData = abi.encode(address(eas), schemaUID, broadcaster);

        console2.log("Creating IE");
        scaffoldIE.createIE(data, initializeData, address(retroFunding));
        console2.log("IE created");

        console2.log("Create second IE");

        uint32[] memory _initialAllocations2 = new uint32[](2);
        _initialAllocations2[0] = 5e5;
        _initialAllocations2[1] = 5e5;
        bytes memory data2 = abi.encode(_recipients, _initialAllocations2);
        bytes memory initializeData2 = abi.encode(address(eas), schemaUID, broadcaster);
        scaffoldIE.createIE(data2, initializeData2, address(retroFunding));
        console2.log("Second IE created");
        console2.log("Creating IE route");
        scaffoldIE.createIERoute(_initialAllocations);
        console2.log("IE route created");

        console2.log("RootSplit: %s", address(scaffoldIE.rootSplit()));
        console2.log("PoolCount: %s", scaffoldIE.getPoolCount());
        console2.log("Strategy: %s", address(scaffoldIE.poolIdToStrategy(0)));
        console2.log("Strategy2: %s", address(scaffoldIE.poolIdToStrategy(1)));
    }
}
