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

// RetroFundingManual ABI (evaluate用)
const RETRO_FUNDING_ABI = [
  "function evaluate(bytes calldata data, address caller) external returns (bytes memory)",
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

  // 各プロジェクトのallocationを計算（1e6を基準に）
  const allocations = projects.map((project) => {
    const allocation = (project.percentage * 1e6) / totalPercentage;
    return Math.floor(allocation);
  });

  // 最後のプロジェクトで調整して合計が1e6になるようにする
  const currentTotal = allocations
    .slice(0, -1)
    .reduce((sum, alloc) => sum + alloc, 0);
  allocations[allocations.length - 1] = 1e6 - currentTotal;

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
    const recipients = projects.map((project) => project.recipientAddress);

    // updateRecipients用のデータをエンコード
    const updateData = ethers.utils.defaultAbiCoder.encode(
      ["address[]"],
      [recipients]
    );

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
    await updateTx.wait();
    console.log("Recipients updated");

    // allocationsを計算
    const allocations = calculateAllocations(projects);

    // evaluate()用のデータを作成
    // RetroFundingManualのevaluate()は以下の形式を期待:
    // (string, uint32[], address, uint256, address)
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

    // evaluate()を実行
    console.log("Executing evaluate...");
    const evaluateTx = await scaffold.evaluate(
      1,
      evaluationData,
      wallet.address
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
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
