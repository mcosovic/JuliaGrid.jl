# [In-depth Power Flow Analysis](@id inDepthPowerFlowAnalysis)

After the bus voltages are determined, it is possible to determine other electrical quantities. JuliaGrid stores complex currents in the polar coordinate system, while complex powers are stored in the rectangle coordinate system. In the rest of this part, we define electrical quantities evaluated by JuliaGrid.

---

## AC Power Flow Analysis
The AC power flow analysis implies the calculation of powers and currents related to buses and branches, and powers related to generators. To perform the AC power flow analysis JuliaGrid provides the following sequence of functions:
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
The complex current injection at the bus ``i \in \mathcal{N}`` can be obtained as:
```math
    \bar{I}_{i} = \sum\limits_{j = 1}^n {Y}_{ij} \bar{V}_{j}.
```
```julia-repl
julia> result.bus.current.injection.magnitude
julia> result.bus.current.injection.angle
```

The active and reactive power injections at the bus ``i \in \mathcal{N}`` can be obtained using the expression:
```math
    {S}_{i} =\bar{V}_{i}\bar{I}_{i}^*.
```
```julia-repl
julia> result.bus.power.injection.active
julia> result.bus.power.injection.reactive
```

The active power of the generators that supply the bus ``i \in \mathcal{N}_{\text{pv}}`` is equal to the given active power of the generators in the input data, except for the slack bus, which is determined as:
```math
    P_{\text{g}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}},
```
where ``{P}_{\text{d}i}`` represents the active power demanded by consumers at the slack bus.
```julia-repl
julia> result.bus.power.supply.active
```

The reactive power of the generators that supply the bus is equal to:
```math
    Q_{\text{g}i} = Q_i + Q_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{pv}} \cup \mathcal{N}_{\text{sb}},
```
where ``{Q}_{\text{d}i}`` represents the reactive power demanded by consumers at the corresponding bus.
```julia-repl
julia> result.bus.power.supply.reactive
```

The active and reactive powers related to the shunt element at the bus ``i \in \mathcal{N}`` are obtained using:
```math
  {S}_{\text{sh}i} =\bar{V}_{i}\bar{I}_{\text{sh}i}^* = {y}_{\text{sh}i}^*|\bar{V}_{i}|^2.
```
```julia-repl
julia> result.bus.power.shunt.active
julia> result.bus.power.shunt.reactive
```

---

### Branch
The complex current flow at the bus "from" ``i \in \mathcal{N}`` of the the branch ``(i,j) \in \mathcal{E}`` can be obtained using the [unified branch model](@ref ACBranchModel):
```math
    \bar{I}_{ij} = \cfrac{1}{\tau_{ij}^2}({y}_{ij} + y_{\text{s}ij}) \bar{V}_{i} - \alpha_{ij}^*{y}_{ij} \bar{V}_{j}
```
```julia-repl
julia> result.branch.current.from.magnitude
julia> result.branch.current.from.angle
```
Similarly, the complex current flow at the bus "to" ``j \in \mathcal{N}`` of the branch ``(i,j) \in \mathcal{E}`` is equal to:
```math
    \bar{I}_{ji} = -\alpha_{ij}{y}_{ij} \bar{V}_{i} + ({y}_{ij} + y_{\text{s}ij}) \bar{V}_{j}.
```
```julia-repl
julia> result.branch.current.to.magnitude
julia> result.branch.current.to.angle
```
The complex current flow through the series impedance of the branch ``(i,j) \in \mathcal{E}`` in the direction from bus ``i \in \mathcal{N}`` to bus ``j \in \mathcal{N}`` is determined as:
```math
    \bar{I}_{\text{b}ij} =  y_{ij} (\alpha_{ij}\bar{V}_{i} - \bar{V}_{j}).
```
```julia-repl
julia> result.branch.current.impedance.magnitude
julia> result.branch.current.impedance.angle
```

The active and reactive power flows at the bus "from" ``i \in \mathcal{N}`` of the branch ``(i,j) \in \mathcal{E}`` are obtained as:
```math
    {S}_{ij} = \bar{V}_{i}\bar{I}_{ij}^*
```
```julia-repl
julia> result.branch.power.from.active
julia> result.branch.power.from.reactive
```
The active and reactive power flows at the bus "to" ``j \in \mathcal{N}`` of the branch ``(i,j) \in \mathcal{E}`` are obtained as:
```math
    {S}_{ji} = \bar{V}_{j}\bar{I}_{ji}^*
```
```julia-repl
julia> result.branch.power.to.active
julia> result.branch.power.to.reactive
```

Active and reactive power losses of the branch ``(i,j) \in \mathcal{E}`` arise due to the existence of the series impedance ``z_{ij}``, and can be obtained as:
```math
    \begin{aligned}
        P_{\text{loss}ij} &= r_{ij}|\bar{I}_{\text{b}ij}|^2 \\
        Q_{\text{loss}ij} &= x_{ij}|\bar{I}_{\text{b}ij}|^2.
    \end{aligned}
```
```julia-repl
julia> result.branch.power.loss.active
julia> result.branch.power.loss.reactive
```

Total reactive power injected by the branch ``(i,j) \in \mathcal{E}`` due to the existence of capacitive susceptances is obtained as:
```math
    Q_{\text{ch}ij} = b_{\text{s}i} (|\alpha_{ij}\bar{V}_{i}|^2 - |\bar{V}_{j}|^2).
```
```julia-repl
julia> result.branch.power.shunt.reactive
```

---

### Generator
The output active power of the generator at the bus ``i \in \mathcal{N}_{\text{pv}}`` is equal to the given active power of the generator in the input data. Moreover, if there are several generators at the bus ``i \in \mathcal{N}_{\text{pv}}`` their output active powers are still equal to the active powers given in the input data. The output active power of the generator at the slack bus is determined as:
```math
    P_{\text{g}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}}.
```
When there are several generators at the slack bus, the active power ``P_{\text{g}i}`` will be assigned to the first generator in the list of input data. After that this active power will be reduced by the output active power of the rest of the generators.
```julia-repl
julia> result.generator.power.active
```

The output reactive power of the generator at the bus ``i \in \mathcal{N}_{\text{pv}}`` is equal to:
```math
    Q_{\text{g}i} = Q_i + Q_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{pq}}.
```
In case there are several generators at the bus ``i \in \mathcal{N}_{\text{pv}}`` , the reactive power will be proportionally distributed between the generators based on their capabilities.
```julia-repl
julia> result.generator.power.reactive
```

---

## DC Power Flow Analysis
The DC power flow analysis implies the calculation of active powers related to buses, branches, and generators. To perform the DC power flow analysis JuliaGrid provides the following sequence of functions:
```julia-repl
system = powerSystem("case14.h5")
dcModel!(system)

result = dcPowerFlow(system)

bus!(system, result)
branch!(system, result)
generator!(system, result)
```

---

### Bus
The active power injection at the bus ``i \in \mathcal{N}`` can be obtained using the expression:
```math
   P_i = \sum_{j = 1}^n {B}_{ij} \theta_j + P_{\text{gs}i} + P_{\text{sh}i}.
```
```julia-repl
julia> result.bus.injection.active
```

The active power of the generators that supply the bus ``i \in \mathcal{N}_{\text{pv}}`` is equal to the given active power of the generators in the input data, except for the slack bus, which is determined as:
```math
    P_{\text{g}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}},
```
where ``{P}_{\text{d}i}`` represents the active power demanded by consumers at the slack bus.
```julia-repl
julia> result.bus.power.supply.active
```

---

### Branch
The active power flow at the bus "from" ``i \in \mathcal{N}`` of the branch ``(i,j) \in \mathcal{E}`` is obtained as:
```math
    P_{ij} = \cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} -\theta_{j}-\phi_{ij})
```
```julia-repl
julia> result.branch.power.from.active
```
The active power flow at the bus "to" ``j \in \mathcal{N}`` of the branch ``(i,j) \in \mathcal{E}`` is obtained as:
```math
    P_{ji} = - P_{ij}.
```
```julia-repl
julia> result.branch.power.to.active
```

---

### Generator
The output active power of the generator at the bus ``i \in \mathcal{N}_{\text{pv}}`` is equal to the given active power of the generator in the input data. Moreover, if there are several generators at the bus ``i \in \mathcal{N}_{\text{pv}}`` their output active powers are still equal to the active powers given in the input data. The output active power of the generator at the slack bus is determined as:
```math
    P_{\text{g}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}}.
```
When there are several generators at the slack bus, the active power ``P_{\text{g}i}`` will be assigned to the first generator in the list of input data. After that this active power will be reduced by the output active power of the rest of the generators.
```julia-repl
julia> result.generator.power.active
```