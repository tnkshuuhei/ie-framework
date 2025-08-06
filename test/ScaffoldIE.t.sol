// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29 <0.9.0;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ScaffoldIE } from "../contracts/ScaffoldIE.sol";
import { IScaffoldIE } from "../contracts/interfaces/IScaffoldIE.sol";
import { ScaffoldIE as ScaffoldIEContract } from "../contracts/ScaffoldIE.sol";
import { ISplitMain } from "../contracts/interfaces/ISplitMain.sol";
import { IStrategy } from "../contracts/interfaces/IStrategy.sol";
import { BaseIEStrategy } from "../contracts/IEstrategies/BaseIEStrategy.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract MockStrategy is BaseIEStrategy {
    event MockCreateIECalled(bytes data);
    event MockEvaluateCalled(bytes data, address caller);
    event MockRegisterRecipientsCalled(address[] recipients, address caller);
    event MockUpdateRecipientsCalled(address[] recipients, address caller);

    function createIE(bytes memory _data) external override {
        emit MockCreateIECalled(_data);
    }

    function registerRecipients(address[] memory _recipients, address _caller) external override {
        _registerRecipients(_recipients);
        emit MockRegisterRecipientsCalled(_recipients, _caller);
    }

    function updateRecipients(address[] memory _recipients, address _caller) external override {
        _registerRecipients(_recipients);
        emit MockUpdateRecipientsCalled(_recipients, _caller);
    }

    function evaluate(bytes memory _data, address _caller) external override {
        emit MockEvaluateCalled(_data, _caller);
    }

    function getAddress() external view override returns (address) {
        return address(this);
    }

    function getRecipients() external view override returns (address[] memory) {
        return recipients;
    }

    function _registerRecipients(address[] memory _recipients) internal override {
        recipients = _recipients;
    }

    function setRecipients(address[] memory _recipients) external {
        _registerRecipients(_recipients);
    }

    function addEvaluator(address _evaluator, address _caller) external override { }

    function removeEvaluator(address _evaluator, address _caller) external override { }

    function addManager(address _manager, address _caller) external override { }

    function removeManager(address _manager, address _caller) external override { }
}

contract ScaffoldIETest is Test {
    IScaffoldIE public scaffoldIE;
    ISplitMain public mockSplits;
    MockStrategy public mockStrategy;

    address public currentPrankee;
    address public owner = makeAddr("owner");
    address public splitter = makeAddr("splitter");
    address public evaluator = makeAddr("evaluator");

    address public recipient1 = address(0x1);
    address public recipient2 = address(0x2);
    address public recipient3 = address(0x3);

    function setUp() public {
        // Create mock contracts
        mockSplits = ISplitMain(makeAddr("mockSplits"));
        mockStrategy = new MockStrategy();

        // Deploy ScaffoldIE
        scaffoldIE = new ScaffoldIE(owner, address(mockSplits));

        // Grant roles
        vm.startPrank(owner);
        scaffoldIE.grantRole(scaffoldIE.getSplitterRole(), splitter);
        console2.logBytes32(scaffoldIE.getSplitterRole());
        scaffoldIE.grantRole(scaffoldIE.getEvaluatorRole(), evaluator);
        console2.logBytes32(scaffoldIE.getEvaluatorRole());
        vm.stopPrank();
    }

    function testCreateIE() public {
        bytes memory data = abi.encode("test data");
        bytes memory initializeData = abi.encode(address(0), address(0), bytes32(0), address(0));
        // Mock IStrategy.initialize call
        vm.mockCall(
            address(mockStrategy),
            abi.encodeWithSelector(IStrategy.initialize.selector, 0, initializeData),
            abi.encode()
        );

        // Mock IStrategy.createIE call
        vm.mockCall(address(mockStrategy), abi.encodeWithSelector(IStrategy.createIE.selector, data), abi.encode());

        // Execute test
        vm.prank(owner);
        scaffoldIE.createIE(data, initializeData, address(mockStrategy));

        // Verify results
        assertEq(scaffoldIE.getPoolCount(), 1);
        assertEq(scaffoldIE.getStrategy(0), address(mockStrategy));
    }

    function testCreateIERoute() public {
        // Create IE beforehand
        bytes memory data = abi.encode("test data");
        bytes memory initializeData = abi.encode(address(0), address(0), bytes32(0), address(0));
        vm.prank(owner);
        scaffoldIE.createIE(data, initializeData, address(mockStrategy));

        // Create second IE
        MockStrategy mockStrategy2 = new MockStrategy();
        vm.prank(owner);
        scaffoldIE.createIE(data, initializeData, address(mockStrategy2));

        // Mock ISplitMain.createSplit call
        address[] memory IEs = new address[](2);
        IEs[0] = address(mockStrategy); // Actual contract address
        IEs[1] = address(mockStrategy2); // Actual contract address
        uint32[] memory allocations = new uint32[](2);
        allocations[0] = 5e5;
        allocations[1] = 5e5;

        assertEq(allocations[0] + allocations[1], 1e6);
        assertEq(scaffoldIE.getPoolCount(), 2);

        vm.mockCall(
            address(mockSplits),
            abi.encodeWithSelector(ISplitMain.createSplit.selector, IEs, allocations, 0, address(scaffoldIE)),
            abi.encode(address(0x789)) // Created split address
        );

        // Execute test
        vm.prank(splitter);
        scaffoldIE.createIERoute(allocations);

        // Verify results
        assertEq(scaffoldIE.getRootSplit(), address(0x789));
    }

    function testUpdateRoute() public {
        // Create route beforehand
        testCreateIERoute();

        // Mock IStrategy.getAddress call
        vm.mockCall(
            address(mockStrategy), abi.encodeWithSelector(IStrategy.getAddress.selector), abi.encode(address(0x123))
        );

        // Mock ISplitMain.updateSplit call
        address[] memory IEs = new address[](1);
        IEs[0] = address(0x123);
        uint32[] memory newAllocations = new uint32[](1);
        newAllocations[0] = 200;

        vm.mockCall(
            address(mockSplits),
            abi.encodeWithSelector(ISplitMain.updateSplit.selector, scaffoldIE.getRootSplit(), IEs, newAllocations, 0),
            abi.encode()
        );

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

        // Mock IStrategy.registerRecipients call
        vm.mockCall(
            address(mockStrategy),
            abi.encodeWithSelector(IStrategy.registerRecipients.selector, recipients, owner),
            abi.encode()
        );

        // Execute test
        vm.prank(owner);
        scaffoldIE.registerRecipients(0, recipients, owner);
    }

    function testUpdateRecipients() public {
        // Create IE beforehand
        testCreateIE();

        address[] memory newRecipients = new address[](3);
        newRecipients[0] = recipient1;
        newRecipients[1] = recipient2;
        newRecipients[2] = recipient3;

        // Mock IStrategy.updateRecipients call
        vm.mockCall(
            address(mockStrategy),
            abi.encodeWithSelector(IStrategy.updateRecipients.selector, newRecipients, owner),
            abi.encode()
        );

        // Execute test
        vm.prank(owner);
        scaffoldIE.updateRecipients(0, newRecipients, owner);
    }

    function testEvaluate() public {
        // Create IE beforehand
        testCreateIE();

        bytes memory evaluationData = abi.encode("evaluation data");

        // Mock IStrategy.evaluate call
        vm.mockCall(
            address(mockStrategy),
            abi.encodeWithSelector(IStrategy.evaluate.selector, evaluationData, evaluator),
            abi.encode()
        );

        // Execute test
        vm.prank(evaluator);
        scaffoldIE.evaluate(0, evaluationData, evaluator);
    }

    function testMultipleIEs() public {
        MockStrategy mockStrategy2 = new MockStrategy();

        // Create multiple IEs
        bytes memory data1 = abi.encode("data1");
        bytes memory data2 = abi.encode("data2");
        bytes memory initializeData = abi.encode(address(0), address(0), bytes32(0), address(0));

        // First IE
        vm.mockCall(
            address(mockStrategy),
            abi.encodeWithSelector(IStrategy.initialize.selector, 0, initializeData, address(scaffoldIE)),
            abi.encode()
        );
        vm.mockCall(address(mockStrategy), abi.encodeWithSelector(IStrategy.createIE.selector, data1), abi.encode());

        // Second IE
        vm.mockCall(
            address(mockStrategy2),
            abi.encodeWithSelector(IStrategy.initialize.selector, 1, initializeData, address(scaffoldIE)),
            abi.encode()
        );
        vm.mockCall(address(mockStrategy2), abi.encodeWithSelector(IStrategy.createIE.selector, data2), abi.encode());

        vm.prank(owner);
        scaffoldIE.createIE(data1, initializeData, address(mockStrategy));

        vm.prank(owner);
        scaffoldIE.createIE(data2, initializeData, address(mockStrategy2));

        // Verify results
        assertEq(scaffoldIE.getPoolCount(), 2);
        assertEq(scaffoldIE.getStrategy(0), address(mockStrategy));
        assertEq(scaffoldIE.getStrategy(1), address(mockStrategy2));
    }

    // Test using actual MockStrategy
    function testMockStrategyDirect() public {
        bytes memory data = abi.encode("test data");
        bytes memory initializeData = abi.encode(address(0), address(0), bytes32(0), address(0));

        // Use actual MockStrategy for testing
        vm.prank(owner);
        scaffoldIE.createIE(data, initializeData, address(mockStrategy));

        // Verify results
        assertEq(scaffoldIE.getPoolCount(), 1);
        assertEq(scaffoldIE.getStrategy(0), address(mockStrategy));

        // Check MockStrategy state
        assertEq(mockStrategy.getPoolId(), 0);
    }

    function testMockStrategyRecipients() public {
        // Create IE beforehand
        testMockStrategyDirect();

        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        // Use actual MockStrategy for testing
        vm.prank(owner);
        scaffoldIE.registerRecipients(0, recipients, owner);

        // Check MockStrategy state
        address[] memory storedRecipients = mockStrategy.getRecipients();
        assertEq(storedRecipients.length, 2);
        assertEq(storedRecipients[0], recipient1);
        assertEq(storedRecipients[1], recipient2);
    }

    function testMockStrategyEvaluate() public {
        // Create IE beforehand
        testMockStrategyDirect();

        bytes memory evaluationData = abi.encode("evaluation data");

        // Use actual MockStrategy for testing
        vm.prank(evaluator);
        scaffoldIE.evaluate(0, evaluationData, evaluator);

        // Verify that events are emitted (using actual MockStrategy)
        // In this test, actual contracts are called, so events are emitted
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
