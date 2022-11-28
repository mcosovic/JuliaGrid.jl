# [In-depth Power Flow Solution](@id acPowerFlowAnalysis)

JuliaGrid is based on common network elements and benefits the [unified branch model](@ref branchModelAC) to perform the power flow analysis, which is used for defining load profiles, generator capabilities, voltage specification, contingency analysis, and planning.

To recall, we observe the bus/branch model as a graph ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where the set of nodes ``\mathcal{N} = \{1, \dots, n\}`` represents the set of buses, while the set of edges ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` represents the set of branches of the power network. As shown in section [In-depth AC Model](@ref inDepthACModel), the power flow problem is described by the system of non-linear equations:
```math
    \mathbf {\bar {I}} = \mathbf{Y} \mathbf {\bar {V}},
```
The apparent power injection ``S_i`` into the bus ``i in \mathcal{N}``:


We start from the equation for the apparent power injection ``S_i`` into the bus ``i``:
```math
  	{S}_{i} = \bar{V}_{i}\bar{I}_{i}^*.
```
The apparent power $S_i$ consists of the active power ``P_i`` and reactive power ``Q_i``:
```math
  	{P}_{i} + j{Q}_{i} = \bar{V}_{i}\bar{I}_{i}^*.
```
The energy or apparent power at the bus ``i`` is equal to zero according to Tellegen's theorem:
```math
  \begin{aligned}
    {S}_{i} &= {S}_{\text{g}i}-{S}_{\text{l}i}\\
    {P}_{i} + j{Q}_{i} &= {P}_{\text{g}i} + j{Q}_{\text{g}i} - {P}_{\text{l}i} - j{Q}_{\text{l}i},
  \end{aligned}
```
where ``{S}_{\text{g}i} = {P}_{\text{g}i} + \text{j}{Q}_{\text{g}i}`` denotes a generator power, while ``{S}_{\text{l}i} = {P}_{\text{l}i} + \text{j}{Q}_{\text{l}i}`` indicates a load power. Hence, the active and reactive power equations may be solved independently:
```math
  \begin{aligned}
    {P}_{i} &= {P}_{\text{g}i} - {P}_{\text{l}i}\\
    {Q}_{i} &= {Q}_{\text{g}i} - {Q}_{\text{l}i}.
  \end{aligned}
```

However, **the power flow problem** is described by the **system of non-linear equations**:
```math
    \mathbf {\bar {I}} = \mathbf{Y} \mathbf {\bar {V}},
```
where it is necessary to compute complex voltages ``\bar{V}_{1}, \dots \bar{V}_{n}``. According to the system of equations, for a single bus there are four variables: active power injection ``{P}_{i}``, reactive power injection ``{Q}_{i}``, voltage magnitude ``{V}_{i}`` and voltage angle ``{\theta}_{i}``. Further, to solve the system of equations, two variables for each equation need to be specified. Mathematically, any two variables may be selected, but the choice is dictated by the devices connected to a particular bus. Standard options are summarized in Table below and these options define bus types [[1]](@ref refs).

| Bus Type         | Label            | JuliaGrid | Known                   | Unknown                |
|:-----------------|-----------------:|----------:|------------------------:|-----------------------:|
| Slack generator  | ``V \theta``     | 3         |  ``V_{i},{\theta_{i}}`` | ``P_{i},Q_{i}``        |
| Generator        | PV               | 2         |  ``P_{i},V_{i}``        | ``Q_{i},{\theta_{i}}`` |
| Demand           | PQ               | 1         | ``P_{i},Q_{i}``         | ``V_{i},{\theta_{i}}`` |

Consequently, JuliaGrid operates with sets ``\mathcal{PV}`` and ``\mathcal{PQ}`` that contain PV and PQ buses, respectively, and **exactly one slack bus**. Note that JuliaGrid does not support systems with multiple slack buses.


### [Newton-Raphson Method](@id newtonraphson)
The Newton-Raphson method is generally preferred in power flow calculations because this method has quadratic rate of convergence. The method can have difficulties with initial conditions ("flat start"). The Gauss-Seidel method convergence time increases significantly for large-scale systems and can exhibit convergence problems for systems with high active power transfers. Often, the two algorithms are used complementary, meaning that power flow programs implement both. Gauss-Seidel method is used to rapidly determine an approximate solution from a "flat start", and then the Newton-Raphson method is used to obtain the final accurate solution [[4]](@ref refs).

#### General Properties
Before we apply the Newton-Raphson method to the power flow equations, we review some of its general properties [[2]](@ref refs). First of all, let us consider a real-valued continuously differentiable function ``f(x)``. The Newton-Raphson method provides a good approximation for the root of the function ``f(x)``:
```math
  f(x)= 0.
```

The Newton-Raphson method or Newton's method is essentially based on the Taylor series expansion. Namely, at any point ``x_0 \equiv x^{(0)}``, the function ``f(x)`` is:
```math
  f(x) = f(x^{(0)}) + (x-x^{(0)})\frac{\mathrm d{f(x^{(0)})}}{\mathrm d x} +
  \frac{(x-x^{(0)})^2}{2!}\frac{\mathrm d^2{f(x^{(0)})}}{\mathrm dx^2} + \dots.
```
Neglecting the quadratic and high order terms and taking:
```math
  \Delta{x}^{(0)}=x- x^{(0)},
```
we obtain a linear function (i.e., an affine function) ``f_{\text{a}}(x)`` of the non-linear function ``f(x)`` at the point ``x^{(0)}``:
```math
  f_{\text{a}}(x) = f(x^{(0)}) + \Delta x^{(0)} \frac{\mathrm d{f(x^{(0)})}}{\mathrm d x}.
```
The expression represents a tangent line of the function ``f(x)`` at the point ``[x^{(0)}, f( x^{(0)})]``, as shown in Figure 1. Now, we are interested in determining the root of the equation:
```math
    f(x^{(0)}) + \Delta x^{(0)} \frac{\mathrm d{f(x^{(0)})}}{\mathrm d x} = 0 \;\;\; \to \;\;\;
    \Delta x^{(0)} = -\cfrac{f(x^{(0)})}{\cfrac{\mathrm d{f(x^{(0)})}}{\mathrm d x}}.
```
Thus, we reveal the root ``x^{(1)}`` of the equation ``f_{\text{a}}(x)``:
```math
  x^{(1)} = x^{(0)} + \Delta x^{(0)}.
```
```@raw html
<img src="../../assets/lin_fx.png" class="center"/>
<figcaption>Figure 1: The linearized function of the non-linear function around a given point.</figcaption>
&nbsp;
```

In order to find the root ``x^*`` of the function ``f(x)``, the process is repeated using the Taylor series expansion at the point ``x^{(1)}``, which reveals a new point ``x^{(2)}``, and so on, moving towards a global solution ``x^*``. Therefore, the Newton-Raphson is an iterative method, where we iteratively compute the increments and update solutions:
```math
  \begin{aligned}
    \Delta x^{(\nu)} &= -\cfrac{f(x^{(\nu)})}{\cfrac{\mathrm d{f(x^{(\nu)})}}{\mathrm d x}}\\
    x^{(\nu+1)} &= x^{(\nu)} + \Delta x^{(\nu)},
  \end{aligned}
```
where ``\nu = \{0,1,\dots,\nu_{\max}\}`` is the iteration index and ``\nu_{\max}`` is the maximum number of iterations.

For a complete description of the problem we expand the above model to a function of two variables ``f(x,y)``. The affine function ``f_{\text{a}}(x,y)`` at the point  ``(x^{(0)},y^{(0)})`` is defined:
```math
	f_{\text{a}}(x,y)=f(x^{(0)},y^{(0)})+(x-x^{(0)}) \frac{\mathrm \partial{f(x^{(0)},y^{(0)})}}
	{\mathrm \partial x} +
	(y-y^{(0)}) \frac{\mathrm \partial{f(x^{(0)},y^{(0)})}}{\mathrm \partial y}.
```
Using the matrix notation, the above equation can be written in the form:
```math
  f_{\text{a}}(x,y)=f(x^{(0)},y^{(0)}) +
  \begin{bmatrix}
    \cfrac{\mathrm \partial{f(x^{(0)},y^{(0)})}}{\mathrm \partial x} &
    \cfrac{\mathrm\partial{f(x^{(0)},y^{(0)})}} {\mathrm \partial y}
  \end{bmatrix}
    \begin{bmatrix} \Delta {x}^{(0)}\\ \Delta {y}^{(0)}
  \end{bmatrix},
```
where the Jacobian matrix is:
```math
  \mathbf{J}(x^{(0)},y^{(0)}) =
  \begin{bmatrix}
    \cfrac{\mathrm \partial{f(x^{(0)},y^{(0)})}}{\mathrm \partial x} &
    \cfrac{\mathrm\partial{f(x^{(0)},y^{(0)})}} {\mathrm \partial y}
  \end{bmatrix}.
```

Although somewhat trivial, the above example gives us a good intuition and provides an easy transition to the ``n``-dimensional case:
```math
  \begin{aligned}
    \mathbf{f(x)} &=\left[f_1(\mathbf{x}),\dots, f_n(\mathbf{x}) \right]^T\\
    \mathbf{x} &= \left[x_1,\dots, x_n \right]^T.
  \end{aligned}
```

The linearization of the function ``\mathbf f(\mathbf x)`` at the point ``\mathbf x^{(\nu)}`` is defined by the Taylor expansion:
```math
  \mathbf {f}_{\text{a}}(\mathbf x)=\mathbf f(\mathbf x^{(\nu)})+\mathbf J(\mathbf x^{(\nu)}) \mathbf \Delta \mathbf {x}^{(\nu)}.
```
By taking ``\mathbf {f}_{\text{a}}(\mathbf x) = \mathbf 0``, the vector of increments can be obtained by solving:
```math
   \mathbf \Delta \mathbf {x}^{(\nu)} = -\mathbf J(\mathbf x^{(\nu)})^{-1} \mathbf f(\mathbf x^{(\nu)}),
```
that is, written in the extended form:
```math
  \begin{bmatrix} \Delta {x_{1}^{(\nu)}} \\  \vdots \\  \Delta {x_{n}^{(\nu)}} \end{bmatrix} =
  -\begin{bmatrix}
    \cfrac{\mathrm \partial{f_{1}(\mathbf x^{(\nu)})}}{\mathrm \partial x_{1}} &
    \dots &
    \cfrac{\mathrm \partial{f_{1}(\mathbf x^{(\nu)})}}{\mathrm \partial x_{n}}\\
    \vdots\\
    \cfrac{\mathrm \partial{f_{n}(\mathbf x^{(\nu)})}}{\mathrm \partial x_{1}} &
    ... &
    \cfrac{\mathrm \partial{f_{n}(\mathbf x^{(\nu)})}}{\mathrm \partial x_{n}}
  \end{bmatrix}^{-1}
  \begin{bmatrix} f_{1}(\mathbf x^{(\nu)})\\ \vdots\\ f_{n}(\mathbf x^{(\nu)}) \end{bmatrix}.
```
Then, we obtain the solution:
```math
  \mathbf {x}^{(\nu + 1)}=   \mathbf {x}^{(\nu)} + \mathbf \Delta \mathbf {x}^{(\nu)}.
```

#### Newton-Raphson Applied to the Power Flow Equations
In the following, we observe a power system with the set of buses ``\mathcal{H} = \{1,\dots,n \}``. Without loss of generality, we assume that the slack bus is the first bus, followed by the set of PQ buses and the set of PV buses:
```math
  \mathcal{H} =  \{V \theta\} \cup \mathcal{PQ} \cup \mathcal{PV},
```
where:
```math
  \begin{aligned}
    \mathcal{PQ} &= \{2, \dots, m\} \\
    \mathcal{PV} &= \{m + 1,\dots, n\},
  \end{aligned}
```
where ``m = n_{\text{pq}} + 1``, and ``n_{\text{pq}} = |\mathcal{PQ}|`` is the number of PQ buses.

Let us observe the vector given in the polar coordinate system:
```math
  \mathbf x_{\text{sv}} = [\theta_1,\dots,\theta_n,V_1,\dots,V_n]^T.
```
In general, the vector ``\mathbf x_{\text{sv}} \in \mathbb{R}^{2n}`` contains elements whose values are known: (i) voltage angle ``\theta_1`` and magnitude ``V_1`` at the slack bus; (ii) voltage magnitude at PV buses ``V_i, i \in \mathcal{PV}``. More precisely, the number of unknowns is ``n_{\text{u}} = 2n-n_{\text{pv}} - 2``, where ``n_{\text{pv}} = |\mathcal{PV}|`` is the number of PV buses.


Thus, we observe the state vector ``\mathbf x \in \mathbb{R}^{n_{\text{u}}}`` and associated vector of increments ``\mathbf \Delta \mathbf x \in \mathbb{R}^{n_{\text{u}}}``:
```math
  \mathbf x =
  \begin{bmatrix}
    \bm \theta \\ \mathbf V
  \end{bmatrix}; \;\;\;
  \mathbf \Delta \mathbf x =
  \begin{bmatrix}
    \mathbf \Delta \bm \theta \\ \mathbf \Delta \mathbf V
  \end{bmatrix},
```
where:
```math
  \begin{aligned}
    \bm \theta &= [\theta_2,\dots,\theta_n]^T; \;\;\;\;\;\; \mathbf \Delta \bm \theta = [\Delta \theta_2,\dots,\Delta \theta_n]^T \\
    \mathbf V &= [V_2,\dots,V_{m}]^T; \;\;\; \mathbf \Delta \mathbf V = [\Delta V_2,\dots,\Delta V_{m}]^T.
  \end{aligned}
```

The apparent power at the bus ``i \in \mathcal{H}`` is a function of the complex bus voltage ``S_i=f(\bar {V}_{i})``. Hence, the real and imaginary components of the apparent power define the active and reactive power injection expressions:
```math
  \begin{aligned}
    {P}_{i} &={V}_{i}\sum\limits_{j=1}^n {V}_{j}
    (G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij})\\
    {Q}_{i} &={V}_{i}\sum\limits_{j=1}^n {V}_{j}
    (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}).
	\end{aligned}
```
Based on the above equations, it is possible to define the active power injection functions for PV and PQ buses:
```math
    f_{P_i}(\mathbf x) = {V}_{i}\sum\limits_{j=1}^n {V}_{j}(G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij}) - {P}_{i} = 0,
    \;\;\; i \in \mathcal{PV} \cup \mathcal{PQ},
```
and reactive power injection functions for PQ buses:
```math
    f_{Q_i}(\mathbf x) = {V}_{i}\sum\limits_{j=1}^n {V}_{j}(G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}) - {Q}_{i} = 0,
    \;\;\; i \in \mathcal{PQ}.
```

Functions ``f_{P_i}(\mathbf x)`` and ``f_{Q_i}(\mathbf x)`` are called active and reactive mismatch, respectively, and are often marked as ``\Delta P_i(\mathbf x)`` and ``\Delta Q_i(\mathbf x)``. The first terms on the right-hand side represents power injections into the bus ``i``, while the second term is constant and represents active and reactive powers from generators and loads connected to the bus ``i``. Thus, the power flow problem is described by the system of equations:
```math
  \mathbf{f(x)} =
  \begin{bmatrix}
      f_{P_2}(\mathbf x) \\ \vdots \\ f_{P_{n}}(\mathbf x) \\ f_{Q_2}(\mathbf x) \\ \vdots \\ f_{Q_{m}}(\mathbf x)
  \end{bmatrix} =
  \begin{bmatrix}
    \mathbf{f}_{P}(\mathbf x) \\ \mathbf{f}_{Q}(\mathbf x)
  \end{bmatrix} = \mathbf 0,
```
where the first ``n - 1`` equations are defined for PV and PQ buses, while the last ``m-1`` equations are defined only for PQ buses.

Applying the Newton-Raphson method over power flow equations we have:
```math
	\mathbf{J(x^{(\nu)})}\mathbf{ \Delta x^{(\nu)}}+\mathbf{ f(x^{(\nu)})}=0 \;\;\; \to \;\;\;
  \mathbf{ \Delta x^{(\nu)}} = -\mathbf{J(x^{(\nu)})}^{-1}\mathbf{ f(x^{(\nu)})}
```
```math
  \mathbf {x}^{(\nu + 1)} = \mathbf {x}^{(\nu)} + \mathbf \Delta \mathbf {x}^{(\nu)},
```

where the Jacobian matrix ``\mathbf{J(x^{(\nu)})} \in \mathbb{R}^{n_{\text{u}} \times n_{\text{u}}}`` is:
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