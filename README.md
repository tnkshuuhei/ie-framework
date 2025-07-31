## e.g. Protocol Guild style of IE

```
ImpactEvaluator {
 foreach round(4m) {
   metrics = measure(time, full_or_part_time)
   weight = calculateTimeWeight()
   rewards = split(weight)
 }
}
```

## Time Weight Formula

The time weight for each contributor is calculated using the following formula:

### Individual Time Weight

For contributor $i$ at evaluation round $t$:

$$w_i(t) = \sqrt{(d_i^{start} - d_i^{inactive}) \cdot f_i}$$

Where:

- $w_i(t)$ = time weight for contributor $i$ at time $t$
- $d_i^{start}$ = start date (in months) for contributor $i$
- $d_i^{inactive}$ = months inactive for contributor $i$
- $f_i$ = full/part-time multiplier for contributor $i$

### Full/Part-time Multiplier

$$
f_i = \begin{cases}
1.0 & \text{if full-time } \\
0.5 & \text{if part-time }
\end{cases}
$$

### Normalized Share Calculation

The final share percentage for contributor $i$:

$$s_i(t) = \frac{w_i(t)}{\sum_{j=1}^{n} w_j(t)} \times 100$$

Where $n$ is the total number of contributors.

The total weight across all contributors:

$$W_{total}(t) = \sum_{i=1}^{n} w_i(t) = \sum_{i=1}^{n} \sqrt{(d_i^{start} - d_i^{inactive}) \cdot f_i}$$

The final share calculation using sigma notation:

$$s_i(t) = \frac{\sqrt{(d_i^{start} - d_i^{inactive}) \cdot f_i}}{\sum_{j=1}^{n} \sqrt{(d_j^{start} - d_j^{inactive}) \cdot f_j}} \times 100$$

---

### Flow

1. initialize contract

   1. initialize hat, splits contract and module factory
   2. create/mint Top hat

2. create pool
   1. create manager hat for each pool
   2. deploy modules based on inplementation
   3. `hats.mintHat(managerHatId, moduleAddress);`
   4. create new splits with recipients data
3.

> Each member’s share of the split contract is calculated using member-specific inputs. There are two parts to the calculation:
> Calculate each member’s time*weight: time_weight = SQRT((start_date - months_inactive) * full*or_part_time)
> Normalize time_weight as a percentage: split_share = (time_weight / total_time_weights) * 100
> This formulation recognizes the local knowledge contributors gain over time, and uses that as a proxy for “value to the commons” and to allocate funding to members. Existing contributor weights get “diluted” as newcomers show up. Continuing contributors get additional weight per month they are active.
> Each member’s time-weight is updated onchain every quarter along with an Ethereum address they control to allocate the funding flowing through the mechanism.

```mermaid
sequenceDiagram
    participant Admin
    participant IE as ScaffoldIE Contract
    participant Hats as HatsProtocol
    participant Splits as SplitsContract
    participant Factory as ModuleFactory
    participant Creator as HatCreatorModule
    participant TimeControl as TimeControlModule
    participant Evaluators
    participant Recipients

    Note over Admin,Recipients: Contract Initialization
    Admin->>IE: constructor(owner, hats, splits, metadata, imageURL, factory, creatorImpl, timeControlImpl)
    IE->>Hats: mintTopHat(owner, metadata, imageURL)
    Hats-->>IE: topHatId
    IE->>IE: Store contract addresses and topHatId

    Note over Admin,Recipients: Pool Creation Process
    Admin->>IE: createPool(encodedData)
    IE->>IE: Decode pool configuration data
    IE->>IE: Validate inputs (addresses, arrays, allocations)

    IE->>Hats: createHat(parentId, metadata, maxSupply, eligibility, toggle, mutable, imageURL)
    Hats-->>IE: managerHatId
    IE->>IE: Store poolToManagerHat[poolId] = managerHatId

    IE->>Factory: createHatsModule(creatorImpl, managerHatId, "", initData, 0)
    Factory-->>IE: hatCreatorModule
    IE->>Hats: mintHat(managerHatId, hatCreatorModule)

    IE->>Factory: createHatsModule(timeControlImpl, managerHatId, "", initData, 0)
    Factory-->>IE: timeControlModule
    IE->>Hats: mintHat(managerHatId, timeControlModule)

    IE->>Splits: createSplit(recipients, allocations, 0, admin)
    Splits-->>IE: splitsContract
    IE->>IE: Store splitsContracts[poolId] = splitsContract

    IE->>Creator: createHat(managerHatId, evaluatorMetadata, 1, eligibility, toggle, mutable, "")
    Creator-->>IE: evaluatorHatId

    IE->>Creator: createHat(managerHatId, recipientMetadata, recipients.length, eligibility, toggle, mutable, "")
    Creator-->>IE: recipientHatId

    loop For each evaluator
        IE->>TimeControl: mintHat(evaluatorHatId, evaluator, block.timestamp)
    end

    loop For each recipient
        IE->>TimeControl: mintHat(recipientHatId, recipient, block.timestamp)
    end

    IE->>IE: emit PoolCreated(poolId, managerHatId, splitsContract, evaluatorHatId, recipientHatId, evaluators, recipients)

    Note over Admin,Recipients: Evaluation Process
    Evaluators->>IE: evaluate(poolId)
    IE->>IE: Validate pool exists
    IE->>IE: Get splitsContract and recipients from pool
    IE->>IE: Calculate time-weighted allocations
    IE->>Splits: updateSplit(splitsContract, accounts, percentAllocations, 0)

    Note over Admin,Recipients: Time Weight Calculation
    Note over IE: For each contributor i:
    Note over IE: time_weight_i = √((start_date_i - months_inactive_i) × full_or_part_time_i)
    Note over IE: normalized_share_i = (time_weight_i / Σtime_weights) × 100
```

### Sources

[https://app.splits.org/accounts/0xd982477216daDD4C258094B071b49D17b6271d66/?chainId=1](https://app.splits.org/accounts/0xd982477216daDD4C258094B071b49D17b6271d66/?chainId=1)

[Time weight](https://protocol-guild.readthedocs.io/en/latest/01-membership.html#time-weight)
