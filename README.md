## TL;DR

Scaffold smartcontract to setup IE. Or you can say "MVIE"
![scaffold](https://hackmd.io/_uploads/rya7Or5Dex.png)

## Use cases

### e.g. Protocol Guild style IE

![protocol-guild-diagram](https://hackmd.io/_uploads/SJ3caQ5wxg.png)

```
ImpactEvaluator {
 foreach round(4m) {
   claims = "Contributions to Ethereum developments"
   metrics = measure(time, full_or_part_time)
   weight = calculateTimeWeight()
   rewards = split(weight)
 }
}
```

#### Time Weight Formula

The time weight for each contributor is calculated using the following formula:

#### Individual Time Weight

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

> Each member’s share of the split contract is calculated using member-specific inputs. There are two parts to the calculation:
> Calculate each member’s time*weight: time_weight = SQRT((start_date - months_inactive) * full*or_part_time)
> Normalize time_weight as a percentage: split_share = (time_weight / total_time_weights) * 100
> This formulation recognizes the local knowledge contributors gain over time, and uses that as a proxy for “value to the commons” and to allocate funding to members. Existing contributor weights get “diluted” as newcomers show up. Continuing contributors get additional weight per month they are active.
> Each member’s time-weight is updated onchain every quarter along with an Ethereum address they control to allocate the funding flowing through the mechanism.

```mermaid
sequenceDiagram
    actor Admin
    participant IE as ScaffoldIE Contract
    participant Strategy as ProtocolGuild Strategy
    participant Hats as HatsProtocol
    participant Splits as SplitsContract
    participant Factory as ModuleFactory
    participant Creator as HatCreatorModule
    participant TimeControl as TimeControlModule
    participant Evaluators
    actor Recipients

    Note over Admin,Recipients: Contract Initialization
    Admin->>IE: constructor(owner, hats, splits, factory, creatorImpl)
    IE->>IE: Store contract addresses and owner

    Note over Admin,Recipients: Pool Creation Process
    Admin->>IE: createIE(encodedData, strategy)
    IE->>Strategy: createIE(encodedData)
    Strategy->>Strategy: Decode recipient data and evaluators

    Strategy->>Hats: mintTopHat(strategy, metadata, imageURL)
    Hats-->>Strategy: topHatId

    Strategy->>Hats: createHat(parent: topHatId, manager metadata)
    Hats-->>Strategy: managerHatId

    Strategy->>Factory: createHatsModule(creatorImpl, managerHatId)
    Factory-->>Strategy: hatCreatorModule
    Strategy->>Hats: mintHat(managerHatId, hatCreatorModule)

    Strategy->>Factory: createHatsModule(timeControlImpl, managerHatId)
    Factory-->>Strategy: timeControlModule
    Strategy->>Hats: mintHat(managerHatId, timeControlModule)

    Strategy->>Creator: createHat(evaluator metadata, evaluators.length)
    Creator-->>Strategy: evaluatorHatId

    Strategy->>Creator: createHat(recipient metadata, recipients.length)
    Creator-->>Strategy: recipientHatId

    Strategy->>TimeControl: mintHat(evaluatorHatId, evaluator, timestamp)
    TimeControl->>Evaluators: mintHat()
    Strategy->>TimeControl: mintHat(recipientHatId, recipient, timestamp)
    TimeControl->>Recipients: mintHat()

    Strategy->>Splits: createSplit(recipients, allocations, 0, strategy)
    Splits-->>Strategy: splitsContract

    Strategy-->>IE: topHatId
    IE->>IE: poolCount++, store strategy
    IE->>IE: emit PoolCreated(poolId, strategy)

    Note over Admin,Recipients: Evaluation Process
    Evaluators->>IE: evaluate(poolId, data)
    IE->>Strategy: evaluate(data)
    Strategy->>TimeControl: getWearingElapsedTime(recipient, recipientHatId)
    TimeControl-->>Strategy: elapsedTime

    Strategy->>Strategy: Calculate time-weighted allocations
    Note over Strategy: For each recipient i:
    Note over Strategy: time_weight_i = √(elapsed_time_i × (full_time ? 100 : 50))
    Note over Strategy: normalized_share_i = (time_weight_i / Σtime_weights) × 1_000_000

    Strategy->>Splits: updateSplit(splitsContract, recipients, allocations, 0)
    Strategy-->>IE: encoded result
    IE-->>Evaluators: evaluation result
```

{%preview https://github.com/tnkshuuhei/HatsEligibilityModules %}

{%preview https://app.splits.org/accounts/0xd982477216daDD4C258094B071b49D17b6271d66/?chainId=1 %}

{%preview https://protocol-guild.readthedocs.io/en/latest/01-membership.html#time-weight %}

{%preview https://docs.hatsprotocol.xyz/for-developers/hats-modules %}
