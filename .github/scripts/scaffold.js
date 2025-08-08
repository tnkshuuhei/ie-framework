const fs = require("fs");
const { ethers } = require("ethers");
const csv = require("csv-parser");

// Configuration constants
const CONFIG = {
  RPC_URL: "https://sepolia.drpc.org",
  SCAFFOLD_ADDRESS: "0x31f0d35410f95aFAF29864c6dbd23Adfc8D28dfC",
  POOL_ID: 1,
  CHAIN_ID: 11155111,
  GAS_LIMIT: 30000000,
  CSV_FILE: "rpgf2_results.csv",
  BASIS_POINTS: 1e6,
};

// ScaffoldIE ABI (required functions only)
const SCAFFOLD_ABI = [
  "function updateRecipients(uint256 poolId, bytes calldata data, address caller) external",
  "function evaluate(uint256 poolId, bytes calldata data, address caller) external",
  "function addManager(uint256 poolId, address manager, address caller) external",
  "function addEvaluator(uint256 poolId, address evaluator, address caller) external",
];

/**
 * Parses CSV file containing project data
 * @returns {Promise<Array>} Array of project objects
 */
async function parseCSV() {
  return new Promise((resolve, reject) => {
    if (!fs.existsSync(CONFIG.CSV_FILE)) {
      reject(new Error(`CSV file '${CONFIG.CSV_FILE}' not found`));
      return;
    }

    const projects = [];

    fs.createReadStream(CONFIG.CSV_FILE)
      .pipe(csv())
      .on("data", (row) => {
        try {
          const votesReceived = row["% of votes received"];
          const opReceived = row["OP Received"];
          
          if (!votesReceived || !row["Project Name"]) {
            console.warn(`Skipping invalid row: ${JSON.stringify(row)}`);
            return;
          }

          // Convert percentage to numeric value (e.g., "5.5730" -> 55730)
          const percentage = parseFloat(votesReceived) * 10000;
          
          if (isNaN(percentage) || percentage <= 0) {
            console.warn(`Invalid percentage for ${row["Project Name"]}: ${votesReceived}`);
            return;
          }

          projects.push({
            name: row["Project Name"],
            category: row["Category"] || "Uncategorized",
            percentage: percentage,
            opReceived: opReceived ? parseFloat(opReceived.replace(/,/g, "")) : 0,
            recipientAddress: generateAddressFromName(row["Project Name"]),
          });
        } catch (error) {
          console.warn(`Error parsing row: ${error.message}`);
        }
      })
      .on("end", () => {
        console.log(`Parsed ${projects.length} projects from CSV`);
        resolve(projects);
      })
      .on("error", reject);
  });
}

/**
 * Generates a deterministic address from project name
 * @param {string} name - Project name
 * @returns {string} Ethereum address
 */
function generateAddressFromName(name) {
  if (!name || typeof name !== 'string') {
    throw new Error('Project name must be a non-empty string');
  }
  
  const hash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name));
  return ethers.utils.getAddress(hash.slice(0, 42));
}

/**
 * Calculates allocation percentages in basis points (1e6 = 100%)
 * @param {Array} projects - Array of project objects
 * @returns {Array<number>} Array of allocation values in basis points
 */
function calculateAllocations(projects) {
  if (!projects || projects.length === 0) {
    throw new Error('No projects provided for allocation calculation');
  }

  const totalPercentage = projects.reduce(
    (sum, project) => sum + project.percentage,
    0
  );

  if (totalPercentage <= 0) {
    throw new Error('Total percentage must be greater than 0');
  }

  console.log(`Total percentage: ${totalPercentage}`);
  console.log(`Number of projects: ${projects.length}`);

  // Calculate allocation for each project (based on 1e6 basis points)
  const allocations = projects.map((project) => {
    const allocation = (project.percentage * CONFIG.BASIS_POINTS) / totalPercentage;
    return Math.floor(allocation);
  });

  // Calculate total and handle rounding differences
  const currentTotal = allocations.reduce((sum, alloc) => sum + alloc, 0);
  console.log(`Current total allocation: ${currentTotal}`);

  // Distribute remaining basis points to maintain exactly 1e6 total
  const remaining = CONFIG.BASIS_POINTS - currentTotal;
  if (remaining > 0 && allocations.length > 0) {
    // Add remaining to the project with the largest original allocation
    const maxIndex = allocations.indexOf(Math.max(...allocations));
    allocations[maxIndex] += remaining;
  }

  // Final verification
  const finalTotal = allocations.reduce((sum, alloc) => sum + alloc, 0);
  console.log(`Final total allocation: ${finalTotal}`);
  console.log(
    `Allocations range: ${Math.min(...allocations)} - ${Math.max(
      ...allocations
    )}`
  );

  // Validate allocations
  const invalidAllocations = allocations.filter(
    (alloc) => alloc < 0 || alloc > CONFIG.BASIS_POINTS
  );
  if (invalidAllocations.length > 0) {
    throw new Error(`Invalid allocations found: ${invalidAllocations}`);
  }

  if (finalTotal !== CONFIG.BASIS_POINTS) {
    throw new Error(`Total allocation must equal ${CONFIG.BASIS_POINTS}, got ${finalTotal}`);
  }

  return allocations;
}

/**
 * Validates environment and returns configuration
 * @returns {Object} Configuration object with wallet and contract
 */
function validateAndSetup() {
  const privateKey = process.env.PRIVATE_KEY;
  
  if (!privateKey) {
    throw new Error("PRIVATE_KEY environment variable is required");
  }

  const provider = new ethers.providers.JsonRpcProvider(CONFIG.RPC_URL);
  const wallet = new ethers.Wallet(privateKey, provider);
  const scaffold = new ethers.Contract(CONFIG.SCAFFOLD_ADDRESS, SCAFFOLD_ABI, wallet);

  return { wallet, scaffold };
}

/**
 * Encodes evaluation data for the contract call
 * @param {Array} allocations - Array of allocation values
 * @param {string} walletAddress - Evaluator wallet address
 * @returns {string} Encoded data
 */
function encodeEvaluationData(allocations, walletAddress) {
  return ethers.utils.defaultAbiCoder.encode(
    ["string", "uint32[]", "address", "uint256", "address"],
    [
      "RPGF2 Round 2 Evaluation",
      allocations,
      ethers.constants.AddressZero,
      CONFIG.CHAIN_ID,
      walletAddress,
    ]
  );
}

/**
 * Main execution function
 */
async function main() {
  try {
    console.log("Starting RPGF2 evaluation...");
    
    // Setup and validation
    const { wallet, scaffold } = validateAndSetup();
    console.log("Wallet address:", wallet.address);

    // Parse CSV and validate projects
    const projects = await parseCSV();

    if (projects.length === 0) {
      throw new Error("No projects found in CSV");
    }

    console.log(`Processing ${projects.length} projects...`);
    console.log("Skipping updateRecipients - only running evaluate...");

    // Calculate allocations
    const allocations = calculateAllocations(projects);
    
    console.log("Encoding evaluation data...");
    console.log("Allocations length:", allocations.length);
    console.log("Sample allocations:", allocations.slice(0, 5));

    const evaluationData = encodeEvaluationData(allocations, wallet.address);
    
    console.log("Evaluation data encoded successfully");
    console.log("Data length:", evaluationData.length);

    // Execute evaluate transaction
    console.log("Executing evaluate...");
    const evaluateTx = await scaffold.evaluate(
      CONFIG.POOL_ID,
      evaluationData,
      wallet.address,
      {
        gasLimit: CONFIG.GAS_LIMIT,
      }
    );
    const receipt = await evaluateTx.wait();

    console.log("Evaluation completed successfully!");
    console.log("Transaction hash:", evaluateTx.hash);
    console.log("Gas used:", receipt.gasUsed.toString());

    // Print evaluation summary
    printEvaluationSummary(projects, allocations);
  } catch (error) {
    handleError(error);
    process.exit(1);
  }
}

/**
 * Prints evaluation summary to console
 * @param {Array} projects - Array of project objects
 * @param {Array} allocations - Array of allocation values
 */
function printEvaluationSummary(projects, allocations) {
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
}

/**
 * Handles and logs errors with appropriate suggestions
 * @param {Error} error - The error to handle
 */
function handleError(error) {
  console.error("Error:", error.message);
  
  if (error.code || error.reason) {
    console.error("Error details:", {
      message: error.message,
      code: error.code,
      reason: error.reason,
    });
  }

  // Display transaction details for failures
  if (error.transactionHash) {
    console.error("Transaction hash:", error.transactionHash);
    if (error.transaction) {
      console.error("Transaction data:", error.transaction);
    }
  }

  // Provide specific suggestions based on error type
  if (error.message.includes("UNPREDICTABLE_GAS_LIMIT")) {
    console.error(
      "\nSuggestion: Try increasing gas limit or using a different RPC provider"
    );
  } else if (error.message.includes("CALL_EXCEPTION")) {
    console.error(
      "\nSuggestion: Check contract state, permissions, and data format"
    );
  } else if (error.message.includes("PRIVATE_KEY")) {
    console.error(
      "\nSuggestion: Set the PRIVATE_KEY environment variable"
    );
  } else if (error.message.includes("CSV")) {
    console.error(
      "\nSuggestion: Ensure the CSV file exists and has the correct format"
    );
  }
}

if (require.main === module) {
  main();
}
