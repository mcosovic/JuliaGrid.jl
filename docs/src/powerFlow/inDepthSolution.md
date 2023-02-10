# [In-depth Power Flow Solution](@id inDepthPowerFlowSolution)

JuliaGrid is based on common network elements and benefits the [unified branch model](@ref inDepthACModel) to find the power flow solution and perform the power flow analysis,  which is used for defining load profiles, generator capabilities, voltage specification, contingency analysis, and planning. In the beginning, JuliaGrid requires the composite type `PowerSystem`, which is obtained by using the function [`powerSystem()`](@ref powerSystem), for example:
```julia-repl
system = powerSystem("case14.h5")
```

To recall, we observe the bus/branch model as a graph ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where the set of nodes ``\mathcal{N} = \{1, \dots, n\}`` represents the set of buses, while the set of edges ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` represents the set of branches of the power network. As shown in section [In-depth AC Model](@ref inDepthACModel), we observe the system of non-linear equations:
```math
    \mathbf{\bar {I}} = \mathbf{Y} \mathbf{\bar {V}}.
```
The complex current injection at the bus ``i \in \mathcal{N}`` is defined as:
```math
  	\bar{I}_{i} = \cfrac{S_{i}^*}{\bar{V}_{i}^*},
```
where ``\bar{V}_{i} = V_i \text{e}^{\text{j}\theta_{i}}``. Thus, for the bus ``i \in \mathcal{N}`` we have:
```math
  	\cfrac{S_{i}^*}{\bar{V}_{i}^*} = \sum_{j = 1}^n Y_{ij} \bar {V}_j.
```
The complex power injection ``S_i`` consists of the active power ``P_i`` and reactive power ``Q_i``, therefore we have:
```math
  	\cfrac{P_i - \text{j}Q_i}{\bar{V}_{i}} = \sum_{j = 1}^n Y_{ij} \bar {V}_j.
```
According to the last equation, for the bus ``i \in \mathcal{N}`` there are four unknown variables: active power injection ``{P}_{i}``, reactive power injection ``{Q}_{i}``, bus voltage magnitude ``{V}_{i}`` and bus voltage angle ``{\theta}_{i}``. To solve the system of equations, two variables for each equation need to be specified. Mathematically, any two variables may be selected, but the choice is dictated by the devices connected to a particular bus. Standard options are summarized in the table below and these options define bus types [[1]](@ref inDepthPowerFlowSolutionReference).

| Bus Type         | Label            | JuliaGrid | Known                       | Unknown                     |
|:-----------------|-----------------:|----------:|----------------------------:|----------------------------:|
| Slack            | ``V \theta``     | 3         | ``V_{i}``, ``{\theta_{i}}`` | ``P_{i}``, ``Q_{i}``        |
| Generator        | PV               | 2         | ``P_{i}``, ``V_{i}``        | ``Q_{i}``, ``{\theta_{i}}`` |
| Demand           | PQ               | 1         | ``P_{i}``, ``Q_{i}``        | ``V_{i}``, ``{\theta_{i}}`` |

Consequently, JuliaGrid operates with sets ``\mathcal{N}_{\text{pv}}`` and ``\mathcal{N}_{\text{pq}}`` that contain PV and PQ buses, respectively, and exactly one slack bus in the set ``\mathcal{N}_{\text{sb}}``. Note that JuliaGrid does not support systems with multiple slack buses. Julia internally designates PV or PQ bus type. Namely, if the bus is not marked as a slack bus, it becomes the PV bus only if it has at least one in-service generator, otherwise the bus is PQ type.
```julia-repl
julia> system.bus.layout.type
```

Finally, we note according to Tellegen's theorem, the active ``{P}_{i}`` and reactive ``{Q}_{i}`` power injections are equal to:
```math
  \begin{aligned}
  	P_{i} &= P_{\text{s}i} - P_{\text{d}i} \\
    Q_{i} &= Q_{\text{s}i} - Q_{\text{d}i},
  \end{aligned}
```
where ``{P}_{\text{s}i}`` and ``{Q}_{\text{s}i}`` denote the active and reactive powers of the generators that supply the bus ``i \in \mathcal{N}``, while ``{P}_{\text{d}i}`` and ``{Q}_{\text{d}i}`` indicate active and reactive powers demanded by consumers at the bus ``i \in \mathcal{N}``.
```julia-repl
julia> system.bus.supply.active - system.bus.demand.active
julia> system.bus.supply.reactive - system.bus.demand.reactive
```

---

## [Newton-Raphson Method](@id inDepthNewtonRaphson)
The Newton-Raphson method is generally preferred in power flow calculations because this method has a quadratic rate of convergence. First of all, the Newton-Raphson method provides a good approximation for the roots of the system of non-linear equations:
```math
  \mathbf{f}(\mathbf{x}) = \mathbf{0}.
```
Hence, the Newton-Raphson method solves the system of non-linear equations ``\mathbf{f}(\mathbf{x})``, and reveals bus voltage magnitudes and angles ``\mathbf{x}``. According to bus types, some buses have known values of the voltage magnitudes and angles:
* at the slack bus ``i \in \mathcal{N}_{\text{sb}}`` voltage magnitude ``V_i`` and angle ``\theta_i`` are known;
* at PV buses ``i \in \mathcal{N}_{\text{pv}}`` voltage magnitude ``V_i`` is known.
Thus, we observe the state vector ``\mathbf x = [\bm \theta, \mathbf V]^T``, where ``\bm \theta \in \mathbb{R}^{n-1}`` and ``\mathbf V \in \mathbb{R}^{n_{\text{pq}}}``, while ``n_{\text{pq}} = |\mathcal{N}_{\text{pq}}|`` is the number of PQ buses.

The complex power injection ``S_i`` at the bus ``i \in \mathcal{N}`` is a function of the complex bus voltages. Hence, the real and imaginary components of the complex power define the active and reactive power injection expressions:
```math
  \begin{aligned}
    {P}_{i} &={V}_{i}\sum\limits_{j=1}^n {V}_{j} (G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij})\\
    {Q}_{i} &={V}_{i}\sum\limits_{j=1}^n {V}_{j} (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}).
	\end{aligned}
```
Based on the above equations, it is possible to define the active power injection function for PV and PQ buses:
```math
    f_{P_i}(\mathbf x) = {V}_{i}\sum\limits_{j=1}^n {V}_{j}(G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij}) - {P}_{i} = 0,
    \;\;\; i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}},
```
and reactive power injection function for PQ buses:
```math
    f_{Q_i}(\mathbf x) = {V}_{i}\sum\limits_{j=1}^n {V}_{j}(G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}) - {Q}_{i} = 0,
    \;\;\; i \in \mathcal{N}_{\text{pq}}.
```

Functions ``f_{P_i}(\mathbf x)`` and ``f_{Q_i}(\mathbf x)`` are called active and reactive mismatch, respectively, and are often marked as ``\Delta P_i(\mathbf x)`` and ``\Delta Q_i(\mathbf x)``. The first terms on the right-hand side represent power injections at a bus, while the second term is constant and is obtained based on the active and reactive powers of the generators that supply a bus and active and reactive powers demanded by consumers at the same bus. Thus, the Newton-Raphson method solves the system of non-linear equations:
```math
  \mathbf{f(x)} =
  \begin{bmatrix}
    \mathbf{f}_{P}(\mathbf x) \\ \mathbf{f}_{Q}(\mathbf x)
  \end{bmatrix} = \mathbf 0,
```
where the first ``n - 1`` equations are defined according to PV and PQ buses, while the last ``n_{\text{pq}}`` equations are defined according to PQ buses.

---

#### Method Implementation
To solve the AC power flow and find the bus voltage magnitudes and angles using the Newton-Raphson method, JuliaGrid provides the following sequence of functions:
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
```

The Newton-Raphson method or Newton's method is essentially based on the Taylor series expansion, neglecting the quadratic and high-order terms. The Newton-Raphson is an iterative method, where we iteratively compute the increments:
```math
  \mathbf{\Delta x^{(\nu)}} = -\mathbf{J(x^{(\nu)})}^{-1}\mathbf{ f(x^{(\nu)})},
```
where ``\mathbf{\Delta x^{(\nu)}} = [\mathbf \Delta \bm \theta^{(\nu)}, \mathbf \Delta \mathbf V^{(\nu)}]^T`` consists of the vector of bus voltage angle increments ``\mathbf \Delta \bm \theta^{(\nu)} \in \mathbb{R}^{n-1}`` and bus voltage magnitude increments ``\mathbf \Delta \mathbf V^{(\nu)} \in \mathbb{R}^{n_{\text{pq}}}``, and ``\mathbf{J(x^{(\nu)})}\in \mathbb{R}^{n_{\text{u}} \times n_{\text{u}}}`` is the Jacobian matrix, ``n_{\text{u}} = n + n_{\text{pq}} - 1``.

```julia-repl
julia> result.algorithm.increment
julia> result.algorithm.jacobian
julia> result.algorithm.mismatch
```
The increment ``\mathbf{ \Delta x^{(\nu)}}`` and mismatch ``\mathbf{f(x^{(\nu)})}`` vectors in JuliaGrid are stored identically as defined, the first ``n - 1`` elements are bus voltage angles increments and active mismatches defined according to PV and PQ buses, in the order in which they appear in the input data. The last ``n_{\text{pq}}`` elements are bus voltage magnitudes increments and reactive mismatches defined according to PQ buses. According to this arrangement, the Jacobian matrix ``\mathbf{J(x^{(\nu)})}`` was also formed.

After that, we update the solution:
```math
  \mathbf {x}^{(\nu + 1)} = \mathbf {x}^{(\nu)} + \mathbf \Delta \mathbf {x}^{(\nu)}.
```
JuliaGrid saves the final results after updating in vectors that contain all bus voltage magnitudes and angles:
```julia-repl
julia> result.bus.voltage.magnitude
julia> result.bus.voltage.angle
```
The current number of iterations ``\nu`` can be accessed using the command:
```julia-repl
julia> result.algorithm.iteration.number
```

The iteration loop is repeated until the stopping criteria is met. Namely, after each iteration, we compute active power injection mismatch for PQ and PV buses:
```math
  f_{P_i}(\mathbf x^{(\nu+1)}) = {V}_{i}^{(\nu+1)}\sum\limits_{j=1}^n {V}_{j}^{(\nu+1)}(G_{ij}\cos\theta_{ij}^{(\nu+1)}+B_{ij}\sin\theta_{ij}^{(\nu+1)}) - {P}_{i},
  \;\;\; i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}},
```
and reactive power injection mismatch for PQ buses:
```math
    f_{Q_i}(\mathbf x^{(\nu+1)}) = {V}_{i}^{(\nu+1)}\sum\limits_{j=1}^n {V}_{j}^{(\nu+1)}(G_{ij}\sin\theta_{ij}^{(\nu+1)}-B_{ij}\cos\theta_{ij}^{(\nu+1)}) - {Q}_{i},
    \;\;\; i \in \mathcal{N}_{\text{pq}}.
```
The iteration loop is stopped when the following conditions are met:
```math
    \max \{|f_{P_i}(\mathbf x^{(\nu+1)})|, i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}} \} < \epsilon \\
    \max \{|f_{Q_i}(\mathbf x^{(\nu+1)})|, i \in \mathcal{N}_{\text{pq}} \} < \epsilon
```
where ``\epsilon`` is the predetermined stopping criteria. JuliaGrid stores these values to break the iteration loop in variables:
```julia-repl
julia> result.algorithm.iteration.stopping.active
julia> result.algorithm.iteration.stopping.reactive
```

Note that the Newton-Raphson method can have difficulties with initial conditions under "flat start".

----

#### Jacobian Matrix
Without loss of generality, we assume that the slack bus is the first bus, followed by the set of PQ buses and the set of PV buses:
```math
  \begin{aligned}
    \mathcal{N}_{\text{sb}} &= \{ 1 \} \\
    \mathcal{N}_{\text{pq}} &= \{2, \dots, m\} \\
    \mathcal{N}_{\text{pv}} &= \{m + 1,\dots, n\},
  \end{aligned}
```
where ``\mathcal{N} = \mathcal{N}_{\text{sb}} \cup \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}}``. Hence, we have
```math
  \begin{aligned}
    \bm \theta &= [\theta_2,\dots,\theta_n]^T; \;\;\;\;\;\; \mathbf \Delta \bm \theta = [\Delta \theta_2,\dots,\Delta \theta_n]^T \\
    \mathbf V &= [V_2,\dots,V_{m}]^T; \;\;\; \mathbf \Delta \mathbf V = [\Delta V_2,\dots,\Delta V_{m}]^T.
  \end{aligned}
```

The Jacobian matrix ``\mathbf{J(x^{(\nu)})} \in \mathbb{R}^{n_{\text{u}} \times n_{\text{u}}}`` is:
```math
  \mathbf{J(x^{(\nu)})}=
  \left[
  \begin{array}{ccc|ccc}
  \cfrac{\mathrm \partial{{f_{P_2}}(\mathbf x^{(\nu)})}} {\mathrm \partial \theta_2} & \cdots &
  \cfrac{\mathrm \partial{{f_{P_2}}(\mathbf x^{(\nu)})}}{\mathrm \partial \theta_{n}} &
  \cfrac{\mathrm \partial{{f_{P_2}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{2}} &\cdots &
  \cfrac{\mathrm \partial{{f_{P_2}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{m}}\\
  \;\vdots  & \\
  \cfrac{\mathrm \partial{{f_{P_n}}(\mathbf x^{(\nu)})}} {\mathrm \partial \theta_2} & \cdots &
  \cfrac{\mathrm \partial{{f_{P_n}}(\mathbf x^{(\nu)})}}{\mathrm \partial \theta_{n}} &
  \cfrac{\mathrm \partial{{f_{P_n}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{2}} &\cdots &
  \cfrac{\mathrm \partial{{f_{P_n}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{m}} \\[10pt]
  \hline \\
  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x^{(\nu)})}} {\mathrm \partial \theta_2} & \cdots &
  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x^{(\nu)})}}{\mathrm \partial \theta_{n}} &
  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{2}} &\cdots &
  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{m}}\\
  \;\vdots  & \\
  \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x^{(\nu)})}} {\mathrm \partial \theta_2} & \cdots &
  \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x^{(\nu)})}}{\mathrm \partial \theta_{n}} &
  \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{2}} &\cdots &
  \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{m}}
  \end{array}
  \right].
```
As we can see, the Jacobian matrix can be written using four block matrices:
```math
	  \mathbf{J(x^{(\nu)})} =
  \begin{bmatrix}
    \mathbf{J_{11}(x^{(\nu)})} &\mathbf{J_{12}(x^{(\nu)})} \\ \mathbf{J_{21}(x^{(\nu)})} &
	   \mathbf{J_{22}(x^{(\nu)})}
  \end{bmatrix},
```
where diagonal elements of the Jacobian sub-matrices are defined according to:
```math
  \begin{aligned}
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x^{(\nu)})}} {\mathrm \partial \theta_{i}} &=
  {V}_{i}^{(\nu)}\sum\limits_{j=1}^n {V}_{j}^{(\nu)}(-G_{ij}
  \sin\theta_{ij}^{(\nu)}+B_{ij}\cos\theta_{ij}^{(\nu)}) - ({V}_{i}^{(\nu)})^2B_{ii}\\
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x^{(\nu)})}}
  {\mathrm \partial V_{i}^{(\nu)}} &= \sum\limits_{
  j=1}^n {V}_{j}^{(\nu)}(G_{ij}\cos
  \theta_{ij}^{(\nu)}+B_{ij}\sin\theta_{ij}^{(\nu)})+{V}_{i}^{(\nu)} G_{ii}\\
  \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x^{(\nu)})}}
  {\mathrm \partial \theta_{i}}&={V}_{i}^{(\nu)}
  \sum\limits_{j=1}^n {V}_{j}^{(\nu)}
  (G_{ij}\cos\theta_{ij}^{(\nu)}+B_{ij}\sin\theta_{ij}^{(\nu)})- ({V}_{i}^{(\nu)})^2G_{ii}\\
  \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x^{(\nu)})}}
  {\mathrm \partial V_{i}}&=\sum\limits_{j=1
  }^n {V}_{j}^{(\nu)}(G_{ij}\sin\theta_{ij}^{(\nu)}-
  B_{ij}\cos\theta_{ij}^{(\nu)})-{V}_{i}^{(\nu)} B_{ii},
  \end{aligned}
```
while non-diagonal elements of the Jacobian sub-matrices are:
```math
  \begin{aligned}
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x^{(\nu)})}}
  {\mathrm \partial \theta_{j}}&={V}_{i}^{(\nu)}{V}_{j}^{(\nu)}
  (G_{ij}\sin\theta_{ij}^{(\nu)}-B_{ij}\cos\theta_{ij}^{(\nu)})\\
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x^{(\nu)})}}
  {\mathrm \partial V_{j}^{(\nu)}} &= {V}_{i}^{(\nu)}(G_{ij}\cos
  \theta_{ij}^{(\nu)}+B_{ij}\sin\theta_{ij}^{(\nu)})\\
  \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x^{(\nu)})}}
  {\mathrm \partial \theta_{j}}&={V}_{i}^{(\nu)}{V}_{j}^{(\nu)}
  (-G_{ij}\cos\theta_{ij}^{(\nu)} -B_{ij}\sin\theta_{ij}^{(\nu)})\\
  \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x^{(\nu)})}}{\mathrm
  \partial V_{j}}&={V}_{i}^{(\nu)}(G_{ij}\sin\theta_{ij}^{(\nu)}-
  B_{ij}\cos\theta_{ij}^{(\nu)}).
  \end{aligned}
```
---

## [Fast Newton-Raphson Method](@id inDepthFastNewtonRaphson)
The convergence of the fast Newton-Raphson method is slower than the Newton-Raphson method, but often, a shorter solution time for the updates compensates for slower convergence, resulting in an overall shorter solution time. For not too heavily loaded systems a shorter overall solution time is almost always obtained. It should be noted that if the algorithm converges, it converges to a correct solution [[2]](@ref inDepthPowerFlowSolutionReference).

The fast Newton-Raphson method is based on the decoupling of the power flow equations. Namely, the Newton-Raphson method is based on the equations:
```math
  \begin{bmatrix}
    \mathbf{J_{11}(x)} &\mathbf{J_{12}(x)} \\ \mathbf{J_{21}(x)} &
	   \mathbf{J_{22}(x)}
  \end{bmatrix}
  \begin{bmatrix}
    \mathbf{\Delta \theta} \\ \mathbf{\Delta V}
  \end{bmatrix}	+
  \begin{bmatrix}
    \mathbf{f}_{P}(\mathbf x) \\ \mathbf{f}_{Q}(\mathbf x)
  \end{bmatrix} = \mathbf 0,
```
where we dropped the iteration index for simplicity. In transmission grids, a strong coupling can be found between active powers and voltage angles, and between reactive powers and voltage magnitudes. To obtain decoupling, two conditions are assumed to have been satisfied: first, the resistances ``r_{ij}`` of the branches are small with respect to their respective reactances ``x_{ij}`` and, second, the angle differences are small ``\theta_{ij} \approx 0`` [[3]](@ref inDepthPowerFlowSolutionReference). Respectively, we start from the equation:
```math
  \begin{bmatrix}
    \mathbf{J_{11}(x)} & \mathbf{0} \\ \mathbf{0} & \mathbf{J_{22}(x)}
  \end{bmatrix}
  \begin{bmatrix}
    \mathbf{\Delta \bm \theta} \\ \mathbf{\Delta V}
  \end{bmatrix}	+
  \begin{bmatrix}
    \mathbf{f}_{P}(\mathbf x) \\ \mathbf{f}_{Q}(\mathbf x)
  \end{bmatrix} = \mathbf 0,
```
Thus, the decoupled system can be written as:
```math
  \begin{aligned}
    \mathbf{f}_{P}(\mathbf x) &= -\mathbf{J_{11}(x)} \mathbf{\Delta \bm  \theta} \\
    \mathbf{f}_{Q}(\mathbf x) &= -\mathbf{J_{22}(x)} \mathbf{\Delta V}.
  \end{aligned}
```
Here, it would be useful to observe the problem in the form:
```math
  \begin{aligned}
    {f}_{P_2}(\mathbf x) &= -\Delta \theta_2\cfrac{\mathrm \partial{{f_{P_2}}(\mathbf x)}} {\mathrm \partial \theta_2} - \cdots -
    \Delta \theta_n \cfrac{\mathrm \partial{{f_{P_2}}(\mathbf x)}}{\mathrm \partial \theta_{n}} \\
    & \vdots \\
    {f}_{P_n}(\mathbf x) &= -\Delta \theta_2\cfrac{\mathrm \partial{{f_{P_n}}(\mathbf x)}} {\mathrm \partial \theta_2} - \cdots -
    \Delta \theta_n \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}}{\mathrm \partial \theta_{n}}\\
    {f}_{Q_2}(\mathbf x) &= - \Delta V_2 \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x)}}{\mathrm \partial V_{2}} - \cdots -
    \Delta V_{n_{\text{pq}}}  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x)}}{\mathrm \partial V_{m}}\\
    & \vdots \\
    {f}_{Q_{m}}(\mathbf x) &= - \Delta V_2 \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x)}}{\mathrm \partial V_{2}} - \cdots -
    \Delta V_{m}  \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x)}}{\mathrm \partial V_{m}}.
  \end{aligned}
```
First of all, we expand the second part of the expressions as follows:
```math
  \begin{aligned}
  {f}_{Q_2}(\mathbf x) &=
  -\cfrac{\Delta V_2}{V_2}V_2 \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x)}}{\mathrm \partial V_{2}} - \cdots -
  \cfrac{\Delta V_{m}}{V_{m}} V_{m}
  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x)}}{\mathrm \partial V_{m}}\\
  & \vdots \\
  {f}_{Q_{m}}(\mathbf x) &=
  - \cfrac{\Delta V_2}{V_2}V_2 \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x)}}{\mathrm \partial V_{2}} - \cdots -
  \cfrac{\Delta V_{m}}{V_{m}} V_{m}
  \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x)}}{\mathrm \partial V_{m}}.
  \end{aligned}
```
The next step is deriving the Jacobian elements. For this purpose, let us consider the expressions defined for the Newton-Raphson method, where we applied the above expansions for PQ buses:
```math
  \begin{aligned}
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}} {\mathrm \partial \theta_{i}} &=
  {V}_{i}\sum\limits_{j=1}^n {V}_{j}(-G_{ij}
  \sin\theta_{ij}+B_{ij}\cos\theta_{ij}) - {V}_{i}^2B_{ii}\\
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}}
  {\mathrm \partial \theta_{j}}&={V}_{i}{V}_{j}
  (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij})\\
  V_i \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}}
  {\mathrm \partial V_{i}} &= V_i\sum\limits_{j=1
  }^n {V}_{j}(G_{ij}\sin\theta_{ij}-
  B_{ij}\cos\theta_{ij})-{V}_{i}^2 B_{ii}\\
  V_j \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}}{\mathrm
  \partial V_{j}} &= {V}_{i}V_j (G_{ij}\sin\theta_{ij}-
  B_{ij}\cos\theta_{ij}).
  \end{aligned}
```
Since the reactive power is defined as:
```math
    {Q}_{i} ={V}_{i}\sum\limits_{j=1}^n {V}_{j}(G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}),
```
Jacobian elements can be written in the form:
```math
  \begin{aligned}
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}} {\mathrm \partial \theta_{i}} &=
  -Q_i - {V}_{i}^2B_{ii}\\
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}}
  {\mathrm \partial \theta_{j}}&={V}_{i}{V}_{j}
  (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij})\\
  V_i \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}}
  {\mathrm \partial V_{i}} &= Q_i-{V}_{i}^2 B_{ii}\\
  V_j \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}}{\mathrm
  \partial V_{j}} &= {V}_{i}V_j (G_{ij}\sin\theta_{ij}-
  B_{ij}\cos\theta_{ij}).
  \end{aligned}
```
The decoupled model is based on the following approximations:
```math
  \begin{aligned}
    \sin(\theta_{ij}) \approx 0 \\
    \cos(\theta_{ij}) \approx 1 \\
    Q_i << B_{ii}V_i^2.
  \end{aligned}
```
Consequently, Jacobian elements become:
```math
  \begin{aligned}
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}} {\mathrm \partial \theta_{i}} &= -{V}_{i}^2B_{ii}\\
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}} {\mathrm \partial \theta_{j}} &= -{V}_{i}{V}_{j}B_{ij}\\
  V_i \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}} {\mathrm \partial V_{i}} &= -{V}_{i}^2B_{ii}\\
  V_j \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}}{\mathrm\partial V_{j}} &=  -{V}_{i}{V}_{j}B_{ij}.
  \end{aligned}
```
Then, the initial system of equations is:
```math
  \begin{aligned}
    {f}_{P_2}(\mathbf x) &= {V}_{2}^2B_{22} \Delta \theta_2 + \cdots + {V}_{2}{V}_{n}B_{2n} \Delta \theta_n \\
    & \vdots \\
    {f}_{P_n}(\mathbf x) &= {V}_{2}{V}_{n}B_{n2} \Delta \theta_2 + \cdots + {V}_{n}^2B_{nn} \Delta \theta_n \\
    {f}_{Q_2}(\mathbf x) &=  {V}_{2}^2B_{22} \cfrac{\Delta V_2}{V_2} + \cdots +
     {V}_{2}V_{m}B_{2m} \cfrac{\Delta V_{m}}{V_{m}} \\
    & \vdots \\
    {f}_{Q_{m}}(\mathbf x) &= {V}_{2}V_{m}B_{m2} \cfrac{\Delta V_2}{V_2} + \cdots +
    V_{m}^2 B_{mm} \cfrac{\Delta V_{m}}{V_{m}}.
  \end{aligned}
```
Using ``V_j \approx 1``, wherein ``V_i^2 = V_iV_j, j=i``, the first part of the equations have a form:
```math
  \begin{aligned}
    {f}_{P_2}(\mathbf x) &= {V}_{2}B_{22} \Delta \theta_2 + \cdots + {V}_{2}B_{2n} \Delta \theta_n \\
    & \vdots \\
    {f}_{P_n}(\mathbf x) &= {V}_{n}B_{n2} \Delta \theta_2 + \cdots + {V}_{n}B_{nn} \Delta \theta_n.
  \end{aligned}
```
Simplifying the second part of the equations, we obtain:
```math
  \begin{aligned}
    {f}_{Q_2}(\mathbf x) &=  {V}_{2}B_{22} \Delta V_2 + \cdots +
     V_2 B_{2m} \Delta V_{m}
    \\
    & \vdots \\
    {f}_{Q_{m}}(\mathbf x) &= V_{m}B_{m2} \Delta V_2 + \cdots +
    V_{m} B_{mm} \Delta V_{m}.
  \end{aligned}
```

Finally, the fast Newton-Raphson method is based on the following system of equations:
```math
  \begin{aligned}
    \cfrac{{f}_{P_2}(\mathbf x)}{{V}_{2}} &= B_{22} \Delta \theta_2 + \cdots + B_{2n} \Delta \theta_n \\
    & \vdots \\
    \cfrac{{f}_{P_n}(\mathbf x)}{{V}_{n}} &= B_{n2} \Delta \theta_2 + \cdots + B_{nn} \Delta \theta_n \\
    \cfrac{{f}_{Q_2}(\mathbf x)}{{V}_{2}} &=  B_{22} \Delta V_2 + \cdots + B_{2m} \Delta V_{m} \\
    & \vdots \\
    \cfrac{{f}_{Q_{m}}(\mathbf x)}{V_{m}} &= B_{m2} \Delta V_2 + \cdots +
    B_{mm} \Delta V_{m},
  \end{aligned}
```
which can be written as:
```math
  \begin{aligned}
    \mathbf{h}_{P}(\mathbf x) &= \mathbf{B}_1 \mathbf{\Delta \bm \theta} \\
    \mathbf{h}_{Q}(\mathbf x) &= \mathbf{B}_2 \mathbf{\Delta V}.
  \end{aligned}
```
True benefits from these equations are that Jacobian matrices ``\mathbf{B}_1`` and ``\mathbf{B}_2`` are constant and should be formed only once. Next, it is now possible to define XB and BX versions of the fast Newton-Raphson method.

---

#### XB Version
The resistance ``r_{ij}``, shunt susceptance ``\Im \{ y_{\text{sh}i} \}``, charging susceptance ``\Im \{ y_{\text{s}ij} \}`` and transformer tap ratio magnitude ``\tau_{ij}`` are ignored while forming the matrix ``\mathbf{B}_1``. The transformer phase shift angle ``\phi_{ij}`` is ignored while building the matrix ``\mathbf{B}_2``. This version is the standard fast Newton-Raphson method and has excellent convergence properties for usual cases [[3]](@ref inDepthPowerFlowSolutionReference).

To initialize the XB version of the fast Newton-Raphson method, we use:
```julia-repl
system = powerSystem("case14.h5")
acModel!(system)

result = fastNewtonRaphsonXB(system)
```

---

#### BX Version
The shunt susceptance ``\Im \{ y_{\text{sh}i} \}``, charging susceptance ``\Im \{ y_{\text{s}ij} \}`` and transformer tap ratio magnitude ``\tau_{ij}`` are ignored while forming the matrix ``\mathbf{B}_1``. The resistance ``r_{ij}`` and transformer phase shift angle ``\phi_{ij}`` are ignored while building the matrix ``\mathbf{B}_2``. For usual cases, the iteration count will be similar to the XB scheme, but for systems with a few or with general high ``r_{ij}/x_{ij}`` ratios the number of iterations needed to solve the power flow is considerably smaller than the number of the XB scheme [[3]](@ref inDepthPowerFlowSolutionReference).

To initialize the BX version of the fast Newton-Raphson method, we use:
```julia-repl
system = powerSystem("case14.h5")
acModel!(system)

result = fastNewtonRaphsonBX(system)
```

---

#### Method Implementation
In the beginning, we evaluate matrices ``\mathbf{B}_1`` and ``\mathbf{B}_2`` related with active and reactive power equations, respectively. These matrices can be accessed using commands:
```julia-repl
julia> result.algorithm.active.jacobian
julia> result.algorithm.reactive.jacobian
```

Then, JuliaGrid uses the [LU factorization](https://docs.julialang.org/en/v1/stdlib/LinearAlgebra/#LinearAlgebra.lu) of matrices ``\mathbf{B}_1`` and ``\mathbf{B}_2`` to reveal solutions through iterations:
```julia-repl
julia> result.algorithm.active.lower
julia> result.algorithm.active.upper
julia> result.algorithm.active.right
julia> result.algorithm.active.left
julia> result.algorithm.active.scaling
```

```julia-repl
julia> result.algorithm.reactive.lower
julia> result.algorithm.reactive.upper
julia> result.algorithm.reactive.right
julia> result.algorithm.reactive.left
julia> result.algorithm.reactive.scaling
```

Finally, to solve the AC power flow and find the bus voltage magnitudes and angles, JuliaGrid provides the following sequence of functions:
```julia-repl
stopping = result.algorithm.iteration.stopping
for i = 1:10
    fastNewtonRaphson!(system, result)
    if stopping.active < 1e-8 && stopping.reactive < 1e-8
        break
    end
end
```

The fast Newton-Raphson method first solves the equation:
```math
  \mathbf{\Delta \bm \theta}^{(\nu)} = \mathbf{B}_1^{-1} \mathbf{h}_{P}(\bm \theta^{(\nu)}, \mathbf V^{(\nu)}).
```
```julia-repl
julia> result.algorithm.active.increment
julia> result.algorithm.active.mismatch
```

After that, we update the solution:
```math
  \bm{\theta}^{(\nu+1)} = \bm{\theta}^{(\nu)} + {\mathbf \Delta \bm \theta}^{(\nu)}.
```
JuliaGrid stores the final results after updating in the vector that contains all bus voltage angles:
```julia-repl
julia> result.bus.voltage.angle
```

The fast Newton-Raphson method further solves the equation:
```math
  \mathbf{\Delta V}^{(\nu)} = \mathbf{B}_2^{-1} \mathbf{h}_{Q}(\bm \theta^{(\nu + 1)}, \mathbf V^{(\nu)}).
```
```julia-repl
julia> result.algorithm.reactive.increment
julia> result.algorithm.reactive.mismatch
```

Finally, we update the solution:
```math
  \mathbf{V}^{(\nu+1)} = \mathbf{V}^{(\nu)} + \mathbf{\Delta V}^{(\nu)}.
```
JuliaGrid stores the final results after updating in the vector that contains all bus voltage magnitudes:
```julia-repl
julia> result.bus.voltage.magnitude
```

No approximations have been introduced to the functions ``\mathbf{f}_{P}(\mathbf x)`` or ``\mathbf{f}_{Q}(\mathbf x)``, only in the way we calculate the increments of the state variables [[2]](@ref inDepthPowerFlowSolutionReference). Consequently, we still use the following equations to compute mismatches:
```math
  \begin{aligned}
    f_{P_i}(\mathbf x) &= {V}_{i}\sum\limits_{j=1}^n {V}_{j}(G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij}) - {P}_{i} = 0,
    \;\;\; i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}}\\
    f_{Q_i}(\mathbf x) &= {V}_{i}\sum\limits_{j=1}^n {V}_{j} (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}) - {Q}_{i} = 0,
    \;\;\; i \in \mathcal{N}_{\text{pq}}.
  \end{aligned}
```

Hence, we compute active power injection mismatch for PQ and PV buses:
```math
  {h}_{P_i}(\mathbf x^{(\nu+1)}) =
  \sum\limits_{j=1}^n {V}_{j}^{(\nu+1)}(G_{ij}\cos\theta_{ij}^{(\nu+1)}+B_{ij}\sin\theta_{ij}^{(\nu+1)}) - \cfrac{{P}_{i}}{{V}_{i}^{(\nu+1)}},
  \;\;\;  i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}},
```
and reactive power injection mismatch for PQ buses:
```math
    {h}_{Q_i}(\mathbf x^{(\nu+1)}) =
    \sum\limits_{j=1}^n {V}_{j}^{(\nu+1)} (G_{ij}\sin\theta_{ij}^{(\nu)}-B_{ij}\cos\theta_{ij}^{(\nu+1)}) - \cfrac{{Q}_{i}}{{V}_{i}^{(\nu+1)}},
    \;\;\; i \in \mathcal{N}_{\text{pq}}.
```
The iteration loop is stopped when the following conditions are met:
```math
    \max \{|h_{P_i}(\mathbf x^{(\nu)})|, i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}} \} < \epsilon \\
    \max \{|h_{Q_i}(\mathbf x^{(\nu)})|, i \in \mathcal{N}_{\text{pq}} \} < \epsilon
```
where ``\epsilon`` is the predetermined stopping criteria. JuliaGrid stores these values to break the iteration loop in variables:
```julia-repl
julia> result.algorithm.iteration.stopping.active
julia> result.algorithm.iteration.stopping.reactive
```

---

## [Gauss-Seidel Method](@id inDepthGaussSeidel)
Defining the complex current injection at the bus ``i \in \mathcal{N}`` as:
```math
	\bar{I}_{i} = \frac{{P}_{i} - j{Q}_{i}}{\bar{V}_{i}^*},
```
the power flow problem is described by the system of non-linear equations:
```math
    \mathbf {\bar {I}} = \mathbf{Y} \mathbf {\bar {V}},
```
can be written in the expanded form:
```math
  \begin{aligned}
    Y_{11} & \bar{V}_{1}  + \cdots+ Y_{1n}\bar{V}_{n} = \frac{{P}_{1} - j{Q}_{1}}{\bar{V}_{1}^*} \\
    \; \vdots & \\
    Y_{n1} & \bar{V}_{1} + \cdots+ Y_{nn}\bar{V}_{n} = \frac{{P}_{n} - j{Q}_{n}}{\bar{V}_{n}^*}.
	\end{aligned}
```
The Gauss-Seidel method directly solves the above system of equations, albeit with very slow convergence, almost linearly with the size of the system. Consequently, this method needs many iterations to achieve the desired solution [[4]](@ref inDepthPowerFlowSolutionReference). The Gauss-Seidel method convergence time increases significantly for large-scale systems and can exhibit convergence problems for systems with high active power transfers. However, the Newton-Raphson and Gauss-Seidel methods are used complementary, meaning that power flow programs implement both. Gauss-Seidel method is used to rapidly determine an approximate solution from a "flat start", and then the Newton-Raphson method is used to obtain the final accurate solution [[5]](@ref inDepthPowerFlowSolutionReference).

In general, the Gauss-Seidel method is based on the above system of equations, where the set of non-linear equations has ``n`` complex equations, and one of these equations describes the slack bus. Consequently, one of these equations can be removed resulting in the power flow problem with ``n-1`` equations.

---

#### Method Implementation
To solve the AC power flow and find the bus voltage magnitudes and angles using the Gauss-Seidel method, JuliaGrid provides the following sequence of functions:
```julia-repl
system = powerSystem("case14.h5")
acModel!(system)

result = gaussSeidel(system)
stopping = result.algorithm.iteration.stopping
for i = 1:10
    gaussSeidel!(system, result)
    if stopping.active < 1e-8 && stopping.reactive < 1e-8
        break
    end
end
```

The method starts with initial complex bus voltages ``\bar{V}_i^{(0)}, i \in \mathcal{N}``. The iteration scheme first computes bus complex voltages for PQ buses:
```math
    \bar{V}_{i}^{(\nu + 1)} =
    \cfrac{1}{{Y}_{ii}} \Bigg(\cfrac{{P}_{i} - j{Q}_{i}}{\bar{V}_{i}^{*(\nu)}} -
    \sum\limits_{\substack{j = 1}}^{i - 1} {Y}_{ij}\bar{V}_{j}^{(\nu + 1)} -
    \sum\limits_{\substack{j = i + 1}}^{n} {Y}_{ij}\bar{V}_{j}^{(\nu)}\Bigg),
    \;\;\; i \in \mathcal{N}_{\text{pq}}.
```
Then, the solution for PV buses is obtained in two steps: we first determine the reactive power injection, and then the bus complex voltage is updated:
```math
  \begin{aligned}
    Q_i^{(\nu+1)} &=
    -\Im \left\{ \bar{V}_{i}^{*(\nu + 1)} \sum\limits_{j=1}^n {Y}_{ij}\bar{V}_{j}^{(\nu+1)}\right\}, \;\;\; i \in \mathcal{N}_{\text{pv}} \\
    \bar{V}_{i}^{(\nu + 1)} &:=
    \cfrac{1}{{Y}_{ii}} \Bigg(\cfrac{{P}_{i} - j{Q}_{i}^{(\nu + 1)}}{\bar{V}_{i}^{*(\nu + 1)}}-
    \sum\limits_{\substack{j = 1,\;j \neq i}}^{n} {Y}_{ij}\bar{V}_{j}^{(\nu + 1)} \Bigg), \;\;\; i \in \mathcal{N}_{\text{pv}}.
  \end{aligned}
```
Obtained voltage magnitude is not equal to the magnitude specified for the PV bus. Thus, it is necessary to perform the voltage correction:
```math
      \bar{V}_{i}^{(\nu+1)} := {V}_{i}^{(0)} \cfrac{\bar{V}_{i}^{(\nu+1)}}{{V}_{i}^{(\nu+1)}}, \;\;\; i \in \mathcal{N}_{\text{pv}}.
```

JuliaGrid saves the final results in vectors that contain all bus voltage magnitudes and angles:
```julia-repl
julia> result.bus.voltage.magnitude
julia> result.bus.voltage.angle
```

The iteration loop is repeated until the stopping criteria is met. Namely, after one iteration loop is done, we compute active power injection mismatch for PQ and PV buses:
```math
    {f}_{P_i}(\mathbf x^{(\nu+1)}) = \Re\{\bar{V}_i^{(\nu + 1)} \bar{I}_i^{*(\nu + 1)}\} - P_i, \;\;\; i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}},
```
and reactive power injection mismatch for PQ buses:
```math
  {f}_{Q_i}(\mathbf x^{(\nu+1)}) = \Im\{\bar{V}_i^{(\nu + 1)} \bar{I}_i^{*(\nu + 1)}\} - Q_i, \;\;\; i \in \mathcal{N}_{\text{pq}}.
```
The iteration loop is stopped when the following conditions are met:
```math
    \max \{|{f}_{P_i}(\mathbf x^{(\nu+1)})|, i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}} \} < \epsilon \\
    \max \{|{f}_{Q_i}(\mathbf x^{(\nu+1)})|, i \in \mathcal{N}_{\text{pq}} \} < \epsilon
```
where ``\epsilon`` is the predetermined stopping criteria. JuliaGrid stores these values to break the iteration loop:
```julia-repl
julia> result.algorithm.iteration.stopping.active
julia> result.algorithm.iteration.stopping.reactive
```

---

## [DC Power Flow Solution](@id dcPowerFlowSolution)
As shown in section [In-depth DC Model](@ref inDepthDCModel), the DC power flow problem is described by the system of linear equations:
```math
  \mathbf {P} = \mathbf{B} \bm {\theta} + \mathbf{P_\text{gs}} + \mathbf{P}_\text{sh}.
```

---

#### Implementation
To solve the DC power flow and find the bus voltage angles, JuliaGrid provides the following sequence of functions:
```julia-repl
system = powerSystem("case14.h5")
dcModel!(system)

result = dcPowerFlow(system)
```

The DC power flow solution is obtained through a non-iterative procedure by solving the linear problem:
```math
    \bm {\theta} = \mathbf{B}^{-1}(\mathbf {P} - \mathbf{P_\text{gs}} - \mathbf{P}_\text{sh}).
```
Note that the slack bus voltage angle is excluded from ``\bm {\theta}``. Hence, corresponding elements in vectors ``\mathbf {P}``, ``\mathbf{P_\text{gs}}``, ``\mathbf{P}_\text{sh}``, and corresponding column of the matrix ``\mathbf{B}`` will be removed, during the calculation process.

JuliaGrid saves the final result in the vector that contains all bus voltage angles:
```julia-repl
julia> result.bus.voltage.angle
```

---

## [References](@id inDepthPowerFlowSolutionReference)
[1] A. Wood and B. Wollenberg, *Power Generation, Operation, and Control*, ser. A Wiley-Interscience publication. Wiley, 1996.

[2] G. Andersson, *Modelling and analysis of electric power systems*, EEH-Power Systems Laboratory, Swiss Federal Institute of Technology (ETH), Zürich, Switzerland (2008).

[3] R. A. M. van Amerongen, "A general-purpose version of the fast decoupled load flow," *IEEE Trans. Power Syst.*, vol. 4, no. 2, pp. 760-770, May 1989.

[4] D. P. Chassin, P. R. Armstrong, D. G. Chavarria-Miranda, and R. T. Guttromson, "Gauss-seidel accelerated: implementing flow solvers on field programmable gate arrays," *in Proc. IEEE PES General Meeting*, 2006, pp. 5.

[5] R. D. Zimmerman, C. E. Murillo-Sanchez, *MATPOWER User’s Manual*, Version 7.0. 2019.

