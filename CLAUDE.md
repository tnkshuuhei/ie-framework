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
   - `RetroFunding.sol` - Concrete implementation using EAS attestations for retroactive funding evaluation

### Protocol Integrations

The system integrates with key protocols:

- **EAS (Ethereum Attestation Service)** - For attestation-based evaluation and impact measurement
- **Splits Protocol** - Automated fund distribution based on calculated allocations
- **OpenZeppelin AccessControl** - Role-based permissions (EVALUATOR_ROLE, MEASURER_ROLE, PAUSER_ROLE)

### Evaluation Mechanisms

Current strategies support different evaluation approaches:

**RetroFunding Strategy**:

- Uses EAS attestations for impact measurement
- Implements role-based evaluation with EVALUATOR_ROLE and MEASURER_ROLE
- Supports pausable operations for emergency controls
- Custom AttesterResolver ensures only authorized attestations

### Core Data Flow

1. **Pool Creation**: `createIE()` → Strategy sets up evaluation framework and splits contract
2. **Registration**: Recipients are registered and configured within the strategy
3. **Evaluation**: `evaluate()` → Recalculates allocations based on strategy-specific logic and updates splits
4. **Distribution**: Funds sent to splits contract automatically distribute to recipients based on updated allocations

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
│   └── RetroFunding.sol       # EAS-based retroactive funding strategy
└── AttesterResolver.sol       # Custom EAS resolver for controlled attestations

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
- **Dependencies**: OpenZeppelin, EAS contracts, Splits contracts via git submodules

## Development Patterns

### Adding New Strategy

1. Inherit from `BaseIEStrategy` in `contracts/IEstrategies/`
2. Implement virtual `_createIE()` and `_evaluate()` methods
3. Use hook methods (`_beforeCreateIE`, `_afterCreateIE`, etc.) for setup/cleanup
4. Add comprehensive tests

### EAS Integration Development

1. Use `AttesterResolver` for controlled attestation validation
2. Implement proper role-based access controls (EVALUATOR_ROLE, MEASURER_ROLE)
3. Consider pausable patterns for emergency controls
4. Test attestation flows and resolver logic

### Working with Allocations

- Allocation calculations should be precise and deterministic
- Use basis points (1_000_000 = 100%) for precision in financial calculations
- Always ensure allocations sum to exactly 1_000_000 when updating splits
- Validate recipient addresses and allocations before updating splits

## Testing Strategy

- Unit tests for individual contracts and functions
- Integration tests for multi-contract workflows (EAS + splits + strategies)
- Test both happy path and edge cases (zero allocations, equal distributions, role permissions)
- Mock external dependencies (EAS, splits) when testing in isolation
- Test pausable functionality and access control restrictions

## Common Debugging

- Use `forge test -vvv` for detailed transaction traces
- Check event emissions for state changes
- Verify external protocol interactions (EAS attestations, Splits.updateSplit)
- Role-based access control testing requires proper account setup and role assignments
- EAS attestation validation and resolver logic debugging
