# ScaffoldIE

## Overview

ScaffoldIE is a scaffold smart contract for Impact Evaluations (IE). Built during the Impact Evaluation Research Retreat (IERR) 2025, it implements a layered distribution architecture that enables both portfolio-level and project-level distribution across multiple IEs.

### Motivation

During this Research Retreat, I was interested in automating Impact Evaluation (IE) iterations using smart contracts. How wonderful would it be if smart contracts could perform measurement and evaluation, determine weights, and automatically distribute funds? From a feasibility perspective, I concluded that the Protocol Guild membership model represents the minimal viable IE mechanism. Their compensation formula is remarkably simple and easily implementable on-chain. Creating incentives for Ethereum Core developers/researchers through donations from other protocols is crucial for retention, and as long as these incentives function, they continue to make significant contributions to Ethereum. As Ethereum grows, Protocol Guild's achievements become increasingly important, attracting donations from protocols like Uniswap and others. For them, the priority is not perfect evaluation accuracy, but rather how to distribute more funds to more Core developers/researchers effectively.
Additionally, the scope of this project includes not only on-chain measurement/evaluation but also manual weight updates based on off-chain evaluations, similar to existing RetroFunding mechanisms.
Building on discussions about FIL PGF, I focused on managing overall fund distribution through meta-evaluation of IE systems. The ScaffoldIE contract enables the creation of IE mechanisms based on different strategies under a core contract, with administrators able to adjust fund allocation between these IE mechanisms.

## Deployed Contracts (Sepolia)

- **Root Split Example**: [View on 0xSplits](https://app.splits.org/accounts/0x159F16726970a8E2067318A1bD0177029C0886A3/?chainId=11155111) - showing 4 IE pools with different allocations
- **ScaffoldIE**: [`0x31f0d35410f95aFAF29864c6dbd23Adfc8D28dfC`](https://sepolia.etherscan.io/address/0x31f0d35410f95aFAF29864c6dbd23Adfc8D28dfC)
- **RetroFundingManual strategy implementation**: [`0x96dD5187e48e4C116202BFD0001936814e68fF3F`](https://sepolia.etherscan.io/address/0x96dD5187e48e4C116202BFD0001936814e68fF3F)
- **ProtocolGuild strategy implementation**: [`0xfae2FD69e301d28CB03634AA958dC9ae1d041dcb`](https://sepolia.etherscan.io/address/0xfae2FD69e301d28CB03634AA958dC9ae1d041dcb)

## Technical Overview

## Core Architecture

### Strategy Pattern

ScaffoldIE implements a gas-efficient cloneable strategy pattern where different evaluation mechanisms can be plugged in:

```
ScaffoldIE (Orchestrator)
    ├── RetroFundingManual (Manual calculation)
    ├── ProtocolGuild (Time-weighted allocations)
    └── [Your Custom Strategy]
```

### Multi-Layer Distribution Architecture

![distribution](https://hackmd.io/_uploads/H1OdyzX_xe.png)
ScaffoldIE implements a sophisticated two-layer fund distribution system:

**Layer 1: Root Distribution**

- ScaffoldIE acts as the root split controller
- Evaluators at this level can adjust weights between different IE pools
- Enables portfolio-level impact allocation

**Layer 2: IE-Specific Distribution**

- Each IE pool has its own distribution mechanism
- Currently uses 0xSplits, but designed for future integrations (Drips, Superfluid)
- Independent evaluator access control per IE pool

### Key Components

1. **ScaffoldIE.sol** - Main orchestrator managing pool creation, evaluation routing, and root split control
2. **BaseIEStrategy.sol** - Abstract base providing hooks for custom evaluation logic
3. **Strategy Implementations**:
   - **RetroFundingManual**: Inspired by [Optimism](https://optimism.io) and [Filecoin](https://filecoin.io) retroactive funding models
   - **ProtocolGuild**: Based on [Protocol Guild](https://protocolguild.org) and implements Protocol Labs' [Generalized Impact Evaluator](https://research.protocol.ai/publications/generalized-impact-evaluators/ngwhitepaper2.pdf) concept as a minimal on-chain IE mechanism
4. **Distribution Layers**:
   - **Root Split**: Managed by ScaffoldIE for portfolio-level allocation
   - **IE Splits**: Individual distribution mechanisms per evaluation pool

### Protocol Integrations

- **EAS (Ethereum Attestation Service)**: ScaffoldIE is designed to align with hypercerts protocol v2 architecture
- **0xSplits Protocol**: Current implementation for automated fund distribution
- **Future Integrations**: Architecture supports [Drips](https://drips.network), [Superfluid](https://superfluid.finance), and other distribution protocols at the IE level

## How It Works

![sequence](https://hackmd.io/_uploads/HyOdLyQuxx.png)

![iteration](https://hackmd.io/_uploads/S1u_Ikmdel.png)

#### Scenario 1: Retroactive Funding

Creating a retroactive funding pool with off-chain measurement/evaluation:

```solidity
// Register contributors
address[] recipients = [alice, bob, charlie];
uint32[] allocations = [400000, 350000, 250000]; // 40%, 35%, 25%

// Create evaluation pool
scaffoldIE.createIE(data, initData, retroFundingStrategy);

// IE-specific evaluator updates distribution
scaffoldIE.evaluate(poolId, allocations, evaluator);
```

- Requires off-chain computation of each weight
- [Integration with GitHub Actions](https://github.com/tnkshuuhei/scaffold-ie/actions/runs/16822751416) that triggers the evaluate function with evaluator role and [updates weights on Split contract](https://app.splits.org/accounts/0xBC45cB7D86b2b32D2de0B22195Cdb71daa7b2faa/?chainId=11155111).

### Scenario 2: Protocol Guild

Time-weighted allocation inspired by [protocolguild.org](https://protocolguild.org):

```solidity
// Register with work types
WorkType[] types = [FULL_TIME, PART_TIME, FULL_TIME];

// Automatic calculation implementing minimal IE mechanism
// Alice (6 months full-time): sqrt(180 days) × 10 = 134.16
// Bob (6 months part-time): sqrt(180 days) × 5 = 67.08
// Charlie (3 months full-time): sqrt(90 days) × 10 = 94.87

// IE evaluator triggers recalculation
scaffoldIE.evaluate(guildPoolId, evalData, guildEvaluator);

// This pool receives funds based on root split allocation
```

### Time Weight Formula (Protocol Guild Implementation)

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

The final allocation calculation using sigma notation:
$s_i(t) = \frac{\sqrt{(d_i^{eval} - d_i^{start}) \cdot f_i}}{\sum_{j=1}^{n} \sqrt{(d_j^{eval} - d_j^{start}) \cdot f_j}} \times 1,000,000$

**Note**: Unlike the original Protocol Guild formula, our implementation uses:

- Active time calculation: `evaluation timestamp - start timestamp`
- Time units in days rather than months
- Using basis points (1,000,000) to adjust uint32

## Challenges Faced

The main challenge I encountered was the observability limitations on-chain. While the Protocol Guild case works well, for cases like RetroFunding, most of the metrics we want to observe are impossible to capture without external input (though creating decentralized oracles for metrics is an interesting problem in itself). It's not necessarily required to observe and evaluate metrics on-chain (which actually increases costs and storage demands). Rather, what's important is that data remains verifiable afterward, regardless of the technology used. For this project, I partially utilized EAS Attestations with future composability with Hypercerts v2 in mind, and I realized the importance of preserving data snapshots during measurement and evaluation phases.
