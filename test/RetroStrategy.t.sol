// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { ScaffoldIE } from "../contracts/ScaffoldIE.sol";
import { RetroFundingManual } from "../contracts/IEstrategies/RetroFundingManual.sol";
import { ISplitMain } from "../contracts/interfaces/ISplitMain.sol";
import { console2 } from "forge-std/src/console2.sol";
import { IEAS, Attestation, AttestationRequest, AttestationRequestData } from "eas-contracts/IEAS.sol";
import { ISchemaRegistry } from "eas-contracts/ISchemaRegistry.sol";

import { IStrategy } from "../contracts/interfaces/IStrategy.sol";
import { IScaffoldIE } from "../contracts/interfaces/IScaffoldIE.sol";

contract RetroStrategyTest is Test {
    ScaffoldIE public scaffoldIE;
    RetroFundingManual public retroFunding;
    ISplitMain public splits;
    IEAS public eas;
    ISchemaRegistry public schemaRegistry;
    bytes32 public schemaUID;

    address public currentPrankee;
    address public admin = makeAddr("admin");
    address public splitter = makeAddr("splitter");
    address public evaluator = makeAddr("evaluator");
    address public manager = makeAddr("manager");

    address public recipient1 = address(0x1);
    address public recipient2 = address(0x2);
    address public recipient3 = address(0x3);
    address public recipient4 = address(0x4);

    function setUp() public {
        configureChain();
        scaffoldIE = new ScaffoldIE(admin, address(splits));
        retroFunding = new RetroFundingManual(); // implementation

        vm.startPrank(admin);
        scaffoldIE.setCloneableStrategy(address(retroFunding), true);
        vm.stopPrank();
    }

    function testDeployments() public view {
        assertNotEq(address(scaffoldIE), address(0));
        assertEq(scaffoldIE.getSplits(), address(splits));

        assertNotEq(address(retroFunding), address(0));
    }

    function testCreateIE() public {
        address[] memory _recipients = new address[](2);
        _recipients[0] = recipient1;
        _recipients[1] = recipient2;

        uint32[] memory _initialAllocations = new uint32[](2);
        _initialAllocations[0] = 5e5;
        _initialAllocations[1] = 5e5;
        bytes memory data = abi.encode(_recipients, _initialAllocations);

        bytes memory initializeData = abi.encode(address(eas), schemaUID, admin);

        // Execute test
        vm.startPrank(admin);
        scaffoldIE.createIE(data, initializeData, address(retroFunding));

        // Verify results
        assertEq(scaffoldIE.getPoolCount(), 1);
        // Get the actual strategy address that was created
        address actualStrategy = scaffoldIE.getStrategy(0);
        assertNotEq(actualStrategy, address(0));
        vm.stopPrank();
    }

    function testCreateIERoute() public {
        // Create IE beforehand
        testCreateIE();
        // Create second IE
        _createIE(address(retroFunding));

        // Mock ISplitMain.createSplit call
        address[] memory IEs = new address[](2);
        IEs[0] = address(scaffoldIE.getStrategy(0));
        IEs[1] = address(scaffoldIE.getStrategy(1));
        uint32[] memory allocations = new uint32[](2);
        allocations[0] = 5e5;
        allocations[1] = 5e5;

        assertEq(allocations[0] + allocations[1], 1e6);
        assertEq(scaffoldIE.getPoolCount(), 2);

        vm.startPrank(admin);
        scaffoldIE.grantRole(scaffoldIE.getSplitterRole(), splitter);
        vm.stopPrank();

        // Execute test
        vm.startPrank(splitter);
        scaffoldIE.createIERoute(allocations);

        // Verify results
        assertNotEq(scaffoldIE.getRootSplit(), address(0));
    }

    function testUpdateRoute() public {
        // Create route beforehand
        testCreateIERoute();

        // Mock ISplitMain.updateSplit call
        address[] memory IEs = new address[](2);
        IEs[0] = address(scaffoldIE.getStrategy(0));
        IEs[1] = address(scaffoldIE.getStrategy(1));
        uint32[] memory newAllocations = new uint32[](2);
        newAllocations[0] = 5e5;
        newAllocations[1] = 5e5;

        vm.startPrank(admin);
        scaffoldIE.grantRole(scaffoldIE.getSplitterRole(), splitter);
        vm.stopPrank();

        // Execute test
        vm.prank(splitter);
        scaffoldIE.updateRoute(newAllocations);
    }

    function testRegisterRecipients() public {
        // Create IE beforehand
        testCreateIE();

        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        // Execute test
        vm.startPrank(admin);
        scaffoldIE.addManager(0, manager, admin);
        vm.stopPrank();
        vm.startPrank(manager);
        scaffoldIE.registerRecipients(0, abi.encode(recipients), manager);
        vm.stopPrank();

        // Check RetroFunding state
        address strategyAddress = scaffoldIE.getStrategy(0);
        bytes memory storedRecipients = IStrategy(strategyAddress).getRecipients();
        (address[] memory _recipients) = abi.decode(storedRecipients, (address[]));
        assertEq(_recipients.length, 2);
        assertEq(_recipients[0], recipient1);
        assertEq(_recipients[1], recipient2);
    }

    function testUpdateRecipients() public {
        // Create IE beforehand
        testCreateIE();

        address[] memory newRecipients = new address[](3);
        newRecipients[0] = recipient1;
        newRecipients[1] = recipient2;
        newRecipients[2] = recipient3;

        vm.startPrank(admin);
        scaffoldIE.addManager(0, manager, admin);
        vm.stopPrank();

        // Execute test
        vm.startPrank(manager);
        scaffoldIE.updateRecipients(0, abi.encode(newRecipients), manager);
        vm.stopPrank();

        // Check RetroFunding state
        address strategyAddress = scaffoldIE.getStrategy(0);
        bytes memory storedRecipients = IStrategy(strategyAddress).getRecipients();
        (address[] memory recipients) = abi.decode(storedRecipients, (address[]));
        assertEq(recipients.length, 3);
        assertEq(recipients[0], recipient1);
        assertEq(recipients[1], recipient2);
        assertEq(recipients[2], recipient3);
    }

    function testEvaluate() public {
        // Create IE beforehand
        testCreateIE();

        string memory dataset = "data";
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        uint32[] memory allocations = new uint32[](2);
        allocations[0] = 5e5;
        allocations[1] = 5e5;

        bytes memory evaluationData =
            abi.encode(dataset, recipients, allocations, address(retroFunding), block.chainid, evaluator);

        vm.startPrank(admin);
        scaffoldIE.addEvaluator(0, evaluator, admin);
        vm.stopPrank();

        // Execute test
        vm.startPrank(evaluator);
        scaffoldIE.evaluate(0, evaluationData, evaluator);
    }

    function _createIE(address strategy) internal prankception(admin) {
        address[] memory _recipients = new address[](4);
        _recipients[0] = recipient1;
        _recipients[1] = recipient2;
        _recipients[2] = recipient3;
        _recipients[3] = recipient4;

        uint32[] memory _initialAllocations = new uint32[](4);
        // 1e6 = 1,000,000
        _initialAllocations[0] = 250_000;
        _initialAllocations[1] = 250_000;
        _initialAllocations[2] = 250_000;
        _initialAllocations[3] = 250_000;

        bytes memory data = abi.encode(_recipients, _initialAllocations);

        bytes memory initializeData = abi.encode(address(eas), schemaUID, admin);

        scaffoldIE.createIE(data, initializeData, strategy);
    }

    function configureChain() public {
        uint256 chainId = block.chainid;
        if (chainId == 11_155_111) {
            splits = ISplitMain(0x54E4a6014D36c381fC43b7E24A1492F556139a6F);
            eas = IEAS(0xC2679fBD37d54388Ce493F1DB75320D236e1815e);
            schemaRegistry = ISchemaRegistry(0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0);
            schemaUID = 0x78add97290831dd54d5e4599a0a1dc1ada8278264c93c801d72adddea395e26f;
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
