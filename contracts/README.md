# Core Contract

## Core Architecture

ScaffoldIE implements a gas-efficient cloneable strategy pattern where different evaluation mechanisms can be plugged in:

```
ScaffoldIE (Orchestrator)
    ├── RetroFundingManual (Manual calculation)
    ├── ProtocolGuild (Time-weighted allocations)
    └── [Your Custom Strategy]
```

- Deploy strategy logic once, clone for multiple evaluation pools
- Significant gas savings (up to 90% reduction in deployment costs)
- Consistent logic with independent state management

```mermaid
sequenceDiagram

actor ad as Admin
participant sc as ScaffoldIE.sol
participant retro as RetroFunding.sol
participant sp as Split
actor e as Evaluators(retro)

ad ->> sc : createIE() with Strategy implementation
sc ->> retro: create new IE
retro->> retro: registerRecipients()
retro --> sc: get Hat contract
retro ->> sp: createSplit with initial recipients/allocations
sp ->> retro: return created splits contract address
retro ->> sc: return address
sc-> sc: mapping poolCount => split address(this could be just a address for superfluid case)

e ->> sc: evaluate()
sc ->> retro: IStrategy(strategy).evaluate()
retro --> sc: getRecipients()
retro ->> sp : updateSplit()
```
