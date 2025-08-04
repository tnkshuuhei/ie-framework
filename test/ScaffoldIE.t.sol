// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29 <0.9.0;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { ScaffoldIE } from "../contracts/ScaffoldIE.sol";
import { IScaffoldIE } from "../contracts/interfaces/IScaffoldIE.sol";
import { ProtocolGuild } from "../contracts/IEstrategies/ProtocolGuild.sol";
import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { ISplitMain } from "../contracts/interfaces/ISplitMain.sol";
import { IHatsModuleFactory } from "../contracts/interfaces/IHatsModuleFactory.sol";
import { IHatsHatCreatorModule } from "../contracts/Hats/IHatCreatorModule.sol";
import { IHatsTimeControlModule } from "../contracts/Hats/ITimeControlModule.sol";
import { HatsHatCreatorModule } from "../contracts/Hats/HatCreatorModule.sol";
import { HatsTimeControlModule } from "../contracts/Hats/TimeControlModule.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// TODO: fix test
contract ScaffoldIETest is Test {
    IScaffoldIE public scaffoldIE;
    ProtocolGuild public protocolGuild;

    IHatsModuleFactory public hatsModuleFactory;
    IHats public hats;
    ISplitMain public splits;

    address public currentPrankee;
    address public creatorModuleImpl;
    address public timeControlModuleImpl;
    address public owner = makeAddr("owner");

    address public recipient1 = address(0x1);
    address public recipient2 = address(0x2);
    address public recipient3 = address(0x3);
    address public evaluator1 = makeAddr("evaluator1");
    address public evaluator2 = makeAddr("evaluator2");
    address public evaluator3 = makeAddr("evaluator3");

    address[] public evaluators = [evaluator1, evaluator2];

    event PoolCreated(uint256 poolId, address indexed strategy);

    function setUp() public {
        configureChain();

        creatorModuleImpl = address(new HatsHatCreatorModule("v0.1.0"));
        timeControlModuleImpl = address(new HatsTimeControlModule("v0.1.0"));

        scaffoldIE =
            new ScaffoldIE(owner, address(hats), address(splits), hatsModuleFactory, address(creatorModuleImpl));

        protocolGuild = new ProtocolGuild(address(scaffoldIE));
    }

    function testCreateIE() external {
        ProtocolGuild.Recipient[] memory recipients = new ProtocolGuild.Recipient[](3);
        recipients[0] =
            ProtocolGuild.Recipient({ recipient: recipient1, recipientType: ProtocolGuild.RecipientType.FullTime });
        recipients[1] =
            ProtocolGuild.Recipient({ recipient: recipient2, recipientType: ProtocolGuild.RecipientType.PartTime });
        recipients[2] =
            ProtocolGuild.Recipient({ recipient: recipient3, recipientType: ProtocolGuild.RecipientType.FullTime });

        bytes memory data = abi.encode(
            timeControlModuleImpl,
            recipients,
            "ipfs://TopHatMetadata",
            "ipfs://TopHatImageURL",
            "ipfs://ManagerHatMetadata",
            "ipfs://ManagerHatImageURL",
            "ipfs://EvaluatorHatMetadata",
            "ipfs://RecipientHatMetadata",
            evaluators
        );

        vm.startPrank(owner);

        (, uint256 poolId) = scaffoldIE.createIE(data, address(protocolGuild));
        assertEq(poolId, 1);

        address splitsContract = protocolGuild.splitsContract();
        address controller = splits.getController(splitsContract);
        assertEq(controller, address(protocolGuild));
        vm.stopPrank();
    }

    function testEvaluate() external {
        uint256 poolId = _createPool(owner);

        // 1month
        vm.warp(block.timestamp + 30 * 86_400);

        vm.startPrank(evaluator1);

        // Create recipients data for evaluation
        ProtocolGuild.Recipient[] memory recipients = new ProtocolGuild.Recipient[](3);
        recipients[0] =
            ProtocolGuild.Recipient({ recipient: recipient1, recipientType: ProtocolGuild.RecipientType.FullTime });
        recipients[1] =
            ProtocolGuild.Recipient({ recipient: recipient2, recipientType: ProtocolGuild.RecipientType.PartTime });
        recipients[2] =
            ProtocolGuild.Recipient({ recipient: recipient3, recipientType: ProtocolGuild.RecipientType.FullTime });

        bytes memory result = scaffoldIE.evaluate(poolId, "0x");
        (, uint32[] memory allocations) = abi.decode(result, (address[], uint32[]));

        assertEq(allocations[0] > allocations[1], true);
        assertEq(allocations[2] > allocations[1], true);

        vm.stopPrank();
    }

    function testDeployments() public view {
        assertEq(scaffoldIE.getHatsModuleFactory(), address(hatsModuleFactory));
        assertEq(scaffoldIE.getHatCreatorModuleImpl(), address(creatorModuleImpl));
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

    function _createPool(address _prankee) internal prankception(_prankee) returns (uint256) {
        ProtocolGuild.Recipient[] memory recipients = new ProtocolGuild.Recipient[](3);
        recipients[0] =
            ProtocolGuild.Recipient({ recipient: recipient1, recipientType: ProtocolGuild.RecipientType.FullTime });
        recipients[1] =
            ProtocolGuild.Recipient({ recipient: recipient2, recipientType: ProtocolGuild.RecipientType.PartTime });
        recipients[2] =
            ProtocolGuild.Recipient({ recipient: recipient3, recipientType: ProtocolGuild.RecipientType.FullTime });

        bytes memory data = abi.encode(
            timeControlModuleImpl,
            recipients,
            "ipfs://TopHatMetadata",
            "ipfs://TopHatImageURL",
            "ipfs://ManagerHatMetadata",
            "ipfs://ManagerHatImageURL",
            "ipfs://EvaluatorHatMetadata",
            "ipfs://RecipientHatMetadata",
            evaluators
        );

        (, uint256 poolId) = scaffoldIE.createIE(data, address(protocolGuild));
        return poolId;
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
