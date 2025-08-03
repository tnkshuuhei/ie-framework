# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Scaffold-IE is a smart contract system implementing "Impact Evaluation" (IE) mechanisms for decentralized funding allocation. It's an MVIE (Minimum Viable Impact Evaluator) that enables Protocol Guild-style time-weighted funding distributions using mathematical formulas to calculate fair allocations based on contributor activity and time commitment.

## Technology Stack

- **Solidity ^0.8.29** - Smart contract development
- **Foundry** - Primary development framework
- **Hardhat** - Secondary tooling framework  
- **TypeScript** - Configuration and scripting
- **pnpm** - Package management

## Essential Commands

### Development
```bash
pnpm setup           # Install dependencies and setup environment
pnpm clean          # Clean build artifacts
pnpm build          # Clean and build contracts
pnpm test           # Clean and run tests
pnpm coverage       # Generate test coverage reports
```

### Deployment
```bash
pnpm deploy:UUPS-sepolia    # Deploy to Sepolia testnet with verification
pnpm upgrade               # Upgrade UUPS contracts on Sepolia
```

### Testing
- Use `forge test` for individual test runs
- Tests located in `test/` directory
- Foundry supports unit tests, fuzz testing, and fork testing

## Architecture

### Core System Components

1. **ScaffoldIE.sol** - Main contract implementing the Impact Evaluation system
2. **Hats Modules** - Role-based access control and functionality:
   - `HatCreatorModule.sol` - Creates and manages hats for roles
   - `TimeControlModule.sol` - Tracks time-based metrics for contributors  
   - `HypercertsEligibilityModule.sol` - Integrates with Hypercerts for impact verification

### Protocol Integrations

- **Hats Protocol** - Role management and access control
- **Splits Protocol** - Fund distribution mechanisms
- **Hypercerts** - Impact certification and eligibility
- **OpenZeppelin** - Security and upgradeability patterns

### Mathematical Foundation

The system uses Protocol Guild's time-weight formula:
```
time_weight_i = √((start_date_i - months_inactive_i) × full_or_part_time_i)
normalized_share_i = (time_weight_i / Σtime_weights) × 100
```

## Development Workflow

1. **Pool Creation**: Admins create funding pools with recipients, evaluators, and initial allocations
2. **Role Management**: Hats Protocol manages different roles (admin, evaluator, recipient)
3. **Time Tracking**: TimeControlModule tracks contributor activity periods
4. **Evaluation Process**: Periodic recalculation of allocations using time-weighted formulas
5. **Fund Distribution**: Splits protocol distributes funds according to calculated shares

## Configuration

- **foundry.toml** - Primary build configuration with Solidity 0.8.29
- **hardhat.config.ts** - Additional tooling configuration
- **remappings.txt** - Import path mappings for lib dependencies
- Environment variables required for API keys (Alchemy, Etherscan)

## Key Patterns

- **UUPS Upgradeable** - Contracts use OpenZeppelin's upgrade pattern
- **Modular Architecture** - Hats modules provide extensible functionality
- **Multi-network Support** - Configured for mainnet, sepolia, base, optimism
- **Time-weighted Calculations** - Sophisticated mathematical formulas for fair allocation