# [Observability Analysis](@id ACObservabilityAnalysisTutorials)
The state estimation algorithm aims to estimate the values of the state variables based on the measurement model described as a system of equations. Prior to applying the state estimation algorithm, the observability analysis determines the existence and uniqueness of the solution for the underlying system of equations.

Typical observability analysis, in cases where a unique solution is not guaranteed, identifies observable islands and prescribes an additional set of equations (pseudo-measurements) to ensure a unique solution [cosovic2021observability](@cite). In addition, optimal PMU placement can also be considered from an observability perspective, determining the placement of PMUs to achieve system observability using only phasor measurements.

To initiate the process, let us construct the `PowerSystem` type:
```@example ACObservability
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide
@config(label = Integer)

system = powerSystem()

addBus!(system; label = 1, type = 3)
addBus!(system; label = 2)
addBus!(system; label = 3)
addBus!(system; label = 4)
addBus!(system; label = 5)

addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.05)
addBranch!(system; label = 2, from = 2, to = 3, reactance = 0.01)
addBranch!(system; label = 3, from = 2, to = 4, reactance = 0.02)
addBranch!(system; label = 4, from = 3, to = 4, reactance = 0.03)
addBranch!(system; label = 5, from = 4, to = 5, reactance = 0.05)
nothing # hide
```

To review, we can conceptualize the bus/branch model as the graph denoted by ``\mathcal G = (\mathcal N, \mathcal E)``, where we have the set of buses ``\mathcal N = \{1, \dots, n\}``, and the set of branches ``\mathcal E \subseteq \mathcal N \times \mathcal N`` within the power system:
```@repl ACObservability
𝒩 = collect(keys(system.bus.label))
ℰ = hcat([𝒩[system.branch.layout.from] 𝒩[system.branch.layout.to]])
```

---

## Identification of Observable Islands
JuliaGrid employs standard observability analysis performed on the linear decoupled measurement model [monticellibook; Ch. 7](@cite). Active power measurements from wattmeters are utilized to estimate bus voltage angles, while reactive power measurements from varmeters are used to estimate bus voltage magnitudes. This necessitates that measurements of active and reactive power come in pairs.

Let us illustrate this concept with the following example, where measurements form an unobservable system:
```@example ACObservability
monitoring = measurement(system)

addWattmeter!(monitoring; label = 1, from = 1, active = 0.93)
addVarmeter!(monitoring; label = 1, from = 1, reactive = -0.41)

addWattmeter!(monitoring; label = 2, bus = 2, active = -0.1)
addVarmeter!(monitoring; label = 2, bus = 2, reactive = -0.01)

addWattmeter!(monitoring; label = 3, bus = 3, active = -0.30)
addVarmeter!(monitoring; label = 3, bus = 3, reactive = 0.52)
nothing # hide
```

If the system lacks observability, the observability analysis needs to identify all potential observable islands that can be independently solved. An observable island is defined as follows: It is a segment of the power system where the flows across all branches within that island can be calculated solely from the available measurements. This independence holds regardless of the values chosen for the bus voltage angle at the slack bus [monticellibook; Sec. 7.1.1](@cite). Within this context, two types of observable islands are evident:
* flow-observale islands,
* maximal-observable islands.

The selection between them relies on the power system's structure and the available measurements. Opting for detecting only flow observable islands simplifies the island detection function's complexity but increases the complexity in the restoration function compared to identifying maximal-observable islands.

---

##### Flow-Observale Islands
To identify flow-observable islands, JuliaGrid employs a topological method outlined in [horisberger1985observability](@cite). The process begins with the examination of all active power flow measurements from wattmeters, aiming to determine the largest sets of connected buses within the network linked by branches with active power flow measurements. Subsequently, the analysis considers individual boundary or tie active power injection measurements, involving two islands that may potentially be merged into a single observable island. The user can initiate this process by calling the function:
```@example ACObservability
islands = islandTopologicalFlow(monitoring)
nothing # hide
```

As a result, four flow-observable islands are identified. The first island includes buses `1` and `2`, while the second, third, and fourth islands consist of buses `3`, `4`, and `5`, respectively:
```@repl ACObservability
islands.island
```

Additionally, users can inspect the tie buses and branches resulting from the observability analysis we conducted:
```@repl ACObservability
islands.tie.bus
islands.tie.branch
```
This tie data will be utilized throughout the restoration step, where we introduce pseudo-measurements to merge the observable flow islands obtained.

---

##### Maximal-Observale Islands
To identify maximal-observable islands, we extend the analysis with an additional processing step. After processing individual injection tie measurements, we are left with a series of injection measurements that are not entirely contained within any observable zone. In this set of remaining tie injections, we now examine pairs involving three and only three previously determined observable zones (including individual buses). If we find such a pair, the three islands will be merged, and all injection measurements related exclusively to these three islands are no longer considered. The procedure then restarts at the stage where we process tie active power injection measurements involving two and only two islands. If no mergers are possible with pairs, we then consider sets of three injection measurements involving four islands, and so on [horisberger1985observability](@cite). The user can initiate this by calling the function:
```@example ACObservability
islands = islandTopological(monitoring)
nothing # hide
```

The outcome reveals the identification of two maximal-observable islands:
```@repl ACObservability
islands.island
```
Comparing this result with the flow-observable islands clearly shows that the injection measurements at buses `2` and `3` merge the first, second, and third flow-observable islands into a single island.

Here we can observe tie data:
```@repl ACObservability
islands.tie.bus
islands.tie.branch
```
Compared to the tie data obtained after detecting flow-observable islands, we now have a smaller set, indicating that the restoration step will be more computationally efficient.

---

## Observability Restoration
Before commencing the restoration of observability in the context of the linear decoupled measurement model and observability analysis, it is imperative to ensure that the system possesses one bus voltage magnitude measurement. This necessity arises from the fact that observable islands are identified based on wattmeters, where wattmeters are tasked with estimating voltage angles. Since one voltage angle is already known from the slack bus, the same principle should be applied to bus voltage magnitudes. Therefore, to address this requirement, we add:
```@example ACObservability
addVoltmeter!(monitoring; bus = 1, magnitude = 1.0)
nothing # hide
```

After determining the islands, the observability analysis merges these islands in a manner that protect previously determined observable states from being altered by the new set of equations defined by the additional measurements, called pseudo-measurements. In general, this can be achieved by ensuring that the set of new measurements forms a non-redundant set [monticellibook; Sec. 7.3.2](@cite), i.e., the set of equations must be linearly independent with respect to the global system. The goal of observability restoration is to find this non-redundant set.

The outcome of the island detection step results in the power system being divided into ``m`` islands. Subsequently, we focus on the set of measurements ``\mathcal M_\mathrm{r} \subset \mathcal M``, which exclusively consists of:
* active power injection measurements at tie buses,
* bus voltage phasor measurements.
These measurements are retained from the phase where we identify observable islands, and are crucial in determining whether we need additional pseudo-measurements to be included in the measurement set ``\mathcal M``. In this specific example, we do not have active power injection measurements at tie buses remaining after the identification of maximal-observable islands. However, if we proceed with flow-observable islands to the restoration step, we will have two injection measurements at buses `2` and `3`.

However, let us introduce the matrix ``\mathbf M_\mathrm{r} \in \mathbb{R}^{r \times m}``, where ``r = |\mathcal M_\mathrm{r}|``. This matrix can be conceptualized as the coefficient matrix of a reduced network, with ``m`` columns corresponding to islands and ``r`` rows associated with the set ``\mathcal M_\mathrm{r}``. More precisely, if we construct the coefficient matrix ``\mathbf H_\mathrm{r}`` linked to the set ``\mathcal M_\mathrm{r}`` in the DC framework, the matrix ``\mathbf M_\mathrm{r}`` can be constructed by summing the columns of ``\mathbf H_\mathrm{r}`` that belong to a specific island [manousakis2010observability](@cite).

Subsequently, the user needs to establish a set of pseudo-measurements, where measurements must come in pairs as well. Let us create that set:
```@example ACObservability
pseudo = measurement(system)

addWattmeter!(pseudo; label = 4, bus = 1, active = 0.93)
addVarmeter!(pseudo; label = 4, bus = 1, reactive = -0.41)

addWattmeter!(pseudo; label = 5, from = 5, active = 0.30)
addVarmeter!(pseudo; label = 5, from = 5, reactive = 0.03)
nothing # hide
```

From this set, the restoration step will only utilize the following:
* active power flow measurements between tie buses,
* active power injection measurements at tie buses,
* bus voltage phasor measurements.

These pseudo-measurements ``\mathcal M_\mathrm{p}`` will define the reduced coefficient matrix ``\mathbf M_\mathrm{p} \in \mathbb{R}^{p \times m}``, where ``p = |\mathcal M_\mathrm{p}|``. In this example, only the fifth wattmeter will contribute to the construction of the matrix ``\mathbf M_\mathrm{p}``. Similar to the previous case, measurement functions linked to the set ``\mathcal M_\mathrm{p}`` define the coefficient matrix ``\mathbf H_\mathrm{p}``, and the matrix ``\mathbf M_\mathrm{p}`` can be viewed as the sum of the columns of ``\mathbf H_\mathrm{p}`` belonging to a specific observable island.

Additionally, users have the option to include bus voltage angle measurements from PMUs. In this scenario, restoration can be conducted without merging observable islands into one island, as each island becomes globally observable when one angle is known. It is important to note that during the restoration step, JuliaGrid initially processes active power measurements and subsequently handles bus voltage angle measurements if they are present in the set of pseudo-measurements.

Users can execute the observability restoration procedure with the following:
```@example ACObservability
restorationGram!(monitoring, pseudo, islands; threshold = 1e-6)
nothing # hide
```

The function constructs the reduced coefficient matrix as follows:
```math
  \mathbf M = \begin{bmatrix} \mathbf M_{\text{r}} \\ \mathbf M_{\text{p}} \end{bmatrix},
```
and forms the corresponding Gram matrix:
```math
  \mathbf D = \mathbf M \mathbf M^T.
```

The decomposition of ``\mathbf D`` into its ``\mathbf Q`` and ``\mathbf R`` factors is achieved through QR factorization. Non-redundant measurements are identified by non-zero diagonal elements in ``\mathbf R``. Specifically, if the diagonal element satisfies:
```math
    |R_{ii}| < \epsilon,
```
JuliaGrid designates the corresponding measurement as redundant, where ``\epsilon`` represents a pre-determined zero pivot `threshold`, set to `1e-6` in this example. The minimal set of pseudo-measurements for observability restoration corresponds to the non-zero diagonal elements at positions associated with the candidate pseudo-measurements. It is essential to note that an inappropriate choice of the zero pivot threshold may adversely affect observability restoration. Additionally, there is a possibility that the set of pseudo-measurements ``\mathcal{M}_\text{p}`` may not be sufficient for achieving observability restoration.

Finally, the fifth wattmeter, and consequently the fifth varmeter successfully restore observability, and these measurements are added to the `monitoring` variable, which stores actual measurements:
```@repl ACObservability
monitoring.wattmeter.label
monitoring.varmeter.label
```

Here, we can confirm that the new measurement set establishes the observable system formed by a single island:
```@repl ACObservability
islands = islandTopological(monitoring);

islands.island
```

---

## [Optimal PMU Placement](@id optimalpmu)
JuliaGrid implements the optimal PMU placement algorithms proposed in [gou2008optimal, gou2008generalized](@cite). Users can determine the optimal placement in two cases:
* without legacy measurements,
* with legacy measurements.

Here, legacy measurements refer only to power flow and injection data. When legacy measurements are included in the formulation, it is assumed that active and reactive power measurements always appear as pairs. The optimal PMU placement is then determined using only the active power measurements.

---

##### Optimal Solution Without Legacy Measurements
The optimal placement of PMUs without legacy measurements is formulated as an integer linear programming problem:
```math
  \begin{aligned}
    \text{minimize}& \;\;\; \sum_{i=1}^n d_i\\
    \text{subject\;to}& \;\;\; \sum_{j=1}^n a_{ij}d_j \geq 1, \;\; \forall i \in \mathcal{N},
  \end{aligned}
```
where ``d_i \in \mathbb{F} = \{0,1\}`` is the PMU placement decision variable associated with bus ``i \in \mathcal{N}``. The binary parameter ``a_{ij} \in \mathbb{F}`` indicates the connectivity of the power system network, where ``a_{ij}`` can be directly derived from the nodal admittance matrix by converting its entries into binary form [xu2004observability](@cite). This linear programming problem is implemented using JuMP package allowing compatibility with different type of optimization solvers.

Consequently, we obtain the binary vector ``\mathbf d = [d_1,\dots,d_n]^T``, where ``d_i = 1``, ``i \in \mathcal{N}``, suggests that a PMU should be placed at bus ``i``. The primary aim of PMU placement in the power system is to determine a minimal set of PMUs such that the entire system is observable without relying on legacy measurements [gou2008optimal](@cite). Specifically, when we observe ``d_i = 1``, it indicates that the PMU is installed at bus ``i \in \mathcal{N}`` to measure bus voltage phasor as well as all current phasors across branches incident to bus ``i``.

Now, we will determine the optimal PMU placement for our power system:
```@example ACObservability
using HiGHS
@default(unit) # hide

placement = pmuPlacement(monitoring, HiGHS.Optimizer)
nothing # hide
```

The `placement` variable contains data regarding the optimal placement of measurements. It lists all buses ``i \in \mathcal{N}`` that satisfy ``d_i = 1``:
```@repl ACObservability
keys(placement.bus)
```

The PMUs installed at buses `2` and `4` will measure the voltage phasors at these buses, along with all current phasors on the branches connected to them. These measurements are stored in the following variables:
```@repl ACObservability
keys(placement.from)
keys(placement.to)
```
Consequently, the PMUs will measure the current phasors at the from-bus ends of branches `2`, `3`, and `5`, as well as the current phasors at the to-bus ends of branches `1`, `3`, and `4`.

---

##### Optimal Solution With Legacy Measurements
Beyond this scenario, JuliaGrid also includes an algorithm for identifying the minimal set of PMUs while considering legacy measurements, where legacy measurements refer to power flow and injection data only. In this case, the optimal PMU placement can be obtained by solving:
```math
  \begin{aligned}
    \text{minimize}& \;\;\; \sum_{i=1}^n d_i\\
    \text{subject\;to}& \;\;\; \sum_{j=1}^n c_{ij} \left ( \sum_{k=1}^n a_{ik}d_k \right) \geq b_i, \;\; \forall i \in \mathcal{H}.
  \end{aligned}
```
The binary coefficient ``c_{ij} \in \mathbb{F} = \{0,1\}`` indicates the incidence of buses ``\{i,j\} \subset \mathcal{N}`` according to the presence or absence of measurements at the bus, and the right-hand side coefficient ``b_i`` depends on the number of nonzero terms ``c_{ij}``. Each inequality corresponds to a bus ``i \in \mathcal{H}``, where ``\mathcal{H}`` is the set of buses associated with a power flow measurement, an injection measurement, or no measurement.

More precisely, three cases are distinguished. If a power flow measurement is installed at the ``i`` end of branch ``(i,j)``, then ``c_{ii} = c_{ij} = 1`` and ``b_i = 1``. The second case occurs when a power injection measurement is located at bus ``i``, which is incident to buses ``\mathcal{N}_i``. In this case, ``c_{ii} = c_{ik} = 1`` for ``k \in \mathcal{N}_i`` and ``b_i = |\mathcal{N}_i|``. Finally, if bus ``i`` is not incident to any measurement, then ``c_{ii} = 1`` and ``b_i = 1``. All other binary coefficients not explicitly specified are equal to zero.

As in the case of optimal placement without legacy measurements, we obtain the binary vector ``\mathbf{d}``, where ``d_i = 1, i \in \mathcal{N}`` indicates that a PMU should be installed at bus ``i``.

Now, we can determine the optimal PMU placement while taking legacy measurements into account:
```@example ACObservability
using HiGHS
@default(unit) # hide

placement = pmuPlacement(monitoring, HiGHS.Optimizer; legacy = true)
nothing # hide
```

Thus, we obtain:
```@repl ACObservability
keys(placement.bus)
keys(placement.from)
keys(placement.to)
```
As we can see, when determining the PMU placement to make the system observable while also taking legacy measurements into account, it is sufficient to install a PMU at bus `4`. This PMU will measure the voltage magnitude and angle at bus `4` as well as the current magnitudes and angles at the corresponding branches.