// SPDX-License-Identifier: MIT

import { Base } from "./Base.t.sol";
import { ScaffoldIE } from "../contracts/ScaffoldIE.sol";
import { ProtocolGuild } from "../contracts/IEstrategies/ProtocolGuild.sol";
import { IStrategy } from "../contracts/interfaces/IStrategy.sol";

contract ProtocolGuildTest is Base {
    bytes32 public schemaUID;
    ProtocolGuild public protocolGuild;

    function setUp() public {
        _configureChain();
        schemaUID = 0x78add97290831dd54d5e4599a0a1dc1ada8278264c93c801d72adddea395e26f;
        scaffoldIE = new ScaffoldIE(admin, address(splits));
        protocolGuild = new ProtocolGuild(); // implementation

        vm.startPrank(admin);
        scaffoldIE.setCloneableStrategy(address(protocolGuild), true);
        vm.stopPrank();
    }

    function testDeployments() public view {
        assertNotEq(address(scaffoldIE), address(0));
        assertEq(scaffoldIE.getSplits(), address(splits));
        assertNotEq(address(protocolGuild), address(0));
    }

    function testCreateIE() public {
        address[] memory _recipients = new address[](5);
        _recipients[0] = recipient1;
        _recipients[1] = recipient2;
        _recipients[2] = recipient3;
        _recipients[3] = recipient4;
        _recipients[4] = address(5);

        ProtocolGuild.WorkType[] memory workTypes = new ProtocolGuild.WorkType[](5);
        workTypes[0] = ProtocolGuild.WorkType.FULL;
        workTypes[1] = ProtocolGuild.WorkType.PARTIAL;
        workTypes[2] = ProtocolGuild.WorkType.FULL;
        workTypes[3] = ProtocolGuild.WorkType.FULL;
        workTypes[4] = ProtocolGuild.WorkType.PARTIAL;

        uint32[] memory _initialAllocations = new uint32[](5);
        _initialAllocations[0] = 2e5;
        _initialAllocations[1] = 2e5;
        _initialAllocations[2] = 2e5;
        _initialAllocations[3] = 2e5;
        _initialAllocations[4] = 2e5;

        bytes memory data = abi.encode(_recipients, workTypes, _initialAllocations);

        bytes memory initializeData = abi.encode(address(eas), schemaUID, admin);

        // Execute test
        vm.startPrank(admin);
        scaffoldIE.createIE(data, initializeData, address(protocolGuild));

        // Verify results
        assertEq(scaffoldIE.getPoolCount(), 1);
        // Get the actual strategy address that was created
        address actualStrategy = scaffoldIE.getStrategy(0);
        assertNotEq(actualStrategy, address(0));
        vm.stopPrank();
    }

    function testEvaluateIE() public {
        testCreateIE();

        bytes memory evaluationData = abi.encode("data", address(protocolGuild), block.chainid, evaluator);

        vm.startPrank(admin);
        scaffoldIE.addEvaluator(0, evaluator, admin);
        vm.stopPrank();
        // warp 3months
        vm.warp(block.timestamp + 10 * 30 days);

        vm.startPrank(evaluator);
        scaffoldIE.evaluate(0, evaluationData, evaluator);
        vm.stopPrank();

        address[] memory _recipients = new address[](6);
        _recipients[0] = recipient1;
        _recipients[1] = recipient2;
        _recipients[2] = recipient3;
        _recipients[3] = recipient4;
        _recipients[4] = address(5);
        _recipients[5] = address(6);

        ProtocolGuild.WorkType[] memory workTypes = new ProtocolGuild.WorkType[](6);
        workTypes[0] = ProtocolGuild.WorkType.FULL;
        workTypes[1] = ProtocolGuild.WorkType.PARTIAL;
        workTypes[2] = ProtocolGuild.WorkType.FULL;
        workTypes[3] = ProtocolGuild.WorkType.FULL;
        workTypes[4] = ProtocolGuild.WorkType.PARTIAL;
        workTypes[5] = ProtocolGuild.WorkType.PARTIAL;

        bytes memory data = abi.encode(_recipients, workTypes);

        vm.startPrank(admin);
        scaffoldIE.addManager(0, manager, admin);
        vm.stopPrank();

        vm.startPrank(manager);
        scaffoldIE.updateRecipients(0, data, manager);
        vm.stopPrank();

        vm.warp(block.timestamp + 20 * 30 days);

        vm.startPrank(evaluator);
        scaffoldIE.evaluate(0, evaluationData, evaluator);
        vm.stopPrank();
    }
}
