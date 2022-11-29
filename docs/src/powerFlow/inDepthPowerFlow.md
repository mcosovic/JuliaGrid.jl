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
The Newton-Raphson method is generally preferred in power flow calculations because this method has quadratic rate of convergence. First of all, the Newton-Raphson method provides a good approximation for the roots of the system of non-linear equations:
```math
  \mathbf{f}(\mathbf{x}) = \mathbf{0}.
```
Hence, the Newton-Raphson method solves the system of non-linear equations ``\mathbf{f}(\mathbf{x})``, and reveals bus voltage magnitudes and angles ``\mathbf{x}``. According to bus types, some buses have known values of bus voltage magnitudes and angles:
* at the slack bus ``i \in \mathcal{N}_{\text{sb}}`` voltage angle ``\theta_i`` and magnitude ``V_i`` are known;
* at PV buses ``i \in \mathcal{N}_{\text{pv}}`` voltage magnitude ``V_i`` is known.
Thus, we observe the state vector ``\mathbf x``:
```math
  \mathbf x =
  \begin{bmatrix}
    \bm \theta \\ \mathbf V
  \end{bmatrix},
```
where ``\bm \theta \in \mathbb{R}^{n-1}`` and ``\mathbf V \in \mathbb{R}^{n_{\text{pq}}}``, while ``n_{\text{pq}} = |\mathcal{N}_{\text{pq}}|`` is the number of PQ buses.


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

Functions ``f_{P_i}(\mathbf x)`` and ``f_{Q_i}(\mathbf x)`` are called active and reactive mismatch, respectively, and are often marked as ``\Delta P_i(\mathbf x)`` and ``\Delta Q_i(\mathbf x)``. The first terms on the right-hand side represents power injections into the bus ``i``, while the second term is constant and is obtained based on the active and reactive powers of the generators that supply the bus ``i`` and active and reactive powers demanded by consumers at the bus ``i``.

---

#### Implementation Aspects of the Newton-Raphson Method
To solve the AC power flow analysis and find the bus voltage magnitudes and angles using Newton-Raphson method, JuliaGrid provides the following sequence of functions:
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

That is, applying the Newton-Raphson method over power flow equations we have:
```math
  \mathbf{ \Delta x^{(\nu)}} = -\mathbf{J(x^{(\nu)})}^{-1}\mathbf{ f(x^{(\nu)})}.
```
```julia-repl
julia> result.algorithm.increment
julia> result.algorithm.jacobian
julia> result.algorithm.mismatch
```
After that, we update the solution:
```math
  \mathbf {x}^{(\nu + 1)} = \mathbf {x}^{(\nu)} + \mathbf \Delta \mathbf {x}^{(\nu)}.
```
```julia-repl
julia> result.bus.voltage.angle
julia> result.bus.voltage.magnitude
```
The current number of iterations ``\nu`` can be accessed using the command:
```julia-repl
julia> result.algorithm.iteration.number
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
    \max \{|f_{P_i}(\mathbf x^{(\nu)})|, i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}} \} < \epsilon \\
    \max \{|f_{Q_i}(\mathbf x^{(\nu)})|, i \in \mathcal{N}_{\text{pq}} \} < \epsilon
```
where ``\epsilon`` is predetermined stopping criteria. JuliaGrid stores these values in order to break the iteration loop:
```julia-repl
julia> result.stopping.active
julia> result.stopping.reactive
```

---

## [Fast Newton-Raphson Method](@id inDepthFastNewtonRaphson)

The convergence of the fast Newton-Raphson method is in fact slower than the Newton-Raphson method, but often, shorter solution time for the updates compensates for slower convergence, resulting in overall shorter solution time. For not too heavily loaded systems a shorter overall solution time is almost always obtained. It should be noted that if the algorithm converges, it converges to a correct solution [[2]](@ref refs).

The fast Newton-Raphson method is based on the decoupling of the power flow equations. Namely, in transmission grids a strong coupling can be found between active powers and voltage angles, and between reactive powers and voltage magnitudes. In order to obtain decoupling, two conditions are assumed to have been satisfied: first, the resistances ``r_{ij}`` of the branches are small with respect to their respective reactances ``x_{ij}`` and, second, the angle differences are small ``\theta_{ij} \approx 0`` [[5]](@ref refs). Respectively, we start from the equation:
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
where, for simplicity, we drop the iteration index. Thus, decoupled system can be written as:
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
True benefits from these equations is that Jacobian matrices ``\mathbf{B}_1`` and ``\mathbf{B}_2`` are constant and should be formed only once. Note that no approximations have been introduced to the functions ``\mathbf{f}_{P}(\mathbf x)`` or ``\mathbf{f}_{Q}(\mathbf x)``, only in the way we calculate the increments of the state variables [[2]](@ref refs). Consequently, we still use:
```math
  \begin{aligned}
    f_{P_i}(\mathbf x) &= {V}_{i}\sum\limits_{j=1}^n {V}_{j}(G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij}) - {P}_{i} = 0,
    \;\;\; i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}}\\
    f_{Q_i}(\mathbf x) &= {V}_{i}\sum\limits_{j=1}^n {V}_{j} (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}) - {Q}_{i} = 0,
    \;\;\; i \in \mathcal{N}_{\text{pq}}.
  \end{aligned}
```

It is now possible to define XB and BX versions of the fast Newton-Raphson method.

#### XB Version
The resistance ``r_{ij}``, shunt susceptance ``\Im \{ y_{\text{sh}i} \}``, charging susceptance ``\Im \{ y_{\text{s}ij} \}`` and transformer tap ratio magnitude ``\tau_{ij}`` are ignored while forming the matrix ``\mathbf{B}_1``. The transformer phase shift angle ``\phi_{ij}`` is ignored while building the matrix ``\mathbf{B}_2``. This version is the standard fast Newton-Raphson method and has excellent convergence properties for usual cases.

To initialize the XB version of the fast Newton-Raphson method, we can use:
```julia-repl
system = powerSystem("case14.h5")
acModel!(system)

result = fastNewtonRaphsonXB(system)
```

#### BX Version
The shunt susceptance ``\Im \{ y_{\text{sh}i} \}``, charging susceptance ``\Im \{ y_{\text{s}ij} \}`` and transformer tap ratio magnitude ``\tau_{ij}`` are ignored while forming the matrix ``\mathbf{B}_1``. The resistance ``r_{ij}`` and transformer phase shift angle ``\phi_{ij}`` are ignored while building the matrix ``\mathbf{B}_2``. For usual cases, the iteration count will be similar to the XB scheme, but for systems with a few or with general high ``r_{ij}/x_{ij}`` ratios the number of iterations needed to solve the power flow is considerably smaller than the number of the XB scheme [[5]](@ref refs).

To initialize the BX version of the fast Newton-Raphson method, we can use:
```julia-repl
system = powerSystem("case14.h5")
acModel!(system)

result = fastNewtonRaphsonBX(system)
```

#### Implementation Aspects of the Fast Newton-Rapshson Method
In the beginning, we evaluate matrices ``\mathbf{B}_1`` and ``\mathbf{B}_2`` related with active and reactive power equations, respectively. These matrices can be accessed using commands:
```julia-repl
julia> result.algorithm.active.jacobian
julia> result.algorithm.reactive.jacobian
```

Then, JuliaGrid uses the L[U factorization](https://docs.julialang.org/en/v1/stdlib/LinearAlgebra/#LinearAlgebra.lu) of matrices ``\mathbf{B}_1`` and ``\mathbf{B}_2`` to reveal solutions through iterations:
```julia-repl
julia> result.algorithm.active.lower
julia> result.algorithm.active.upper
julia> result.algorithm.active.right
julia> result.algorithm.active.left
julia> result.algorithm.active.scaling

julia> result.algorithm.reactive.lower
julia> result.algorithm.reactive.upper
julia> result.algorithm.reactive.right
julia> result.algorithm.reactive.left
julia> result.algorithm.reactive.scaling
```

Finally, to solve the AC power flow analysis and find the bus voltage magnitudes and angles, JuliaGrid provides the following sequence of functions:
```julia-repl
stopping = result.algorithm.iteration.stopping
for i = 1:10
    newtonRaphson!(system, result)
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
```julia-repl
julia> result.bus.voltage.magnitude
```

Then, we compute active power injection mismatch for PQ and PV buses:
```math
  {h}_{P_i}(\bm \theta^{(\nu+1)}, \mathbf V^{(\nu+1)}) =
  \sum\limits_{j=1}^n {V}_{j}^{(\nu+1)}(G_{ij}\cos\theta_{ij}^{(\nu+1)}+B_{ij}\sin\theta_{ij}^{(\nu+1)}) - \cfrac{{P}_{i}}{{V}_{i}^{(\nu+1)}},
  \;\;\;  i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}},
```
and reactive power injection mismatch for PQ buses:
```math
    {h}_{Q_i}(\bm \theta^{(\nu+1)}, \mathbf V^{(\nu+1)}) =
    \sum\limits_{j=1}^n {V}_{j}^{(\nu+1)} (G_{ij}\sin\theta_{ij}^{(\nu)}-B_{ij}\cos\theta_{ij}^{(\nu+1)}) - \cfrac{{Q}_{i}}{{V}_{i}^{(\nu+1)}},
    \;\;\; i \in \mathcal{N}_{\text{pq}}.
```
The iteration loop is stopped when the following conditions are met:
```math
    \max \{|f_{P_i}(\mathbf x^{(\nu)})|, i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}} \} < \epsilon \\
    \max \{|f_{Q_i}(\mathbf x^{(\nu)})|, i \in \mathcal{N}_{\text{pq}} \} < \epsilon
```
where ``\epsilon`` is predetermined stopping criteria. JuliaGrid stores these values in order to break the iteration loop:
```julia-repl
julia> result.stopping.active
julia> result.stopping.reactive
```

---

