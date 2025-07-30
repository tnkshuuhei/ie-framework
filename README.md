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
1.0 & \text{if full-time (≥40 hr/wk)} \\
0.5 & \text{if part-time (20-40 hr/wk)}
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

- admin create pool on IE contract
- then initialize pool with config

  - use splits module as reward function
  - use time control module as an measurement function
  - use below fomula as an evaluation function

  > Each member’s share of the split contract is calculated using member-specific inputs. There are two parts to the calculation:
  > Calculate each member’s time*weight: time_weight = SQRT((start_date - months_inactive) * full*or_part_time)
  > Normalize time_weight as a percentage: split_share = (time_weight / total_time_weights) * 100
  > This formulation recognizes the local knowledge contributors gain over time, and uses that as a proxy for “value to the commons” and to allocate funding to members. Existing contributor weights get “diluted” as newcomers show up. Continuing contributors get additional weight per month they are active.
  > Each member’s time-weight is updated onchain every quarter along with an Ethereum address they control to allocate the funding flowing through the mechanism.

- once pool is initialized, admin will update evaluation(this will change the share of each recipients on splits contract)

```mermaid
sequenceDiagram

actor admin as Admin
participant ie as IE Contract
participant splits as Splits Contract
participant eval as Evaluation Contract
participant time as Time Control Module

actor alice as Alice
actor bob as Bob
actor charlie as Charlie
```
