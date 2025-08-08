// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { BaseScript } from "./Base.s.sol";
import { ScaffoldIE } from "../contracts/ScaffoldIE.sol";
import { IScaffoldIE } from "../contracts/interfaces/IScaffoldIE.sol";
import { ProtocolGuild } from "../contracts/IEstrategies/ProtocolGuild.sol";

contract MockScript is BaseScript {
    ScaffoldIE public scaffold = ScaffoldIE(0x31f0d35410f95aFAF29864c6dbd23Adfc8D28dfC);

    // CSVからパースしたデータを格納する構造体
    struct ProjectData {
        string name;
        string category;
        uint256 percentage;
        uint256 opReceived;
        address recipientAddress;
    }

    ProjectData[] public projects;

    function run() public broadcast {
        _addRecipientsPoolId1();
    }

    function _addRecipientsPoolId1() internal {
        string memory csvContent = vm.readFile("rpgf2_results.csv");
        _parseCSV(csvContent);

        // CSVからパースしたデータを使ってupdateRecipientsを呼び出し
        _updateRecipientsFromCSV();
    }

    function _parseCSV(string memory csvContent) internal {
        // 行ごとに分割
        string[] memory lines = _split(csvContent, "\n");

        // ヘッダー行をスキップして、データ行を処理
        for (uint256 i = 1; i < lines.length; i++) {
            if (bytes(lines[i]).length == 0) continue;

            string[] memory fields = _split(lines[i], ",");
            if (fields.length >= 4) {
                ProjectData memory project;
                project.name = fields[0];
                project.category = fields[1];
                project.percentage = _parsePercentage(fields[2]);
                project.opReceived = _parseOPAmount(fields[3]);
                project.recipientAddress = _generateAddressFromName(project.name);

                projects.push(project);
            }
        }
    }

    function _split(string memory str, string memory delimiter) internal pure returns (string[] memory) {
        // 簡易的な文字列分割関数
        // 実際の実装では、より複雑なCSVパーサーが必要
        bytes memory strBytes = bytes(str);
        bytes memory delimiterBytes = bytes(delimiter);

        // カウント
        uint256 count = 1;
        for (uint256 i = 0; i < strBytes.length - delimiterBytes.length + 1; i++) {
            bool found = true;
            for (uint256 j = 0; j < delimiterBytes.length; j++) {
                if (strBytes[i + j] != delimiterBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) count++;
        }

        string[] memory result = new string[](count);
        uint256 index = 0;
        uint256 start = 0;

        for (uint256 i = 0; i < strBytes.length - delimiterBytes.length + 1; i++) {
            bool found = true;
            for (uint256 j = 0; j < delimiterBytes.length; j++) {
                if (strBytes[i + j] != delimiterBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                result[index] = _substring(str, start, i);
                index++;
                start = i + delimiterBytes.length;
            }
        }

        result[index] = _substring(str, start, strBytes.length);
        return result;
    }

    function _substring(
        string memory str,
        uint256 startIndex,
        uint256 endIndex
    )
        internal
        pure
        returns (string memory)
    {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    function _parsePercentage(string memory percentageStr) internal pure returns (uint256) {
        // パーセンテージ文字列（例: "5.5730"）をuint256に変換
        // 小数点以下4桁を保持するため、10000倍して返す
        bytes memory bytesStr = bytes(percentageStr);
        uint256 result = 0;
        uint256 decimalPlaces = 0;
        bool foundDecimal = false;

        for (uint256 i = 0; i < bytesStr.length; i++) {
            if (bytesStr[i] == ".") {
                foundDecimal = true;
                continue;
            }

            if (bytesStr[i] >= 0x30 && bytesStr[i] <= 0x39) {
                result = result * 10 + (uint8(bytesStr[i]) - 0x30);
                if (foundDecimal) {
                    decimalPlaces++;
                }
            }
        }

        // 4桁の小数点以下に正規化
        while (decimalPlaces < 4) {
            result *= 10;
            decimalPlaces++;
        }

        return result;
    }

    function _parseOPAmount(string memory amountStr) internal pure returns (uint256) {
        // OP金額文字列（例: "557,301.00"）をuint256に変換
        bytes memory bytesStr = bytes(amountStr);
        uint256 result = 0;
        uint256 decimalPlaces = 0;
        bool foundDecimal = false;

        for (uint256 i = 0; i < bytesStr.length; i++) {
            if (bytesStr[i] == ",") continue; // カンマをスキップ
            if (bytesStr[i] == ".") {
                foundDecimal = true;
                continue;
            }

            if (bytesStr[i] >= 0x30 && bytesStr[i] <= 0x39) {
                result = result * 10 + (uint8(bytesStr[i]) - 0x30);
                if (foundDecimal) {
                    decimalPlaces++;
                }
            }
        }

        // 2桁の小数点以下に正規化
        while (decimalPlaces < 2) {
            result *= 10;
            decimalPlaces++;
        }

        return result;
    }

    function _generateAddressFromName(string memory name) internal pure returns (address) {
        // プロジェクト名からアドレスを生成（簡易的な実装）
        // 実際の実装では、より適切なアドレス生成ロジックが必要
        bytes memory nameBytes = bytes(name);
        uint256 hash = 0;

        for (uint256 i = 0; i < nameBytes.length; i++) {
            hash = uint256(keccak256(abi.encodePacked(hash, nameBytes[i])));
        }

        return address(uint160(hash % (2 ** 160)));
    }

    function getProjectsCount() public view returns (uint256) {
        return projects.length;
    }

    function getProject(uint256 index)
        public
        view
        returns (
            string memory name,
            string memory category,
            uint256 percentage,
            uint256 opReceived,
            address recipientAddress
        )
    {
        require(index < projects.length, "Index out of bounds");
        ProjectData memory project = projects[index];
        return (project.name, project.category, project.percentage, project.opReceived, project.recipientAddress);
    }

    function _updateRecipientsFromCSV() internal {
        require(projects.length > 0, "No projects loaded from CSV");

        address[] memory updatedRecipients = new address[](projects.length);

        for (uint256 i = 0; i < projects.length; i++) {
            ProjectData memory project = projects[i];
            updatedRecipients[i] = project.recipientAddress;
        }

        bytes memory data = abi.encode(updatedRecipients);

        // ManagerとEvaluatorを追加
        scaffold.addManager(1, broadcaster, broadcaster);
        scaffold.addEvaluator(1, broadcaster, broadcaster);

        // updateRecipientsを呼び出し
        IScaffoldIE(address(scaffold)).updateRecipients(1, data, broadcaster);

        // evaluate()を実行
        _evaluateWithAllocations();
    }

    function _evaluateWithAllocations() internal {
        require(projects.length > 0, "No projects loaded from CSV");

        // uint32[] allocationsを計算（合計が1e6になるように）
        uint32[] memory allocations = new uint32[](projects.length);
        uint256 totalPercentage = 0;

        // まず、各プロジェクトのパーセンテージを合計
        for (uint256 i = 0; i < projects.length; i++) {
            totalPercentage += projects[i].percentage;
        }

        // 各プロジェクトのallocationを計算（1e6を基準に）
        for (uint256 i = 0; i < projects.length; i++) {
            // パーセンテージを1e6に正規化
            uint256 allocation = (projects[i].percentage * 1e6) / totalPercentage;
            allocations[i] = uint32(allocation);
        }

        // 最後のプロジェクトで調整して合計が1e6になるようにする
        uint256 currentTotal = 0;
        for (uint256 i = 0; i < projects.length - 1; i++) {
            currentTotal += allocations[i];
        }
        allocations[projects.length - 1] = uint32(1e6 - currentTotal);

        // evaluate()用のデータを作成
        // RetroFundingManualのevaluate()は以下の形式を期待:
        // (string, uint32[], address, uint256, address)
        bytes memory evaluationData = abi.encode(
            "RPGF2 Round 2 Evaluation", // 評価データの説明
            allocations, // uint32[] allocations
            address(0), // contract address (placeholder)
            uint256(11_155_111), // chainId (Sepolia)
            broadcaster // attester
        );

        // evaluate()を実行
        IScaffoldIE(address(scaffold)).evaluate(1, evaluationData, broadcaster);
    }

    function _addRecipientsAndEvaluate() internal {
        address[] memory updatedRecipients = new address[](10);
        updatedRecipients[0] = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
        updatedRecipients[1] = 0xc3593524E2744E547f013E17E6b0776Bc27Fc614;
        updatedRecipients[2] = address(2);
        updatedRecipients[3] = address(3);
        updatedRecipients[4] = address(4);
        updatedRecipients[5] = address(5);
        updatedRecipients[6] = address(6);
        updatedRecipients[7] = address(7);
        updatedRecipients[8] = address(8);
        updatedRecipients[9] = address(9);

        ProtocolGuild.WorkType[] memory workTypes = new ProtocolGuild.WorkType[](10);
        workTypes[0] = ProtocolGuild.WorkType.PARTIAL;
        workTypes[1] = ProtocolGuild.WorkType.FULL;
        workTypes[2] = ProtocolGuild.WorkType.PARTIAL;
        workTypes[3] = ProtocolGuild.WorkType.FULL;
        workTypes[4] = ProtocolGuild.WorkType.PARTIAL;
        workTypes[5] = ProtocolGuild.WorkType.FULL;
        workTypes[6] = ProtocolGuild.WorkType.PARTIAL;
        workTypes[7] = ProtocolGuild.WorkType.FULL;
        workTypes[8] = ProtocolGuild.WorkType.PARTIAL;
        workTypes[9] = ProtocolGuild.WorkType.FULL;

        bytes memory data = abi.encode(updatedRecipients, workTypes);
        // scaffold.addManager(3, broadcaster, broadcaster);
        // scaffold.addEvaluator(3, broadcaster, broadcaster);

        bytes memory evaluationData = abi.encode(
            "data",
            IScaffoldIE(address(scaffold)).getStrategy(2),
            11_155_111,
            address(0x67Df9d563032dAA77273a689041bC9cFC1B35911)
        );

        // IScaffoldIE(address(scaffold)).updateRecipients(3, data, broadcaster);
        IScaffoldIE(address(scaffold)).evaluate(3, evaluationData, broadcaster);
    }
}
