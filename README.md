# Scaffold IE (MVIE)

A smart contract scaffold for setting up Impact Evaluations (IE) with modular strategy patterns and retroactive funding mechanisms.

[Example](https://app.splits.org/accounts/0x159F16726970a8E2067318A1bD0177029C0886A3/?chainId=11155111)

## Overview

Scaffold IE is a modular smart contract system that enables the creation and management of Impact Evaluations (IE) with flexible strategy implementations. It provides a foundation for retroactive funding and other impact evaluation mechanisms through a pluggable strategy architecture.

## Features

- **Modular Strategy Pattern**: Implement custom IE strategies by extending the base contract
- **Cloneable Strategies**: Gas-efficient strategy deployment using proxy pattern
- **Retroactive Funding**: Built-in support for retroactive funding mechanisms
- **Access Control**: Role-based access control for different operations
- **Split Management**: Integration with 0xSplits for fund distribution
- **EAS Integration**: Ethereum Attestation Service integration for attestations
- **Pausable**: Emergency pause functionality for security

## Architecture

### Core Components

1. **ScaffoldIE.sol**: Main contract that orchestrates IE creation and management
2. **BaseIEStrategy.sol**: Abstract base class for implementing IE strategies
3. **RetroFunding.sol**: Example strategy implementation for retroactive funding
4. **AttesterResolver.sol**: EAS integration for attestation handling
5. **Cloneable Strategy Pattern**: Gas-efficient strategy deployment using OpenZeppelin's Clones library

### Key Roles

- **DEFAULT_ADMIN_ROLE**: Full administrative access
- **PAUSER_ROLE**: Can pause/unpause the contract
- **SPLITTER_ROLE**: Can create and update fund distribution routes
- **EVALUATOR_ROLE**: Can evaluate IE strategies
- **MANAGER_ROLE**: Can manage recipients and strategy-specific operations

## Installation & Setup

### Prerequisites

- Node.js (v18+)
- Foundry
- Hardhat

## Development

### Compile Contracts

```bash
# Using Foundry
forge build


```

### Run Tests

```bash
# Using Foundry
pnpm test:sepolia
```

## Usage

### Creating an IE

1. **Deploy a Strategy**: First, deploy your IE strategy contract
2. **Register Strategy**: Add the strategy to the cloneable strategies list
3. **Create IE**: Call `createIE()` with your strategy and initialization data

```solidity
// Example: Creating a RetroFunding IE
bytes memory initData = abi.encode(easAddress, schemaUID, adminAddress);
scaffoldIE.createIE(ieData, initData, retroFundingStrategyAddress);
```

### Managing Cloneable Strategies

The ScaffoldIE contract uses a cloneable strategy pattern to reduce gas costs and enable efficient strategy deployment. Only strategies marked as cloneable can be used to create new IEs.

```solidity
// Set a strategy as cloneable (admin only)
scaffoldIE.setCloneableStrategy(strategyAddress, true);

// Check if a strategy is cloneable
bool isCloneable = scaffoldIE.isCloneableStrategy(strategyAddress);

// Create IE using a cloneable strategy
scaffoldIE.createIE(ieData, initData, cloneableStrategyAddress);
```

**Benefits of Cloneable Strategies:**

- **Gas Efficiency**: Deploy strategy once, clone for multiple IEs
- **Consistency**: All clones share the same logic but have independent state
- **Upgradeability**: Update the master strategy to affect future clones
- **Cost Reduction**: Significant gas savings compared to deploying each strategy individually

### Managing Recipients

```solidity
// Register initial recipients
address[] memory recipients = [addr1, addr2, addr3];
scaffoldIE.registerRecipients(poolId, recipients, caller);

// Update recipients
address[] memory newRecipients = [addr4, addr5, addr6];
scaffoldIE.updateRecipients(poolId, newRecipients, caller);
```

### Evaluating IE

```solidity
// Evaluate the IE strategy
bytes memory evaluationData = abi.encode(attestationData);
scaffoldIE.evaluate(poolId, evaluationData, evaluator);
```

### Creating Distribution Routes

```solidity
// Create initial route with allocations
uint32[] memory allocations = [50, 30, 20]; // percentages
scaffoldIE.createIERoute(allocations);

// Update route allocations
uint32[] memory newAllocations = [40, 35, 25];
scaffoldIE.updateRoute(newAllocations);
```

## Strategy Implementation

To create a custom IE strategy:

1. **Extend BaseIEStrategy**:

```solidity
contract MyCustomStrategy is BaseIEStrategy {
    // Implement required functions
    function _initialize(bytes memory _initializeData) internal override {
        // Custom initialization logic
    }

    function _evaluate(bytes memory _data) internal override {
        // Custom evaluation logic
    }
}
```

2. **Required Functions**:

   - `_initialize()`: Strategy-specific initialization
   - `_evaluate()`: Core evaluation logic
   - `_registerRecipients()`: Recipient management
   - `getAddress()`: Return the strategy's address

3. **Cloneable Strategy Requirements**:
   - Strategy must be marked as cloneable by admin
   - Strategy must implement proper initialization logic
   - Each clone maintains independent state while sharing logic

## Contract Addresses

### Sepolia

- [ScaffoldIE.sol](https://sepolia.etherscan.io/address/0x31f0d35410f95aFAF29864c6dbd23Adfc8D28dfC)
- [RetroFundingManual strategy implementation](https://sepolia.etherscan.io/address/0x96dD5187e48e4C116202BFD0001936814e68fF3F)
- [Protocol Guild strategy implementation](https://sepolia.etherscan.io/address/0xfae2FD69e301d28CB03634AA958dC9ae1d041dcb)

## Testing

Run the test suite:

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testCreateIE

# Run with verbose output
forge test -vvv
```

## Security

- **Access Control**: Role-based permissions for all critical operations
- **Pausable**: Emergency pause functionality
- **Input Validation**: Comprehensive input validation and error handling
- **Audit Ready**: Clean, auditable code structure

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## Sequence Diagram

```mermaid
sequenceDiagram

actor ad as Admin
participant sc as ScaffoldIE.sol
participant retro as RetroFunding.sol
participant sp as Split
actor e as Evaluators(retro)
actor m as Measurer(retro)

ad ->> sc : createIE() with Strategy implementation
sc ->> retro: create new IE
retro->> retro: registerRecipients()
retro --> sc: get Hat contract
retro ->> sp: createSplit with initial recipients/allocations
sp ->> retro: return created splits contract address
retro ->> sc: return address
sc-> sc: mapping poolCount => split address(this could be just a address for superfluid case)
sc ->> ad: return tuple(poolId(poolCount) , address)

m ->> sc: updateRecipients(address[] newRecipients)
sc -> sc: update mapping
e ->> sc: evaluate()
sc ->> retro: IStrategy(strategy).evaluate()
retro --> sc: getRecipients()
retro ->> sp : updateSplit()
```
