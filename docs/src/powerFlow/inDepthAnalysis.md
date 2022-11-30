# [In-depth Power Flow Analysis](@id inDepthPowerFlowAnalysis)

After the bus voltages are determined, it is possible to determine other electrical quantities. In the rest of this part, we define electrical quantities evaluated by JuliaGrid.

---

## AC Power Flow Analysis
The AC power flow analysis implies the calculation of powers related to buses, powers and currents related to branches, and powers related to generators. To perform the AC power flow analysis JuliaGrid provides the following sequence of functions:
```julia-repl
system = powerSystem("case14.h5")
acModel!(system)

result = newtonRaphson(system)
stopping = result.algorithm.iteration.stopping
for i = 1:10
    newtonRaphson!(system, result)
    if stopping.active < 1e-8 && stopping.reactive < 1e-8
        break
    end
end

bus!(system, result)
branch!(system, result)
generator!(system, result)
```

---

### Bus
The active and reactive powers injection into the bus ``i \in \mathcal{N}`` can be obtained using the expression for the complex apparent power:
```math
    {S}_{i} =\bar{V}_{i}\bar{I}_{i}^* = \bar{V}_{i} \sum\limits_{j \in \mathcal{H}_i} {Y}_{ij}^* \bar{V}_{j}^*; \;\;\;
    P_i = \Re{\{S}_{i}\}; \;\;\;
    Q_i = \Im{\{S}_{i}\}.
```
```julia-repl
julia> result.bus.injection.active
julia> result.bus.injection.reactive
```

The active power of the generators that supply the bus ``i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}}`` is equal to the given active power of the generators in the input data, except for the slack bus, which is determined as:
```math
    P_{\text{g}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}},
```
where ``{P}_{\text{d}i}`` represents the active power demanded by consumers at the slack bus.
```julia-repl
julia> result.bus.supply.active
```

The reactive power of the generators that supply the bus ``i \in \mathcal{N}_{\text{pv}} \cup \mathcal{N}_{\text{sb}}`` is equal to the given reactive power of the generators in the input data, except for PQ buses, which are determined as:
```math
    Q_{\text{g}i} = Q_i + Q_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{pq}},
```
where ``{Q}_{\text{d}i}`` represents the reactive power demanded by consumers at the corresponding PQ bus.
```julia-repl
julia> result.bus.supply.reactive
```

The active and reactive powers related to the shunt element at the bus ``i \in \mathcal{N}`` are obtained using the complex apparent power:
```math
  {S}_{\text{sh}i} =\bar{V}_{i}\bar{I}_{\text{sh}i}^* = {y}_{\text{sh}i}^*|\bar{V}_{i}|^2; \;\;\;
  {P}_{\text{sh}i} = \Re{\{S}_{\text{sh}i}\}; \;\;\;
  {Q}_{\text{sh}i} = \Im{\{S}_{\text{sh}i}\}.
```
```julia-repl
julia> result.bus.shunt.active
julia> result.bus.shunt.reactive
```

---

### Branch
The complex current at the bus "from" ``i \in \mathcal{N}`` of the the branch ``(i,j) \in \mathcal{E}`` can be obtained using the [unified branch model](@ref ACBranchModel):
```math
    \bar{I}_{ij} = \cfrac{1}{\tau_{ij}^2}({y}_{ij} + y_{\text{s}ij}) \bar{V}_{i} - \alpha_{ij}^*{y}_{ij} \bar{V}_{j}
```
JuliaGrid stores the values of these currents in the polar coordinate system.
```julia-repl
julia> result.branch.current.fromBus.magnitude
julia> result.branch.current.fromBus.angle
```
Similarly, the complex current at the bus "to" ``j \in \mathcal{N}`` of the branch ``(i,j) \in \mathcal{E}``
```math
    \bar{I}_{ji} = -\alpha_{ij}{y}_{ij} \bar{V}_{i} + ({y}_{ij} + y_{\text{s}ij}) \bar{V}_{j}.
```
```julia-repl
julia> result.branch.current.toBus.magnitude
julia> result.branch.current.toBus.angle
```
The complex current flowing through the series impedance of the branch in the direction from bus ``i \in \mathcal{N}`` to bus ``j \in \mathcal{N}`` is determined as:
```math
    \bar{I}_{\text{b}ij} =  y_{ij} (\alpha_{ij}\bar{V}_{i} - \bar{V}_{j}).
```
```julia-repl
julia> result.branch.current.impedance.magnitude
julia> result.branch.current.impedance.angle
```

The active and reactive powers at the bus "from" ``i \in \mathcal{N}`` of the branch ``(i,j) \in \mathcal{E}`` are obtained as:
```math
    {S}_{ij} &= \bar{V}_{i}\bar{I}_{ij}^*
```
```julia-repl
julia> result.branch.power.fromBus.active
julia> result.branch.power.fromBus.reactive
```
The active and reactive powers at the bus "to" ``j \in \mathcal{N}`` of the branch ``(i,j) \in \mathcal{E}`` are obtained as:
```math
    {S}_{ji} &= \bar{V}_{j}\bar{I}_{ji}^*
```
```julia-repl
julia> result.branch.power.toBus.active
julia> result.branch.power.toBus.reactive
```

Active and reactive power losses at the branch ``(i,j) \in \mathcal{E}`` arise due to the existence of the series impedance ``z_{ij}``, and can be defined as:
```math
  P_{\text{loss}ij} = r_{ij}|\bar{I}_{\text{b}ij}|^2; \;\;\;
  Q_{\text{loss}ij} = x_{ij}|\bar{I}_{\text{b}ij}|^2.
```
```julia-repl
julia> result.branch.loss.active
julia> result.branch.loss.reactive
```

Total reactive power injected by the branch ``(i,j) \in \mathcal{E}`` due to the existence of capacitive susceptances is obtained as:
```math
    Q_{\text{ch}ij} = b_{\text{s}i} (|\alpha_{ij}\bar{V}_{i}|^2 - |\bar{V}_{j}|^2).
```
```julia-repl
julia> result.branch.shunt.reactive
```

---

### Generator

