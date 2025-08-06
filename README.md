## TL;DR

Scaffold smartcontract to setup IE. Or you can say "MVIE"

<!-- ![scaffold](https://hackmd.io/_uploads/rya7Or5Dex.png) -->

- [ ] Who determin the distribution between IEs and how
- [ ] What kind of AccessControl roles we need for strategy
- [ ] TODO: add attestation(\_beforeEvaluation) flow on sequenceDiagram

```mermaid
sequenceDiagram

actor ad as Admin
participant sc as ScaffoldIE.sol
participant retro as RetroFunding.sol
participant sp as Split
actor e as Evalators(retro)
actor m as Measurere(retro)


ad ->> sc : createIE() with Strategy implementation
sc ->> retro: create new IE
retro->> retro: registerRecipients()
retro --> sc: get Hat contract
retro ->> sp: createSplit with initial recipients/allocations
sp ->> retro: retun created splits contract address
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
