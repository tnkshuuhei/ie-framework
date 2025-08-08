# [ScaffoldIE](https://github.com/tnkshuuhei/scaffold-ie)

## Overview

ScaffoldIE is a scaffold smart contract for Impact Evaluator (IE) built during the [Impact Evaluator Research Retreat (IERR) 2025](https://www.researchretreat.org/ierr-2025/). This implements a layered distribution architecture that enables both portfolio-level and project-level distribution across multiple IEs.

### Motivation

During the Research Retreat, I was interested in automating Impact Evaluator iterations using smart contracts. Imagine if smart contracts could perform measurement and evaluation, determine weights, and automatically distribute funds. From a feasibility perspective, I concluded that Protocol Guild's membership model represents a minimal viable IE mechanism. Their reward formula is remarkably simple and easily implemented on-chain. Additionally, the scope of this project includes not only on-chain measurement/evaluation but also manual weight updates based on off-chain evaluations, similar to existing RetroFunding mechanisms. And I focused on managing overall fund distribution through meta-evaluation (as an external input) of IE systems. The ScaffoldIE contract enables the creation of IE mechanisms based on different strategies under a core contract, with administrators able to adjust fund allocation between these IE mechanisms.

## Core Architecture

### Two-Layer Distribution Architecture

![distribution](https://hackmd.io/_uploads/H1OdyzX_xe.png)
ScaffoldIE implements a two-layer fund distribution system. The first layer handles root distribution where ScaffoldIE acts as the root split controller, allowing evaluators at this level to adjust weights between different IEs. The second layer manages IE-specific distribution, where each IE maintains its own distribution mechanism. Each IE features independent evaluator access control.

### Strategy Pattern

ScaffoldIE implements a gas-efficient cloneable strategy pattern where different evaluation mechanisms can be plugged in:

```
ScaffoldIE (Orchestrator)
    ├── RetroFundingManual (Manual calculation)
    ├── ProtocolGuild (Time-weighted allocations)
    └── [Your Custom Strategy]
```

### Key Components

The ScaffoldIE system consists of several core components that work together to create a flexible and efficient impact evaluation framework. The main orchestrator is ScaffoldIE.sol, which handles IE creation, routing, and root split control. This contract serves as the central hub where users mainly interact with the system.

For custom evaluation logic, I've created BaseIEStrategy.sol as an abstract base strategy contract that provides hooks for implementing different evaluation mechanisms. This design allows developers to easily plug in their own evaluation strategies!

The strategy implementations include two main approaches. First, there's the Manual Evaluation strategy (RetroFundingManual) which enables manual weight adjustments based on off-chain evaluations. This approach is inspired by retroactive funding models used by Optimism and Filecoin.

Second, I've implemented a ProtocolGuild strategy based on the Protocol Guild's time-weighted formula. This implements the Generalized Impact Evaluator concept as a minimal on-chain IE mechanism, providing a more automated approach.

The Root Split layer is managed by ScaffoldIE for portfolio-level allocation, while the IE Splits layer provides individual distribution mechanisms for each evaluation pool.

### Protocol Integrations

The current implementation uses the 0xSplits Protocol for fund distribution. I've designed the system with future integrations in mind to ensure scalability and flexibility.

We can add custom strategies with other distribution mechanisms such as Drips and Superfluid. These integrations will provide more sophisticated distribution mechanisms while maintaining the core evaluation framework. I'm also exploring the integration of Hypercerts v2 with the Ethereum Attestation Service for certification.

## How It Works

![sequence](https://hackmd.io/_uploads/HyOdLyQuxx.png)

![iteration](https://hackmd.io/_uploads/S1u_Ikmdel.png)

#### Scenario 1: Manual Evaluation (Retroactive Funding)

Creating an IE where evaluators can manually update weights based on off-chain measurements and evaluations:

```solidity
// Register contributors
address[] memory recipients = new address[](4);
recipients[0] = alice;
recipients[1] = bob;
recipients[2] = carl;
recipients[3] = david;

uint32[] memory initialAllocations = new uint32[](4); // 25%, 25%, 25%, 25%
initialAllocations[0] = 250000;
initialAllocations[1] = 250000;
initialAllocations[2] = 250000;
initialAllocations[3] = 250000;

bytes memory data = abi.encode(recipients, initialAllocations);

bytes memory initializeData = abi.encode(address(eas), schemaUID, admin);

// Create IE
scaffoldIE.createIE(data, initializeData, strategy);

uint32[] memory newAllocations = new uint32[](4);
newAllocations[0] = 100000;
newAllocations[1] = 200000;
newAllocations[2] = 300000;
newAllocations[3] = 400000;

bytes memory evaluationData = abi.encode(dataset, newAllocations, address(retroFunding), block.chainid, evaluator);

// IE-specific evaluator updates distribution
scaffoldIE.evaluate(poolId, evaluationData, evaluator);
```

This approach requires off-chain weight calculation.
The system includes [integration with GitHub Actions](https://github.com/tnkshuuhei/scaffold-ie/actions/runs/16822751416) that triggers the evaluate function and [updates weights on the Split contract](https://app.splits.org/accounts/0xBC45cB7D86b2b32D2de0B22195Cdb71daa7b2faa/?chainId=11155111).

### Scenario 2: Protocol Guild

Time-weighted allocation inspired by [protocolguild.org](https://protocolguild.org):

```solidity
// Register with work types
enum WorkType {
    FULL,
    PARTIAL
}

bytes memory evaluationData = abi.encode(dataset/*this should be empty*/, address(protocolGuild), block.chainid, evaluator);

// IE evaluator triggers recalculation
scaffoldIE.evaluate(poolId, evaluationData, evaluator);
```

### Time Weight Formula

The time weight for each contributor is calculated using the following formula:

#### Individual Time Weight

For contributor $i$ at evaluation time $t$:
$w_i(t) = \sqrt{(d_i^{eval} - d_i^{start}) \cdot f_i}$

Where:

- $w_i(t)$ = time weight for contributor $i$ at time $t$
- $d_i^{eval}$ = evaluation timestamp (in days)
- $d_i^{start}$ = start date timestamp (in days) for contributor $i$
- $(d_i^{eval} - d_i^{start})$ = active contribution period
- $f_i$ = full/part-time multiplier for contributor $i$

#### Full/Part-time Multiplier

In our implementation:
$f_i = \begin{cases}
10 & \text{if full-time (FULL)} \\
5 & \text{if part-time (PARTIAL)}
\end{cases}$

#### Normalized Share Calculation

The final allocation percentage for contributor $i$:
$s_i(t) = \frac{w_i(t)}{\sum_{j=1}^{n} w_j(t)} \times 1,000,000$

Where $n$ is the total number of contributors, and results are in basis points (1,000,000 = 100%).

The total weight across all contributors:
$W_{total}(t) = \sum_{i=1}^{n} w_i(t) = \sum_{i=1}^{n} \sqrt{(d_i^{eval} - d_i^{start}) \cdot f_i}$

The final allocation calculation:
$s_i(t) = \frac{\sqrt{(d_i^{eval} - d_i^{start}) \cdot f_i}}{\sum_{j=1}^{n} \sqrt{(d_j^{eval} - d_j^{start}) \cdot f_j}} \times scale$

**Note**: Original Protocol Guild formula uses this:
$w_i(t) = \sqrt{(d_i^{start} - d_i^{inactive}) \cdot f_i}$

## Deployed Contracts (Sepolia)

- **Root Split Example**: [View on 0xSplits](https://app.splits.org/accounts/0x159F16726970a8E2067318A1bD0177029C0886A3/?chainId=11155111) - showing 4 IE pools with different allocations
- **ScaffoldIE**: [`0x31f0d35410f95aFAF29864c6dbd23Adfc8D28dfC`](https://sepolia.etherscan.io/address/0x31f0d35410f95aFAF29864c6dbd23Adfc8D28dfC)
- **RetroFundingManual strategy implementation**: [`0x96dD5187e48e4C116202BFD0001936814e68fF3F`](https://sepolia.etherscan.io/address/0x96dD5187e48e4C116202BFD0001936814e68fF3F)
- **ProtocolGuild strategy implementation**: [`0xfae2FD69e301d28CB03634AA958dC9ae1d041dcb`](https://sepolia.etherscan.io/address/0xfae2FD69e301d28CB03634AA958dC9ae1d041dcb)
