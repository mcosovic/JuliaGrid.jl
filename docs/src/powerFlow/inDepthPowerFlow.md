# [In-depth Power Flow Solution](@id inDepthPowerFlowSolution)

JuliaGrid is based on common network elements and benefits the [unified branch model](@ref inDepthACModel) to perform the power flow analysis, which is used for defining load profiles, generator capabilities, voltage specification, contingency analysis, and planning. At the beginning, JuliaGrid requires the formation of the composite type `PowerSystem` using the function [`powerSystem()`](@ref powerSystem), for example:
```julia-repl
system = powerSystem("case14.h5")
```

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
```julia-repl
julia> system.bus.layout.type
```

Finally, we note according to Tellegen's theorem, the bus active ``{P}_{i}`` and reactive ``{Q}_{i}`` power injections are equal to:
```math
  \begin{aligned}
  	P_{i} &= P_{\text{g}i} - P_{\text{d}i} \\
    Q_{i} &= Q_{\text{g}i} - Q_{\text{d}i},
  \end{aligned}
```
where ``{P}_{\text{g}i}`` and ``{Q}_{\text{g}i}`` denote the active and reactive powers of the generators that supply the bus ``i \in \mathcal{N}``, while ``{P}_{\text{d}i}`` and ``{Q}_{\text{d}i}`` indicate active and reactive powers demanded by consumers at the bus ``i \in \mathcal{N}``.
```julia-repl
julia> system.bus.supply.active - system.bus.demand.active
julia> system.bus.supply.reactive - system.bus.demand.reactive
```

---

## [Newton-Raphson Method](@id inDepthNewtonRaphson)
The Newton-Raphson method is generally preferred in power flow calculations because this method has quadratic rate of convergence. The method can have difficulties with initial conditions ("flat start"). First of all, the Newton-Raphson method provides a good approximation for the roots of the system of non-linear equations:
```math
  \mathbf{f}(\mathbf{x}) = \mathbf{0}.
```
To solve the AC power flow analysis and find the bus voltage magnitudes and angles, JuliaGrid provides the following sequence of functions:
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

The Newton-Raphson method or Newton's method is essentially based on the Taylor series expansion, neglecting the quadratic and high order terms. The Newton-Raphson is an iterative method, where we iteratively compute the increments ``\mathbf \Delta \mathbf {x}`` using Jacobian matrix ``\mathbf{J}(\mathbf x)``, and update solutions:
```math
  \begin{aligned}
    \mathbf \Delta \mathbf {x}^{(\nu)} &= -\mathbf J(\mathbf x^{(\nu)})^{-1} \mathbf f(\mathbf x^{(\nu)}) \\
    \mathbf {x}^{(\nu + 1)} &= \mathbf {x}^{(\nu)} + \mathbf \Delta \mathbf {x}^{(\nu)},
  \end{aligned}
```
where ``\nu = \{1,2,\dots \}`` represents the iteration index, and is stored as:
```julia-repl
julia> result.algorithm.iteration.number
```

Let us observe the vector ``\mathbf x_{\text{sv}} \in \mathbb{R}^{2n}`` given in the polar coordinate system:
```math
  \mathbf x_{\text{sv}} = [\theta_1,\dots,\theta_n,V_1,\dots,V_n]^T.
```
The vector contains the voltage angles and magnitudes at all buses, and can be accessed after any iteration ``\nu``:
```julia-repl
julia> result.bus.voltage.angle
julia> result.bus.voltage.magnitude
```

However, the Newton-Raphson method does not use the entire vector ``\mathbf x_{\text{sv}}``. Namely, the vector ``\mathbf x_{\text{sv}}`` contains elements whose values are known:
* voltage angle ``\theta_i`` and magnitude ``V_i`` at the slack bus, ``i \in \mathcal{N}_{\text{sb}}``;
* voltage magnitude ``V_i`` at PV buses, ``i \in \mathcal{N}_{\text{pv}}``.
More precisely, the number of unknowns is ``n_{\text{u}} = 2n - n_{\text{pv}} - 2``, where ``n_{\text{pv}} = |\mathcal{N}_{\text{pv}}|`` is the number of PV buses. Thus, we observe the state vector ``\mathbf x \in \mathbb{R}^{n_{\text{u}}}`` and associated vector of increments ``\mathbf \Delta \mathbf x \in \mathbb{R}^{n_{\text{u}}}``:
```math
  \mathbf x =
  \begin{bmatrix}
    \bm \theta \\ \mathbf V
  \end{bmatrix}; \;\;\;
  \mathbf \Delta \mathbf x =
  \begin{bmatrix}
    \mathbf \Delta \bm \theta \\ \mathbf \Delta \mathbf V
  \end{bmatrix}.
```

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

The apparent power injection ``S_i`` into the bus ``i \in \mathcal{N}`` is a function of the complex bus voltages. Hence, the real and imaginary components of the apparent power define the active and reactive power injection expressions:
```math
  \begin{aligned}
    {P}_{i} &={V}_{i}\sum\limits_{j=1}^n {V}_{j} (G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij})\\
    {Q}_{i} &={V}_{i}\sum\limits_{j=1}^n {V}_{j} (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}).
	\end{aligned}
```
Based on the above equations, it is possible to define the active power injection functions for PV and PQ buses:
```math
    f_{P_i}(\mathbf x) = {V}_{i}\sum\limits_{j=1}^n {V}_{j}(G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij}) - {P}_{i} = 0,
    \;\;\; i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}},
```
and reactive power injection functions for PQ buses:
```math
    f_{Q_i}(\mathbf x) = {V}_{i}\sum\limits_{j=1}^n {V}_{j}(G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}) - {Q}_{i} = 0,
    \;\;\; i \in \mathcal{N}_{\text{pq}}.
```

Functions ``f_{P_i}(\mathbf x)`` and ``f_{Q_i}(\mathbf x)`` are called active and reactive mismatch, respectively, and are often marked as ``\Delta P_i(\mathbf x)`` and ``\Delta Q_i(\mathbf x)``. The first terms on the right-hand side represents power injections into the bus ``i``, while the second term is constant and is obtained based on the active and reactive powers of the generators that supply the bus ``i`` and active and reactive powers demanded by consumers at the bus ``i``. Thus, the power flow problem is described by the system of equations:
```math
  \mathbf{f(x)} =
  \begin{bmatrix}
      f_{P_2}(\mathbf x) \\ \vdots \\ f_{P_{n}}(\mathbf x) \\ f_{Q_2}(\mathbf x) \\ \vdots \\ f_{Q_{m}}(\mathbf x)
  \end{bmatrix} =
  \begin{bmatrix}
    \mathbf{f}_{P}(\mathbf x) \\ \mathbf{f}_{Q}(\mathbf x)
  \end{bmatrix} = \mathbf 0,
```
where the first ``n - 1`` equations are defined for PV and PQ buses, while the last ``m - 1`` equations are defined only for PQ buses.

Applying the Newton-Raphson method over power flow equations we have:
```math
  \mathbf{ \Delta x^{(\nu)}} = -\mathbf{J(x^{(\nu)})}^{-1}\mathbf{ f(x^{(\nu)})}
```
```math
  \mathbf {x}^{(\nu + 1)} = \mathbf {x}^{(\nu)} + \mathbf \Delta \mathbf {x}^{(\nu)}.
```
```julia-repl
julia> result.algorithm.jacobian
julia> result.algorithm.increment
julia> result.algorithm.mismatch
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
To conclude, the Newton-Raphson method is based on the equations:
```math
  \begin{bmatrix}
    \mathbf{J_{11}(x^{(\nu)})} &\mathbf{J_{12}(x^{(\nu)})} \\ \mathbf{J_{21}(x^{(\nu)})} &
	   \mathbf{J_{22}(x^{(\nu)})}
  \end{bmatrix}
  \begin{bmatrix}
    \mathbf{\Delta \theta^{(\nu)}} \\ \mathbf{\Delta V^{(\nu)}}
  \end{bmatrix}	+
  \begin{bmatrix}
    \mathbf{f}_{P}(\mathbf x^{(\nu)}) \\ \mathbf{f}_{Q}(\mathbf x^{(\nu)})
  \end{bmatrix} = \mathbf 0.
```

The iteration loop is repeated until the stopping criteria is met. Namely, after each iteration, we compute active power injection mismatch for PQ and PV buses:
```math
  f_{P_i}(\mathbf x^{(\nu)}) = {V}_{i}^{(\nu)}\sum\limits_{j=1}^n {V}_{j}^{(\nu)}(G_{ij}\cos\theta_{ij}^{(\nu)}+B_{ij}\sin\theta_{ij}^{(\nu)}) - {P}_{i},
  \;\;\; i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}},
```
and reactive power injection mismatch for PQ buses:
```math
    f_{Q_i}(\mathbf x^{(\nu)}) = {V}_{i}^{(\nu)}\sum\limits_{j=1}^n {V}_{j}^{(\nu)}(G_{ij}\sin\theta_{ij}^{(\nu)}-B_{ij}\cos\theta_{ij}^{(\nu)}) - {Q}_{i},
    \;\;\; i \in \mathcal{N}_{\text{pq}}.
```
The iteration loop is stopped when the following conditions are met:
```math
  \begin{gather}
    \max \{|f_{P_i}(\mathbf x^{(\nu)})|, i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}} \} < \epsilon \\
    \max \{|f_{Q_i}(\mathbf x^{(\nu)})|, i \in \mathcal{N}_{\text{pq}} \} < \epsilon
  \end{gather}
```
where ``\epsilon`` is predetermined stopping criteria. JuliaGrid stores these values in order to break the iteration loop:
```julia-repl
julia> result.stopping.active
julia> result.stopping.reactive
```

---

## [Fast Newton-Raphson Method](@id inDepthFastNewtonRaphson)