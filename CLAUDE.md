# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Scaffold-IE is a smart contract system implementing Impact Evaluation (IE) mechanisms for decentralized funding allocation. It uses Protocol Guild-style time-weighted formulas to calculate fair distributions based on contributor activity and commitment over time.

**Core Concept**: The system creates funding pools where contributors receive allocations based on their time-weighted contributions, calculated using the formula: `time_weight = sqrt((wearing_time) * full_or_part_time_multiplier)`

## Technology Stack

- **Solidity ^0.8.29** - Smart contract development
- **Foundry** - Primary development framework (testing, building, deployment)
- **Hardhat** - Additional tooling for network configuration
- **pnpm** - Package manager (always use pnpm, not npm)

## Essential Commands

### Development Workflow
```bash
pnpm setup              # Install dependencies and setup environment  
pnpm clean              # Clean build artifacts
pnpm build              # Clean and compile contracts
pnpm test               # Clean and run all tests
pnpm coverage           # Generate test coverage reports
```

### Testing Commands
```bash
forge test                        # Run all tests
forge test -vvv                   # Run with detailed output for debugging
forge test --match-test TestName  # Run specific test
forge test --gas-report          # Show gas usage
forge test --rpc-url https://sepolia.drpc.org  # Test against Sepolia
```

### Code Formatting
```bash
forge fmt               # Format Solidity code (always run before committing)
```

## Architecture Overview

### Strategy Pattern Implementation

The system uses a pluggable strategy pattern where different evaluation mechanisms can be implemented:

1. **ScaffoldIE.sol** - Main orchestrator contract
   - Manages pool creation and evaluation routing
   - Delegates to strategy contracts for specific IE logic
   - Maps poolId to strategy addresses

2. **Strategy System**:
   - `IStrategy.sol` - Interface defining `createIE()` and `evaluate()` functions
   - `BaseIEStrategy.sol` - Abstract base with hook methods for common functionality
   - `ProtocolGuild.sol` - Concrete implementation of Protocol Guild time-weighting

### Protocol Integrations

The system integrates with three key protocols:

- **Hats Protocol** - Role-based access control and hierarchical permissions
- **Splits Protocol** - Automated fund distribution based on calculated allocations  
- **Hypercerts** - Impact certification (via eligibility modules)

### Time-Weighted Allocation Formula

Protocol Guild strategy implements:
```solidity
// Individual time weight calculation
time_weight_i = sqrt(wearing_time_i * multiplier_i)

// Where multiplier_i = 1.0 (full-time) or 0.5 (part-time)
// Final allocation = (time_weight_i / sum_all_weights) * 100%
```

### Core Data Flow

1. **Pool Creation**: `createIE()` → Strategy deploys hats, modules, splits contract
2. **Time Tracking**: TimeControlModule tracks contributor activity periods
3. **Evaluation**: `evaluate()` → Recalculates allocations and updates splits
4. **Distribution**: Funds sent to splits contract automatically distribute to recipients

## File Structure

```
contracts/
├── ScaffoldIE.sol              # Main orchestrator
├── interfaces/                 # Contract interfaces
│   ├── IScaffoldIE.sol        # Main contract interface
│   ├── IStrategy.sol          # Strategy pattern interface
│   └── ...                    # External protocol interfaces
├── IEstrategies/              # Strategy implementations
│   ├── BaseIEStrategy.sol     # Abstract base strategy
│   └── ProtocolGuild.sol      # Protocol Guild implementation
└── Hats/                      # Hats protocol modules
    ├── HatCreatorModule.sol   # Creates hats for roles
    ├── TimeControlModule.sol  # Tracks time periods
    └── HypercertsEligibilityModule.sol

test/
├── ScaffoldIE.t.sol           # Main contract tests
└── helpers/                   # Test utilities

script/
└── Base.s.sol                 # Deployment base script
```

## Key Configuration

- **Solidity Version**: 0.8.29 (in foundry.toml)
- **Source Directory**: `contracts/` (not the typical `src/`)
- **Optimizer**: Enabled with 200 runs and viaIR
- **Dependencies**: OpenZeppelin, Hats Protocol, Splits contracts via git submodules

## Development Patterns

### Adding New Strategy
1. Inherit from `BaseIEStrategy` in `contracts/IEstrategies/`
2. Implement virtual `_createIE()` and `_evaluate()` methods
3. Use hook methods (`_beforeCreateIE`, `_afterCreateIE`, etc.) for setup/cleanup
4. Add comprehensive tests

### Hat Module Development
1. Create in `contracts/Hats/` following HatsModule patterns
2. Implement eligibility or toggle interfaces as needed
3. Integration test with TimeControlModule for time tracking

### Working with Time Weights
- Time calculations use `block.timestamp` for current time
- `getWearingElapsedTime()` returns seconds since hat was minted
- Formula uses basis points (1_000_000 = 100%) for precision
- Always ensure allocations sum to exactly 1_000_000

## Testing Strategy

- Unit tests for individual contracts and functions
- Integration tests for multi-contract workflows (hats + splits + modules)
- Test both happy path and edge cases (zero time, equal distributions)
- Mock external dependencies when testing in isolation

## Common Debugging

- Use `forge test -vvv` for detailed transaction traces
- Check event emissions for state changes
- Verify external protocol interactions (Hats.mintHat, Splits.updateSplit)
- Time-based calculations sensitive to block.timestamp in tests