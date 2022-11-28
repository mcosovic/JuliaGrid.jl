# [In-depth Power Flow Solution](@id inDepthPowerFlowSolution)

JuliaGrid is based on common network elements and benefits the [unified branch model](@ref branchModelAC) to perform the power flow analysis, which is used for defining load profiles, generator capabilities, voltage specification, contingency analysis, and planning.

To recall, we observe the bus/branch model as a graph ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where the set of nodes ``\mathcal{N} = \{1, \dots, n\}`` represents the set of buses, while the set of edges ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` represents the set of branches of the power network. As shown in section [In-depth AC Model](@ref inDepthACModel), the power flow problem is described by the system of non-linear equations:
```math
    \mathbf{\bar {I}} = \mathbf{Y} \mathbf{\bar {V}},
```
where the complex injection current into the bus ``i \in \mathcal{N}`` is defined as:
```math
  	\bar{I}_{i} = \cfrac{S_{i}^*}{\bar{V}_{i}^*},
```
where ``\bar{V}_{i} = V_i \text{e}^{\text{j}\theta_{i}}``. Thus, for the bus ``i \in \mathcal{N}`` we have:
```math
  	\cfrac{S_{i}^*}{\bar{V}_{i}^*} = \sum_{j = 1}^n Y_{ij} \bar {V}_j.
```
The apparent power injection ``S_i`` consists of the active power ``P_i`` and reactive power ``Q_i``, therefore we have:
```math
  	\cfrac{P_i - \text{j}Q_i}{\bar{V}_{i}} = \sum_{j = 1}^n Y_{ij} \bar {V}_j.
```
According to the last equation, for the bus ``i \in \mathcal{N}`` there are four unknown variables: active power injection ``{P}_{i}``, reactive power injection ``{Q}_{i}``, voltage magnitude ``{V}_{i}`` and voltage angle ``{\theta}_{i}``. To solve the system of equations, two variables for each equation need to be specified. Mathematically, any two variables may be selected, but the choice is dictated by the devices connected to a particular bus. Standard options are summarized in Table below and these options define bus types [[1]](@ref refs).

| Bus Type         | Label            | JuliaGrid | Known                       | Unknown                     |
|:-----------------|-----------------:|----------:|----------------------------:|----------------------------:|
| Slack generator  | ``V \theta``     | 3         | ``V_{i}``, ``{\theta_{i}}`` | ``P_{i}``, ``Q_{i}``        |
| Generator        | PV               | 2         | ``P_{i}``, ``V_{i}``        | ``Q_{i}``, ``{\theta_{i}}`` |
| Demand           | PQ               | 1         | ``P_{i}``, ``Q_{i}``        | ``V_{i}``, ``{\theta_{i}}`` |

Consequently, JuliaGrid operates with sets ``\mathcal{N}_{\text{pv}}`` and ``\mathcal{N}_{\text{pq}}`` that contain PV and PQ buses, respectively, and exactly one slack bus ``\mathcal{N}_{\text{sb}}``. Note that JuliaGrid does not support systems with multiple slack buses.

Finally, we note according to Tellegen's theorem, the bus active ``{P}_{i}`` and reactive ``{Q}_{i}`` power injections are equal to:
```math
  \begin{aligned}
  	P_{i} &= P_{\text{g}i} - P_{\text{d}i} \\
    Q_{i} &= Q_{\text{g}i} - Q_{\text{d}i}
  \end{aligned}
```
where ``{P}_{\text{g}i}`` and ``{Q}_{\text{g}i}`` denote the active and reactive powers of the generators that supply the bus ``i \in \mathcal{N}``, while ``{P}_{\text{d}i}`` and ``{Q}_{\text{d}i}`` indicate active and reactive powers demanded by consumers at the bus ``i in \mathcal{N}``.