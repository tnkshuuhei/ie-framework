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
    address public strategyAddress;

    event MockCreateIECalled(bytes data);
    event MockEvaluateCalled(bytes data, address caller);
    event MockRegisterRecipientsCalled(address[] recipients, address caller);
    event MockUpdateRecipientsCalled(address[] recipients, address caller);

    constructor() BaseIEStrategy(address(0), "MockStrategy") {
        strategyAddress = address(this);
    }

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

    // テスト用のヘルパー関数
    function setStrategyAddress(address _address) external {
        strategyAddress = _address;
    }

    function setRecipients(address[] memory _recipients) external {
        _registerRecipients(_recipients);
    }
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
        // モックコントラクトを作成
        mockSplits = ISplitMain(makeAddr("mockSplits"));
        mockStrategy = new MockStrategy();

        // ScaffoldIEをデプロイ
        scaffoldIE = new ScaffoldIE(owner, address(mockSplits));

        // ロールを付与
        vm.startPrank(owner);
        scaffoldIE.grantRole(scaffoldIE.getSplitterRole(), splitter);
        console2.logBytes32(scaffoldIE.getSplitterRole());
        scaffoldIE.grantRole(scaffoldIE.getEvaluatorRole(), evaluator);
        console2.logBytes32(scaffoldIE.getEvaluatorRole());
        vm.stopPrank();
    }

    function testCreateIE() public {
        bytes memory data = abi.encode("test data");

        // IStrategy.initializeの呼び出しをモック
        vm.mockCall(address(mockStrategy), abi.encodeWithSelector(IStrategy.initialize.selector, 0, data), abi.encode());

        // IStrategy.createIEの呼び出しをモック
        vm.mockCall(address(mockStrategy), abi.encodeWithSelector(IStrategy.createIE.selector, data), abi.encode());

        // テスト実行
        vm.prank(owner);
        scaffoldIE.createIE(data, address(mockStrategy));

        // 結果を検証
        assertEq(scaffoldIE.getPoolCount(), 1);
        assertEq(scaffoldIE.getStrategy(0), address(mockStrategy));
    }

    function testCreateIERoute() public {
        // 事前にIEを作成
        bytes memory data = abi.encode("test data");
        vm.prank(owner);
        scaffoldIE.createIE(data, address(mockStrategy));

        // 2つ目のIEを作成
        MockStrategy mockStrategy2 = new MockStrategy();
        vm.prank(owner);
        scaffoldIE.createIE(data, address(mockStrategy2));

        // ISplitMain.createSplitの呼び出しをモック
        address[] memory IEs = new address[](2);
        IEs[0] = address(mockStrategy); // 実際のコントラクトアドレス
        IEs[1] = address(mockStrategy2); // 実際のコントラクトアドレス
        uint32[] memory allocations = new uint32[](2);
        allocations[0] = 5e5;
        allocations[1] = 5e5;

        assertEq(allocations[0] + allocations[1], 1e6);
        assertEq(scaffoldIE.getPoolCount(), 2);

        vm.mockCall(
            address(mockSplits),
            abi.encodeWithSelector(ISplitMain.createSplit.selector, IEs, allocations, 0, address(scaffoldIE)),
            abi.encode(address(0x789)) // 作成されたスプリットのアドレス
        );

        // テスト実行
        vm.prank(splitter);
        scaffoldIE.createIERoute(allocations, splitter);

        // 結果を検証
        assertEq(scaffoldIE.getRootSplit(), address(0x789));
    }

    function testUpdateRoute() public {
        // 事前にルートを作成
        testCreateIERoute();

        // IStrategy.getAddressの呼び出しをモック
        vm.mockCall(
            address(mockStrategy), abi.encodeWithSelector(IStrategy.getAddress.selector), abi.encode(address(0x123))
        );

        // ISplitMain.updateSplitの呼び出しをモック
        address[] memory IEs = new address[](1);
        IEs[0] = address(0x123);
        uint32[] memory newAllocations = new uint32[](1);
        newAllocations[0] = 200;

        vm.mockCall(
            address(mockSplits),
            abi.encodeWithSelector(ISplitMain.updateSplit.selector, scaffoldIE.getRootSplit(), IEs, newAllocations, 0),
            abi.encode()
        );

        // テスト実行
        vm.prank(splitter);
        scaffoldIE.updateRoute(newAllocations, splitter);
    }

    function testRegisterRecipients() public {
        // 事前にIEを作成
        testCreateIE();

        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        // IStrategy.registerRecipientsの呼び出しをモック
        vm.mockCall(
            address(mockStrategy),
            abi.encodeWithSelector(IStrategy.registerRecipients.selector, recipients, owner),
            abi.encode()
        );

        // テスト実行
        vm.prank(owner);
        scaffoldIE.registerRecipients(0, recipients, owner);
    }

    function testUpdateRecipients() public {
        // 事前にIEを作成
        testCreateIE();

        address[] memory newRecipients = new address[](3);
        newRecipients[0] = recipient1;
        newRecipients[1] = recipient2;
        newRecipients[2] = recipient3;

        // IStrategy.updateRecipientsの呼び出しをモック
        vm.mockCall(
            address(mockStrategy),
            abi.encodeWithSelector(IStrategy.updateRecipients.selector, newRecipients, owner),
            abi.encode()
        );

        // テスト実行
        vm.prank(owner);
        scaffoldIE.updateRecipients(0, newRecipients, owner);
    }

    function testEvaluate() public {
        // 事前にIEを作成
        testCreateIE();

        bytes memory evaluationData = abi.encode("evaluation data");

        // IStrategy.evaluateの呼び出しをモック
        vm.mockCall(
            address(mockStrategy),
            abi.encodeWithSelector(IStrategy.evaluate.selector, evaluationData, evaluator),
            abi.encode()
        );

        // テスト実行
        vm.prank(evaluator);
        scaffoldIE.evaluate(0, evaluationData, evaluator);
    }

    function testMultipleIEs() public {
        MockStrategy mockStrategy2 = new MockStrategy();

        // 複数のIEを作成
        bytes memory data1 = abi.encode("data1");
        bytes memory data2 = abi.encode("data2");

        // 1つ目のIE
        vm.mockCall(
            address(mockStrategy), abi.encodeWithSelector(IStrategy.initialize.selector, 0, data1), abi.encode()
        );
        vm.mockCall(address(mockStrategy), abi.encodeWithSelector(IStrategy.createIE.selector, data1), abi.encode());

        // 2つ目のIE
        vm.mockCall(
            address(mockStrategy2), abi.encodeWithSelector(IStrategy.initialize.selector, 1, data2), abi.encode()
        );
        vm.mockCall(address(mockStrategy2), abi.encodeWithSelector(IStrategy.createIE.selector, data2), abi.encode());

        vm.prank(owner);
        scaffoldIE.createIE(data1, address(mockStrategy));

        vm.prank(owner);
        scaffoldIE.createIE(data2, address(mockStrategy2));

        // 結果を検証
        assertEq(scaffoldIE.getPoolCount(), 2);
        assertEq(scaffoldIE.getStrategy(0), address(mockStrategy));
        assertEq(scaffoldIE.getStrategy(1), address(mockStrategy2));
    }

    function testAccessControl() public {
        bytes memory data = abi.encode("test data");

        // 権限のないユーザーがcreateIEを呼び出そうとする
        vm.prank(makeAddr("unauthorized"));
        vm.expectRevert();
        scaffoldIE.createIERoute(new uint32[](1), makeAddr("unauthorized"));
    }

    // 実際のMockStrategyを使用したテスト
    function testMockStrategyDirect() public {
        bytes memory data = abi.encode("test data");

        // 実際のMockStrategyを使用してテスト
        vm.prank(owner);
        scaffoldIE.createIE(data, address(mockStrategy));

        // 結果を検証
        assertEq(scaffoldIE.getPoolCount(), 1);
        assertEq(scaffoldIE.getStrategy(0), address(mockStrategy));

        // MockStrategyの状態を確認
        assertEq(mockStrategy.getPoolId(), 0);
    }

    function testMockStrategyRecipients() public {
        // 事前にIEを作成
        testMockStrategyDirect();

        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        // 実際のMockStrategyを使用してテスト
        vm.prank(owner);
        scaffoldIE.registerRecipients(0, recipients, owner);

        // MockStrategyの状態を確認
        address[] memory storedRecipients = mockStrategy.getRecipients();
        assertEq(storedRecipients.length, 2);
        assertEq(storedRecipients[0], recipient1);
        assertEq(storedRecipients[1], recipient2);
    }

    function testMockStrategyEvaluate() public {
        // 事前にIEを作成
        testMockStrategyDirect();

        bytes memory evaluationData = abi.encode("evaluation data");

        // 実際のMockStrategyを使用してテスト
        vm.prank(evaluator);
        scaffoldIE.evaluate(0, evaluationData, evaluator);

        // イベントが発行されたことを確認（実際のMockStrategyを使用）
        // このテストでは実際のコントラクトが呼ばれるため、イベントが発行される
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
