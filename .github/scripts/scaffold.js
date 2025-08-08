const fs = require("fs");
const { ethers } = require("ethers");
const csv = require("csv-parser");

// ScaffoldIE ABI (必要な関数のみ)
const SCAFFOLD_ABI = [
  "function updateRecipients(uint256 poolId, bytes calldata data, address caller) external",
  "function evaluate(uint256 poolId, bytes calldata data, address caller) external",
  "function addManager(uint256 poolId, address manager, address caller) external",
  "function addEvaluator(uint256 poolId, address evaluator, address caller) external",
];

async function parseCSV() {
  return new Promise((resolve, reject) => {
    const projects = [];

    fs.createReadStream("rpgf2_results.csv")
      .pipe(csv())
      .on("data", (row) => {
        // パーセンテージを数値に変換（例: "5.5730" -> 55730）
        const percentage = parseFloat(row["% of votes received"]) * 10000;

        projects.push({
          name: row["Project Name"],
          category: row["Category"],
          percentage: percentage,
          opReceived: parseFloat(row["OP Received"].replace(/,/g, "")),
          recipientAddress: generateAddressFromName(row["Project Name"]),
        });
      })
      .on("end", () => {
        console.log(`Parsed ${projects.length} projects from CSV`);
        resolve(projects);
      })
      .on("error", reject);
  });
}

function generateAddressFromName(name) {
  // プロジェクト名からアドレスを生成（簡易的な実装）
  const hash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name));
  return ethers.utils.getAddress(hash.slice(0, 42));
}

function calculateAllocations(projects) {
  const totalPercentage = projects.reduce(
    (sum, project) => sum + project.percentage,
    0
  );

  console.log(`Total percentage: ${totalPercentage}`);
  console.log(`Number of projects: ${projects.length}`);

  // 各プロジェクトのallocationを計算（1e6を基準に）
  const allocations = projects.map((project) => {
    const allocation = (project.percentage * 1e6) / totalPercentage;
    return Math.floor(allocation);
  });

  // 合計を計算
  const currentTotal = allocations.reduce((sum, alloc) => sum + alloc, 0);
  console.log(`Current total allocation: ${currentTotal}`);

  // 残りを最後のプロジェクトに追加
  const remaining = 1e6 - currentTotal;
  if (remaining > 0 && allocations.length > 0) {
    allocations[allocations.length - 1] += remaining;
  }

  // 最終確認
  const finalTotal = allocations.reduce((sum, alloc) => sum + alloc, 0);
  console.log(`Final total allocation: ${finalTotal}`);
  console.log(
    `Allocations range: ${Math.min(...allocations)} - ${Math.max(
      ...allocations
    )}`
  );

  // 負の値や異常な値がないかチェック
  const invalidAllocations = allocations.filter(
    (alloc) => alloc < 0 || alloc > 1e6
  );
  if (invalidAllocations.length > 0) {
    throw new Error(`Invalid allocations found: ${invalidAllocations}`);
  }

  return allocations;
}

async function main() {
  try {
    // 環境変数の取得
    const privateKey = process.env.PRIVATE_KEY;
    const rpcUrl = "https://sepolia.drpc.org";
    const scaffoldAddress = "0x31f0d35410f95aFAF29864c6dbd23Adfc8D28dfC";

    if (!privateKey) {
      throw new Error("PRIVATE_KEY environment variable is required");
    }

    console.log("Starting RPGF2 evaluation...");

    // プロバイダーとウォレットの設定
    const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);

    console.log("Wallet address:", wallet.address);

    // ScaffoldIEコントラクトのインスタンス作成
    const scaffold = new ethers.Contract(scaffoldAddress, SCAFFOLD_ABI, wallet);

    // CSVをパース
    const projects = await parseCSV();

    if (projects.length === 0) {
      throw new Error("No projects found in CSV");
    }

    console.log(`Processing ${projects.length} projects...`);

    // 受信者アドレスの配列を作成
    // const recipients = projects.map((project) => project.recipientAddress);

    // // updateRecipients用のデータをエンコード
    // const updateData = ethers.utils.defaultAbiCoder.encode(
    //   ["address[]"],
    //   [recipients]
    // );

    // // ManagerとEvaluatorを追加
    // console.log("Adding manager and evaluator...");
    // const addManagerTx = await scaffold.addManager(
    //   1,
    //   wallet.address,
    //   wallet.address
    // );
    // await addManagerTx.wait();
    // console.log("Manager added");

    // const addEvaluatorTx = await scaffold.addEvaluator(
    //   1,
    //   wallet.address,
    //   wallet.address
    // );
    // await addEvaluatorTx.wait();
    // console.log("Evaluator added");

    // // updateRecipientsを実行
    // console.log("Updating recipients...");
    // const updateTx = await scaffold.updateRecipients(
    //   1,
    //   updateData,
    //   wallet.address
    // );
    // await updateTx.wait();
    // console.log("Recipients updated");

    console.log("Skipping updateRecipients - only running evaluate...");

    // allocationsを計算
    const allocations = calculateAllocations(projects);

    // evaluate()用のデータを作成
    // RetroFundingManualのevaluate()は以下の形式を期待:
    // (string, uint32[], address, uint256, address)
    console.log("Encoding evaluation data...");
    console.log("Allocations length:", allocations.length);
    console.log("Sample allocations:", allocations.slice(0, 5));

    const evaluationData = ethers.utils.defaultAbiCoder.encode(
      ["string", "uint32[]", "address", "uint256", "address"],
      [
        "RPGF2 Round 2 Evaluation", // 評価データの説明
        allocations, // uint32[] allocations
        ethers.constants.AddressZero, // contract address (placeholder)
        11155111, // chainId (Sepolia)
        wallet.address, // attester
      ]
    );

    console.log("Evaluation data encoded successfully");
    console.log("Data length:", evaluationData.length);

    // evaluate()を実行
    console.log("Executing evaluate...");
    const evaluateTx = await scaffold.evaluate(
      1,
      evaluationData,
      wallet.address,
      {
        gasLimit: 100000000,
      }
    );
    const receipt = await evaluateTx.wait();

    console.log("Evaluation completed successfully!");
    console.log("Transaction hash:", evaluateTx.hash);
    console.log("Gas used:", receipt.gasUsed.toString());

    // 結果のサマリー
    console.log("\n=== Evaluation Summary ===");
    console.log(`Total projects: ${projects.length}`);
    console.log(
      `Total allocation: ${allocations.reduce((sum, alloc) => sum + alloc, 0)}`
    );
    console.log(`Top 5 projects:`);
    projects.slice(0, 5).forEach((project, index) => {
      console.log(
        `  ${index + 1}. ${project.name}: ${allocations[index]} allocation`
      );
    });
  } catch (error) {
    console.error("Error:", error);
    console.error("Error details:", {
      message: error.message,
      code: error.code,
      reason: error.reason,
    });

    // トランザクション失敗の場合は詳細を表示
    if (error.transactionHash) {
      console.error("Transaction hash:", error.transactionHash);
      console.error("Transaction data:", error.transaction);
    }

    // ガス推定エラーの場合は再試行を提案
    if (error.message.includes("UNPREDICTABLE_GAS_LIMIT")) {
      console.error(
        "\nSuggestion: Try increasing gas limit or using a different RPC provider"
      );
    }

    // CALL_EXCEPTIONの場合はコントラクトエラーを提案
    if (error.message.includes("CALL_EXCEPTION")) {
      console.error(
        "\nSuggestion: Check contract state, permissions, and data format"
      );
    }

    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
