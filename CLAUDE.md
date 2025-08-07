# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Scaffold-IE is a smart contract system implementing Impact Evaluation (IE) mechanisms for decentralized funding allocation. It uses Protocol Guild-style time-weighted formulas and EAS attestations to calculate fair distributions based on contributor activity and commitment over time.

**Core Concept**: The system creates funding pools where contributors receive allocations based on their time-weighted contributions, calculated using formulas like: `time_weight = sqrt((wearing_time) * full_or_part_time_multiplier)`

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
pnpm test:sepolia                # Test against Sepolia network
```

### Code Formatting

```bash
forge fmt               # Format Solidity code (always run before committing)
```

### Deployment

```bash
pnpm deploy:sepolia     # Deploy to Sepolia with verification
```

## Architecture Overview

### Strategy Pattern Implementation

The system uses a gas-efficient cloneable strategy pattern where different evaluation mechanisms can be implemented:

1. **ScaffoldIE.sol** - Main orchestrator contract

   - Manages pool creation and evaluation routing
   - Uses OpenZeppelin's `Clones` library for gas-efficient strategy deployment
   - Maps poolId to strategy addresses with metadata
   - Emits events for pool creation and evaluation

2. **Strategy System**:
   - `IStrategy.sol` - Interface defining `createIE()` and `evaluate()` functions
   - `BaseIEStrategy.sol` - Abstract base with hook methods (`_beforeCreateIE`, `_afterCreateIE`, etc.)
   - Concrete implementations:
     - `RetroFundingManual.sol` - Manual evaluation with EAS attestations
     - `ProtocolGuild.sol` - Time-weighted allocation using Protocol Guild formula

### Protocol Integrations

The system integrates with key protocols:

- **EAS (Ethereum Attestation Service)** - For attestation-based evaluation and impact measurement
- **Splits Protocol (0xSplits)** - Automated fund distribution based on calculated allocations
- **OpenZeppelin** - AccessControl, Pausable, and Clones for security and efficiency

### Role-Based Access Control

The system implements multiple roles for different operations:

- `ADMIN_ROLE` - Full administrative control
- `PAUSER_ROLE` - Emergency pause operations
- `EVALUATOR_ROLE` - Perform evaluations
- `MANAGER_ROLE` - Manage strategy configurations
- `SPLITTER_ROLE` - Update splits allocations

### Core Data Flow

1. **Pool Creation**: `createIE()` → Strategy clones are deployed and initialized with splits contract
2. **Registration**: Recipients are registered with their allocation parameters
3. **Evaluation**: `evaluate()` → Strategy calculates new allocations and updates splits
4. **Distribution**: Funds sent to splits contract automatically distribute to recipients

## File Structure

```
contracts/
├── ScaffoldIE.sol              # Main orchestrator
├── AttesterResolver.sol        # Custom EAS resolver for controlled attestations
├── interfaces/                 # Contract interfaces
│   ├── IScaffoldIE.sol        # Main contract interface
│   ├── IStrategy.sol          # Strategy pattern interface
│   └── ISplitMain.sol         # External splits protocol interface
└── IEstrategies/              # Strategy implementations
    ├── BaseIEStrategy.sol     # Abstract base strategy
    ├── RetroFundingManual.sol # Manual retroactive funding strategy
    └── ProtocolGuild.sol      # Time-weighted allocation strategy

test/
├── Base.t.sol                 # Common test utilities and setup
├── ScaffoldIE.t.sol           # Main contract tests
├── ProtocolGuild.t.sol        # Protocol Guild strategy tests
└── RetroStrategy.t.sol        # Retroactive funding strategy tests

script/
├── Base.s.sol                 # Base deployment script
└── Deploy.s.sol               # Main deployment script
```

## Key Configuration

- **Solidity Version**: 0.8.29 (specified in foundry.toml)
- **Source Directory**: `contracts/` (not the typical `src/`)
- **Optimizer**: Enabled with 200 runs and `via_ir = true`
- **Dependencies**: Managed via git submodules in `lib/`
- **Test Integration**: Live Sepolia contracts for realistic testing

## Development Patterns

### Adding New Strategy

1. Create new file in `contracts/IEstrategies/` inheriting from `BaseIEStrategy`
2. Implement required abstract methods:
   - `_createIE()` - Initialize strategy-specific pool data
   - `_evaluate()` - Calculate and update allocations
3. Use hook methods for additional logic:
   - `_beforeCreateIE()` / `_afterCreateIE()`
   - `_beforeEvaluate()` / `_afterEvaluate()`
4. Add comprehensive tests following existing patterns

### Working with Splits Protocol

- Use basis points (1_000_000 = 100%) for allocation precision
- Always ensure allocations sum to exactly 1_000_000
- Call `updateSplit()` after recalculating allocations
- Validate recipient addresses before updating splits

### EAS Integration

- Use `AttesterResolver` for controlled attestation validation
- Implement proper schema validation in strategies
- Consider attestation expiry and revocation handling
- Test attestation flows with mock attesters

## Testing Strategy

- Unit tests for individual functions and edge cases
- Integration tests for multi-contract workflows
- Gas optimization tests with `--gas-report`
- Live network testing against Sepolia deployments
- Mock external dependencies when testing in isolation

## Common Debugging

- Use `forge test -vvv` for detailed transaction traces
- Check event emissions for state changes tracking
- Verify role assignments with `hasRole()` checks
- Validate external protocol calls (EAS attestations, Splits updates)
- Monitor gas usage for clone deployments

## Deployed Contracts (Sepolia)

Key deployments are tracked in `broadcast/` directory. Check deployment scripts for latest addresses and verify on Etherscan for interaction.
