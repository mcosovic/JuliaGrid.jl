# [Power and Current Analysis](@id PowerCurrentAnalysisTutorials)

After the computation of voltage magnitudes and angles at each bus, various electrical quantities can be determined. JuliaGrid offers the [`bus!`](@ref bus!), [`branch!`](@ref branch!), and [`generator!`](@ref generator!) functions for calculating powers and currents associated with buses, branches, and generators. To illustrate, let us create the power system and obtain the bus voltages using the AC power flow framework:
```@example ComputePowersCurrents
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

@power(MW, MVAr, MVA)

system = powerSystem()

addBus!(system; label = 1, type = 3)
addBus!(system; label = 2, type = 1, active = 21.7, reactive = 12.7)
addBus!(system; label = 3, type = 2, conductance = 2.1, susceptance = 1.2)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.02, reactance = 0.06)
addBranch!(system; label = 2, from = 1, to = 3, resistance = 0.05, reactance = 0.21)
addBranch!(system; label = 3, from = 2, to = 3, reactance = 0.26, susceptance = 0.1)

addGenerator!(system; label = 1, bus = 1, active = 20.0, reactive = 22.4)
addGenerator!(system; label = 2, bus = 1, active = 10.0, reactive = 12.4)
addGenerator!(system; label = 3, bus = 3, active = 5.1, reactive = 2.1)

acModel!(system)

result = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, result)
    if all(stopping .< 1e-8)
        break
    end
    solvePowerFlow!(system, result)
end

nothing #hide
```

This section uses the vector notation ``\mathbf{a}`` to represent a vector, which can be denoted as either ``\mathbf{a} = [a_{i}]`` or ``\mathbf{a} = [a_{ij}]``. Here, ``a_{i}`` represents an element associated with the bus ``i \in \mathcal{N}``, and ``a_{ij}`` represents an element related to the branch ``(i,j) \in \mathcal{E}``. To obtain the sets of buses ``\mathcal{N}`` and branches ``\mathcal{E}``, the following commands can be used:
```@repl ComputePowersCurrents
𝒩 = collect(keys(sort(system.bus.label)))
ℰ = [system.branch.layout.from system.branch.layout.to]
```

For each bus in the set ``i \in \mathcal{N}``, the AC power flow solution provides vectors of bus voltage magnitudes ``\mathbf{V} = [V_i]`` and angles ``\bm{\theta} = [\theta_i]``:
```@repl ComputePowersCurrents
𝐕 = result.bus.voltage.magnitude
𝛉 = result.bus.voltage.angle
```

---

## [Bus Powers and Currents](@id BusPowersCurrentsTutorials)
JuliaGrid provides the [`bus!`](@ref bus!) function to compute powers and currents linked to buses, which populates the `bus` field of the `Result` type. Here is an example code snippet:
```@example ComputePowersCurrents
bus!(system, result)
nothing # hide
```

This function computes various electrical quantities, and the computed currents are stored in the polar coordinate system, while the powers are stored in the rectangular coordinate system:
* current injections: ``\mathbf{I} = [I_i]``, ``\bm{\psi} = [\psi_i]``
* power injections: ``\mathbf{P} = [P_i]``, ``\mathbf{Q} = [Q_i]``
* power injected by the generators:  ``\mathbf{P}_{\text{s}} = [P_{\text{s}i}]``, ``\mathbf{Q}_{\text{s}} = [Q_{\text{s}i}]``
* power associated with shunt elements: ``\mathbf{P}_{\text{sh}} = [{P}_{\text{sh}i}]``, ``\mathbf{Q}_{\text{sh}} = [{Q}_{\text{sh}i}]``.

---

##### Current Injections
To obtain the complex current injection at the specific bus, we use the following equation:
```math
    \bar{I}_{i} = I_i \text{e}^{\text{j}\psi_i} = \sum\limits_{j = 1}^n {Y}_{ij} \bar{V}_{j},\;\;\; i \in \mathcal{N}.
```
In JuliaGrid, these complex current injections are stored in a vector of magnitudes denoted as ``\mathbf{I} = [I_i]`` and a vector of angles represented as ``\bm{\psi} = [\psi_i]``. You can retrieve them using the following commands:
```@repl ComputePowersCurrents
𝐈 = result.bus.current.injection.magnitude
𝛙 = result.bus.current.injection.angle
```

---

##### Power Injections
The computation of active and reactive power injections at the bus is expressed by the following equation:
```math
    {S}_{i} = P_i + \text{j}Q_i = \bar{V}_{i}\bar{I}_{i}^*,\;\;\; i \in \mathcal{N}.
```
Active and reactive power injections are stored as the vectors ``\mathbf{P} = [P_i]`` and ``\mathbf{Q} = [Q_i]``, respectively, and can be retrieved using the following commands:
```@repl ComputePowersCurrents
𝐏 = result.bus.power.injection.active
𝐐 = result.bus.power.injection.reactive
```

----

##### Power Injected by the Generators
The [`bus!`](@ref bus!) function in JuliaGrid also computes the active and reactive powers that generators inject to the buses. The active power supplied by the generators to the buses can be calculated by summing the given generator active powers in the input data, except for the slack bus, which can be determined as:
```math
    P_{\text{s}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}},
```
where ``P_{\text{d}i}`` represents the active power demanded by consumers at the slack bus. The vector of active power injected by generators to the buses, denoted by ``\mathbf{P}_{\text{s}} = [P_{\text{s}i}]``, can be obtained using the following command:
```@repl ComputePowersCurrents
𝐏ₛ = result.bus.power.supply.active
```

Similarly, the reactive power injected by the generators to the buses can be obtained using the following equation:
```math
    Q_{\text{s}i} = Q_i + Q_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{pv}} \cup \mathcal{N}_{\text{sb}},
```
where ``Q_{\text{d}i}`` represents the reactive power demanded by consumers at the corresponding bus. Further, the reactive power injected by the generators at buses from ``\mathcal{N}_{\text{pq}}`` can be calculated by summing the given generator reactive powers in the input data. The vector of these reactive power injections by the generators to the buses, denoted by ``\mathbf{Q}_{\text{s}} = [Q_{\text{s}i}]``, can be retrieved using the following command:
```@repl ComputePowersCurrents
𝐐ₛ = result.bus.power.supply.reactive
```

---

##### Power Associated with Shunt Elements
To obtain the active and reactive powers associated with the shunt element at each bus, you can use the following equation:
```math
  {S}_{\text{sh}i} = {P}_{\text{sh}i} + \text{j}{Q}_{\text{sh}i} = \bar{V}_{i}\bar{I}_{\text{sh}i}^* = {y}_{\text{sh}i}^*|\bar{V}_{i}|^2,\;\;\; i \in \mathcal{N}.
```
The active power demanded by the shunt element at each bus is represented by the vector ``\mathbf{P}_{\text{sh}} = [{P}_{\text{sh}i}]``, while the reactive power injected or demanded by the shunt element at each bus is represented by the vector ``\mathbf{Q}_{\text{sh}} = [{Q}_{\text{sh}i}]``. To retrieve these powers in JuliaGrid, use the following commands:
```@repl ComputePowersCurrents
𝐏ₛₕ = result.bus.power.shunt.active
𝐐ₛₕ = result.bus.power.shunt.reactive
```

---

## [Branch Powers and Currents](@id BranchPowersCurrentsTutorials)
JuliaGrid provides the [`branch!`](@ref branch!) function to compute powers and currents linked to branches, which populates the `branch` field of the `Result` type. Here is an example code snippet:
```@example ComputePowersCurrents
branch!(system, result)
nothing # hide
```

The function stores the currents in the polar coordinate system and the powers in the rectangular coordinate system. It calculates the following quantities:
* current flow at from bus ends: ``\mathbf{I}_{\text{i}} = [I_{ij}]``, ``\bm{\psi}_{\text{i}} = [\psi_{ij}]``
* current flow at to bus ends: ``\mathbf{I}_{\text{j}} = [I_{ji}]``, ``\bm{\psi}_{\text{j}} = [\psi_{ji}]``
* current flow through series impedances: ``\mathbf{I}_{\text{s}} = [I_{\text{s}ij}]``, ``\bm{\psi}_{\text{s}} = [\psi_{\text{s}ij}]``
* power flow at from bus ends: ``\mathbf{P}_{\text{i}} = [P_{ij}]``, ``\mathbf{Q}_{\text{i}} = [Q_{ij}]``
* power flow at to bus ends: ``\mathbf{P}_{\text{j}} = [P_{ji}]``, ``\mathbf{Q}_{\text{j}} = [Q_{ji}]``
* power losses: ``\mathbf{P}_{\text{l}} = [P_{\text{l}ij}]``, ``\mathbf{Q}_{\text{l}} = [Q_{\text{l}ij}]``
* reactive power injections: ``\mathbf{Q}_{\text{r}} = [ Q_{\text{r}ij}]``.

---

##### Current Flow at From Bus Ends
To calculate the complex current flow at from bus end ``i \in \mathcal{N}``, the [unified branch model](@ref UnifiedBranchModelTutorials) can be utilized:
```math
    \bar{I}_{ij} = I_{ij} \text{e}^{\text{j}\psi_{ij}} = \cfrac{1}{\tau_{ij}^2}({y}_{ij} + y_{\text{s}ij}) \bar{V}_{i} - \alpha_{ij}^*{y}_{ij} \bar{V}_{j},\;\;\; (i,j) \in \mathcal{E}.
```
To obtain the vectors of magnitudes ``\mathbf{I}_{\text{i}} = [I_{ij}]`` and angles ``\bm{\psi}_{\text{i}} = [\psi_{ij}]`` for the resulting complex current flows at the from bus end, you can use the following commands:
```@repl ComputePowersCurrents
𝐈ᵢ = result.branch.current.from.magnitude
𝛙ᵢ = result.branch.current.from.angle
```

---

##### Current Flow at To Bus Ends
Similarly, we can obtain the complex current flow at the to bus end ``j \in \mathcal{N}`` using the unified branch model, given by:
```math
    \bar{I}_{ji} = I_{ji} \text{e}^{\text{j}\psi_{ji}} = -\alpha_{ij}{y}_{ij} \bar{V}_{i} + ({y}_{ij} + y_{\text{s}ij}) \bar{V}_{j},\;\;\; (i,j) \in \mathcal{E}.
```
We can obtain the vectors of magnitudes ``\mathbf{I}_{\text{j}} = [I_{ji}]`` and angles ``\bm{\psi}_{\text{j}} = [\psi_{ji}]`` of the resulting complex current flows at the to bus end using the following code:
```@repl ComputePowersCurrents
𝐈ⱼ = result.branch.current.to.magnitude
𝛙ⱼ = result.branch.current.to.angle
```

---

##### Current Flow Through Series Impedances
To obtain the complex current flow through the series impedance of a branch in the direction from bus ``i \in \mathcal{N}`` to bus ``j \in \mathcal{N}``, one can use the expression:
```math
    \bar{I}_{\text{s}ij} = I_{\text{s}ij} \text{e}^{\psi_{\text{s}ij}} =  y_{ij} (\alpha_{ij}\bar{V}_{i} - \bar{V}_{j}),,\;\;\; (i,j) \in \mathcal{E}.
```
To obtain the vectors of magnitudes ``\mathbf{I}_{\text{s}} = [I_{\text{s}ij}]`` and angles ``\bm{\psi}_{\text{s}} = [\psi_{\text{s}ij}]`` of the resulting complex current flow through the series impedance, one can use the following code:
```@repl ComputePowersCurrents
𝐈ₛ = result.branch.current.impedance.magnitude
𝛙ₛ = result.branch.current.impedance.angle
```

---

##### Power Flow at From Bus Ends
The active and reactive power flows at from bus end ``i \in \mathcal{N}`` can be obtained using the following equations based on the [unified branch model](@ref UnifiedBranchModelTutorials):
```math
    S_{ij} = P_{ij} + \text{j}Q_{ij} = \bar{V}_{i}\bar{I}_{ij}^*,\;\;\; (i,j) \in \mathcal{E}.
```
The resulting active and reactive power flows at from bus end are stored as the vectors ``\mathbf{P}_{\text{i}} = [P_{ij}]`` and ``\mathbf{Q}_{\text{i}} = [Q_{ij}]``, respectively, and can be retrieved using the following commands:
```@repl ComputePowersCurrents
𝐏ᵢ = result.branch.power.from.active
𝐐ᵢ = result.branch.power.from.reactive
```

---

##### Power Flow at To Bus Ends
Similarly, we can determine the active and reactive power flows at the to bus end `j \in \mathcal{N}` using the equations:
```math
    {S}_{ji} = P_{ji} + \text{j}Q_{ji} = \bar{V}_{j}\bar{I}_{ji}^*,\;\;\; (i,j) \in \mathcal{E}.
```
The vectors of active and reactive power flows at the to bus end are stored as ``\mathbf{P}_{\text{j}} = [P_{ji}]`` and ``\mathbf{Q}_{\text{j}} = [Q_{ji}]``, respectively, and can be retrieved using the following code:
```@repl ComputePowersCurrents
𝐏ⱼ = result.branch.power.to.active
𝐐ⱼ = result.branch.power.to.reactive
```

---

##### Power Losses
The active and reactive power losses in the branch are caused by its series impedance ``z_{ij}``. These losses can be obtained using the following equations:
```math
    \begin{aligned}
        P_{\text{l}ij} &= r_{ij}|\bar{I}_{\text{b}ij}|^2 \\
        Q_{\text{l}ij} &= x_{ij}|\bar{I}_{\text{b}ij}|^2,
    \end{aligned}
```
where ``(i,j) \in \mathcal{E}``. We can retrieve the vectors of active and reactive power losses, ``\mathbf{P}_{\text{l}} = [P_{\text{l}ij}]`` and ``\mathbf{Q}_{\text{l}} = [Q_{\text{l}ij}]``, respectively, using the following commands:
```@repl ComputePowersCurrents
𝐏ₗ = result.branch.power.loss.active
𝐐ₗ = result.branch.power.loss.reactive
```

---

##### Reactive Power Injections
The branch's capacitive susceptances cause reactive power injection. We can calculate the total reactive power injected by the branch using the following equation:
```math
    Q_{\text{r}ij} = b_{\text{s}i} (|\alpha_{ij}\bar{V}_{i}|^2 - |\bar{V}_{j}|^2),\;\;\; (i,j) \in \mathcal{E}.
```
To retrieve the vector of injected reactive powers ``\mathbf{Q}_{\text{r}} = [Q_{\text{r}ij}]``, use the following Julia command:
```@repl ComputePowersCurrents
𝐐ᵣ = result.branch.power.shunt.reactive
```

---

## [Generator Powers](@id GeneratorPowersTutorials)
The [`generator!`](@ref generator!) function provided by JuliaGrid can be used to compute powers associated with generators. This function populates the `generator` field of the `Result` type. Here is an example code snippet:
```@example ComputePowersCurrents
generator!(system, result)
nothing # hide
```

The powers are stored in the rectangular coordinate system, and only the output power of the generators is calculated. The output powers are stored in vectors as ``\mathbf{P}_{\text{g}} = [P_{\text{g}i}]`` and ``\mathbf{Q}_{\text{g}} = [Q_{\text{g}i}]``.

To obtain the output active power of generators connected to bus ``i \in \mathcal{N}_{\text{pv}} \cup \mathcal{N}_{\text{pq}}``, the given active power in the input data is utilized. For the generator connected to the slack bus, the output active power is determined using the equation:
```math
    P_{\text{g}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}}.
```
In the case of multiple generators connected to the slack bus, the first generator in the input data is assigned the obtained value of ``P_{\text{g}i}``. Then, this amount of power is reduced by the output active power of the other generators. Therefore, to get the vector of output active power of generators, i.e., ``\mathbf{P}_{\text{g}} = [P_{\text{g}i}]``, you can use the following command:
```@repl ComputePowersCurrents
𝐏ₒ = result.generator.power.active
```

The output reactive power of a generator located at the bus is obtained by adding the reactive power specified in the input data to the reactive power demand at the bus:
```math
    Q_{\text{g}i} = Q_i + Q_{\text{d}i},\;\;\; i \in \mathcal{N}.
```
If there are multiple generators at the same bus, the reactive power is allocated proportionally among the generators based on their reactive power capabilities. To obtain the vector of output reactive power of generators`` \mathbf{Q}_{\text{g}} = [Q_{\text{g}i}]``, the following command can be used:
```@repl ComputePowersCurrents
𝐐ₒ = result.generator.power.reactive
```

---

## [DC Analysis](@id DCAnalysisTutorials)
To compute the powers associated with buses, branches, and generators within the DC framework, the same functions [`bus!`](@ref bus!), [`branch!`](@ref branch!), and [`generator!`](@ref generator!) can be utilized. Once the power system is created, the bus voltages can be obtained using the DC power flow framework as follows:
```@example ComputePowersCurrents
dcModel!(system)
result = solvePowerFlow(system)
nothing #hide
```

To retrieve the bus voltage angles, use the command:
```@repl ComputePowersCurrents
𝛉 = result.bus.voltage.angle
```

---

##### Bus Powers
JuliaGrid's [`bus!`](@ref bus!) function can be used to compute powers associated with buses, which fills the `bus` field of the `Result` type. Here is an example code snippet:
```@example ComputePowersCurrents
bus!(system, result)
nothing # hide
```

To obtain the active power injection at bus ``i \in \mathcal{N}``, we can refer to section [DC Model](@ref DCModelTutorials), which provides the following expression:
```math
   P_i = \sum_{j = 1}^n {B}_{ij} \theta_j + P_{\text{tr}i} + P_{\text{sh}i},\;\;\; i \in \mathcal{N}.
```
Active power injections are stored as the vector ``\mathbf{P} = [P_i]``, and can be retrieved using the following commands:
```@repl ComputePowersCurrents
𝐏 = result.bus.power.injection.active
```

The active power supplied by generators to the buses can be calculated by summing the given generator active powers in the input data, except for the slack bus, which can be determined as:
```math
    P_{\text{s}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}},
```
where ``P_{\text{d}i}`` represents the active power demanded by consumers at the slack bus. The vector of active power injected by generators to the buses, denoted by ``\mathbf{P}_{\text{s}} = [P_{\text{s}i}]``, can be obtained using the following command:
```@repl ComputePowersCurrents
𝐏ₛ = result.bus.power.supply.active
```

---

##### Branch Powers
To compute powers associated with branches, JuliaGrid provides the [`branch!`](@ref branch!) function, which populates the `branch` field of the `Result` type. Here is an example code snippet:
```@example ComputePowersCurrents
branch!(system, result)
nothing # hide
```

The active power flows at from bus end ``i \in \mathcal{N}`` can be obtained using the following equations:
```math
    P_{ij} = \cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} -\theta_{j}-\phi_{ij}),\;\;\; (i,j) \in \mathcal{E}.
```
The resulting active power flows at from bus end are stored as the vector ``\mathbf{P}_{\text{i}} = [P_{ij}]``, which can be retrieved using the following command:
```@repl ComputePowersCurrents
𝐏ᵢ = result.branch.power.from.active
```

Similarly, the active power flows at to bus end ``j \in \mathcal{N}`` can be obtained as:
```math
    P_{ji} = - P_{ij},\;\;\; (i,j) \in \mathcal{E}.
```
The resulting active power flows at to bus end are stored as the vector ``\mathbf{P}_{\text{j}} = [P_{ji}]``, which can be retrieved using the following command:
```@repl ComputePowersCurrents
𝐏ⱼ = result.branch.power.to.active
```

---

##### Generator Powers
To compute powers associated with generators, JuliaGrid provides the [`generator!`](@ref generator!) function, which populates the `generator` field of the `Result` type. Here is an example code snippet:
```@example ComputePowersCurrents
generator!(system, result)
nothing # hide
```

The active power output of a generator located at bus ``i \in \mathcal{N}_{\text{pv}} \cup \mathcal{N}_{\text{pq}}`` is equal to the active power specified in the input data. If there are multiple generators, their active power outputs are also equal to the active power specified in the input data. However, the active power output of a generator located at the slack bus is determined as:
```math
    P_{\text{g}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}}.
```
In the case of multiple generators connected to the slack bus, the first generator in the input data is assigned the obtained value of ``P_{\text{g}i}``. Then, this amount of power is reduced by the output active power of the other generators. Therefore, to get the vector of output active power of generators, i.e., ``\mathbf{P}_{\text{g}} = [P_{\text{g}i}]``, you can use the following command:
```@repl ComputePowersCurrents
𝐏ₒ = result.generator.power.active
```