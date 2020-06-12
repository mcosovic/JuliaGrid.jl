#  Power Flow

JuliaGrid is based on common network elements and benefits the [unified branch model](@ref branchmodel) to perform the power flow analysis, which is used for defining load profiles, generator capabilities, voltage specification, contingency analysis, and planning. We advise the reader to read the section [Network Equations](@ref networkequationpage) which represents a requirement for the analysis given here.

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

---

## [AC Power Flow](@id acpowerflow)

To solve the AC power flow problem three different methods are available:
* [Gauss-Seidel](@ref gaussseidel),
* [Newton-Raphson](@ref newtonraphson),
* [Fast Newton-Raphson](@ref fastnewtonraphson) with XB and BX schemes.

By default, the AC power flow methods solve the system of non-linear equations and reveal complex bus voltages ignoring any limits. However, JuliaGrid integrates **generator reactive power limits** in all available methods. More precisely, after the algorithm converges, all generators that violated reactive power limits are placed at their limits, and corresponding PV buses are converted to PQ. This procedure is repeated until there are no more violations [[2]](@ref refs).

### [Power Flow Analysis](@id acpfanalysis)

JuliaGrid uses the above methods to compute **complex bus voltages**, and subsequently, calculates other electrical quantities related to the AC power flow analysis. In the rest of this part, we define electrical quantities evaluated by the JuliaGrid.

Electrical quantities related to the bus ``i \in \mathcal{H}``:
* **Active and reactive power injection** can be obtained using the expression for complex apparent power:
```math
    {S}_{i} =\bar{V}_{i}\bar{I}_{i}^* = \bar{V}_{i} \sum\limits_{j \in \mathcal{H}_i} {Y}_{ij}^* \bar{V}_{j}^*; \;\;\;
    P_i = \Re{\{S}_{i}\}; \;\;\;
    Q_i = \Im{\{S}_{i}\}.
```
* **Total active and reactive generation** are determined using Tellegen's theorem:  
```math
    {S}_{i} = {S}_{\text{g}i}-{S}_{\text{l}i}; \;\;\;
    P_{\text{g}i} = \Re{\{S}_{i}\} + \Re{\{S}_{\text{l}i}\}; \;\;\;
    Q_{\text{g}i} = \Im{\{S}_{i}\} + \Im{\{S}_{\text{l}i}\}.
```  
* **Active and reactive power consumed by the shunt element** are obtained using the complex apparent power:
```math
  {S}_{\text{sh}i} =\bar{V}_{i}\bar{I}_{\text{sh}i}^* = {y}_{\text{sh}i}^*|\bar{V}_{i}|^2; \;\;\;
  {P}_{\text{sh}i} = \Re{\{S}_{\text{sh}i}\}; \;\;\;
  {Q}_{\text{sh}i} = \Im{\{S}_{\text{sh}i}\}.
```

Electrical quantities related to the branch ``(i,j) \in \mathcal{E}``:
* **Complex currents** from/to buses can be obtained using the [unified branch model](@ref branchmodel):
```math
\begin{aligned}
    \bar{I}_{ij} &= C_{ij} \bar{V}_{i} + D_{ij} \bar{V}_{j}\\
    \bar{I}_{ji} &= E_{ij} \bar{V}_{i} + F_{ij} \bar{V}_{j}.
  \end{aligned}  
```
* **Active and reactive power flows** are determined using the complex apparent power flows:
```math
  \begin{aligned}
    {S}_{ij} &= \bar{V}_{i}\bar{I}_{ij}^*; \;\;\; P_{ij} = \Re{\{S}_{ij}\}; \;\;\; Q_{ij} = \Im{\{S}_{ij}\}\\
    {S}_{ji} &= \bar{V}_{j}\bar{I}_{ji}^*; \;\;\; P_{ji} = \Re{\{S}_{ji}\}; \;\;\; Q_{ji} = \Im{\{S}_{ji}\}.
  \end{aligned}  
```
* **Branch active and reactive power losses** at the branch series impedance ``z_{ij}`` are obtained using the complex current through impedance ``z_{ij}``:
```math
  \bar{I}_{\text{b}ij} = y_{ij} (\alpha_{ij}\bar{V}_{i} - \bar{V}_{j}); \;\;\;
  P_{\text{loss}ij} = r_{ij}|\bar{I}_{\text{b}ij}|^2; \;\;\;
  Q_{\text{loss}ij} = x_{ij}|\bar{I}_{\text{b}ij}|^2.
```
* **Reactive power injected by the total branch susceptance** can be obtained using:
```math
    Q_{\text{ch}ij} = b_{\text{s}i} (|\alpha_{ij}\bar{V}_{i}|^2 - |\bar{V}_{j}|^2).
```

---

### [Gauss-Seidel Method](@id gaussseidel)
Defining the injected current into the bus ``i \in \mathcal{H}`` as:
```math
	\bar{I}_{i} = \frac{{P}_{i} - j{Q}_{i}}{\bar{V}_{i}^*},
```
the power flow problem which is described by the system of non-linear equations:
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
The Gauss-Seidel method directly solves the above system of equations, albeit with very slow convergence, almost linearly with the size of the system. Consequently, this method needs many iterations to achieve the desired solution [[3]](@ref refs). In general, the Gauss-Seidel method is based on the above system of equations, where the set of non-linear equations has ``n`` complex equations, and one of these equations describes the slack bus. Consequently, one of these equations can be removed resulting in the power flow problem with ``n-1`` equations.

In the following, we observe a power system with sets ``\mathcal{PV}`` and ``\mathcal{PQ}`` that contain PV and PQ buses, respectively, and exactly one slack bus ``\{V \theta\}``:
```math   	
  \mathcal{H} = \mathcal{PV} \cup \mathcal{PQ} \cup \{V \theta\}.
```
The method starts with initial complex bus voltages ``\bar{V}_i^{(0)}, i \in \mathcal{H}``. The iteration scheme first computes complex bus voltages for PQ buses:
```math
    \bar{V}_{i}^{(\nu + 1)} =
    \cfrac{1}{{Y}_{ii}} \Bigg(\cfrac{{P}_{i} - j{Q}_{i}}{\bar{V}_{i}^{*(\nu)}} -
    \sum\limits_{\substack{j = 1}}^{i - 1} {Y}_{ij}\bar{V}_{j}^{(\nu + 1)} -
    \sum\limits_{\substack{j = i + 1}}^{n} {Y}_{ij}\bar{V}_{j}^{(\nu)}\Bigg),
    \;\;\; i \in \mathcal{PQ},
```
where ``\nu = \{0,1,\dots,\nu_{\max}\}`` is the iteration index and ``\nu_{\max}`` is the number of iterations. Then, the solution for PV buses are obtained in two steps: we first determine the reactive power injection, then the complex bus voltage is updated:
```math
  \begin{aligned}
    Q_i^{(\nu+1)} &=
    -\Im \left\{ \bar{V}_{i}^{*(\nu + 1)} \sum\limits_{j=1}^n {Y}_{ij}\bar{V}_{j}^{(\nu+1)}\right\}, \;\;\; i \in \mathcal{PV} \\
    \bar{V}_{i}^{(\nu + 1)} &:=
    \cfrac{1}{{Y}_{ii}} \Bigg(\cfrac{{P}_{i} - j{Q}_{i}^{(\nu + 1)}}{\bar{V}_{i}^{*(\nu + 1)}}-
    \sum\limits_{\substack{j = 1,\;j \neq i}}^{n} {Y}_{ij}\bar{V}_{j}^{(\nu + 1)} \Bigg), \;\;\; i \in \mathcal{PV}.
  \end{aligned}
```
Obtained voltage magnitude is not equal to the magnitude specified for the PV bus. Thus, it is necessary to perform the voltage correction:
```math
      \bar{V}_{i}^{(\nu+1)} := {V}_{i}^{(0)} \cfrac{\bar{V}_{i}^{(\nu+1)}}{{V}_{i}^{(\nu+1)}}, \;\;\; i \in \mathcal{PV}.
```

The iteration loop is repeated until the stopping criteria is met. Namely, after one iteration loop is done, we compute active power injection mismatch for PQ and PV buses:
```math
    \Delta P_i^{(\nu + 1)} = \Re\{\bar{V}_i^{(\nu + 1)} \bar{I}_i^{*(\nu + 1)}\} - P_i, \;\;\; i \in \mathcal{PQ} \cup \mathcal{PV},
```
and reactive power injection mismatch for PQ buses:
```math
  \Delta Q_i^{(\nu + 1)} = \Im\{\bar{V}_i^{(\nu + 1)} \bar{I}_i^{*(\nu + 1)}\} - Q_i, \;\;\; i \in \mathcal{PQ}.
```
The iteration loop is stopped when conditions are met:
```math
  \begin{aligned}
    |\Delta P_i^{(\nu + 1)}| &< \epsilon, \;\;\; i \in \mathcal{PQ} \cup \mathcal{PV} \\
    |\Delta Q_i^{(\nu + 1)}| &< \epsilon, \;\;\; i \in \mathcal{PQ},
  \end{aligned}  
```
where ``\epsilon`` is a predetermined stopping criteria.

---

### [Newton-Raphson Method](@id newtonraphson)
The Newton-Raphson method is generally preferred in power flow calculations because this method has quadratic rate of convergence. The method can have difficulties with initial conditions (''flat start''). The Gauss-Seidel method convergence time increases significantly for large-scale systems and can exhibit convergence problems for systems with high active power transfers. Often, the two algorithms are used complementary, meaning that power flow programs implement both. Gauss-Seidel method is used to rapidly determine an approximate solution from a ''flat start'', and then the Newton-Raphson method is used to obtain the final accurate solution [[4]](@ref refs).

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

In order to find the root ``x*`` of the function ``f(x)``, the process is repeated using the Taylor series expansion at the point ``x^{(1)}``, which reveals a new point ``x^{(2)}``, and so on, moving towards a global solution ``x^*``. Therefore, the Newton-Raphson is an iterative method, where we iteratively compute the increments and update solutions:
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
  \mathbf {f}_{\text{a}}(\mathbf x)=\mathbf f(\mathbf x^{(\nu)})+\mathbf J(\mathbf x^{(\nu)}) \Delta \mathbf {x}^{(\nu)}.                                        
```
By taking ``\mathbf {f}_{\text{a}}(\mathbf x) = \mathbf 0``, the vector of increments can be obtained by solving:
```math
   \Delta \mathbf {x}^{(\nu)} = -\mathbf J(\mathbf x^{(\nu)})^{-1} \mathbf f(\mathbf x^{(\nu)}),                                     
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
  \mathbf {x}^{(\nu + 1)}=   \mathbf {x}^{(\nu)} + \Delta \mathbf {x}^{(\nu)}.                                     
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
    \mathbf V &= [V_2,\dots,V_{m}]^T; \;\;\; \mathbf \Delta V = [\Delta V_2,\dots,\Delta V_{m}]^T.
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
  \mathbf{ \Delta x^{(\nu)}} = -\mathbf{J(x^{(\nu)})}^{-1}\mathbf{ f(x^{(\nu)})}\\
  \mathbf {x}^{(\nu + 1)}=   \mathbf {x}^{(\nu)} + \Delta \mathbf {x}^{(\nu)},
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

As for the [Gauss-Sedel method](@ref gaussseidel), the iteration loop is repeated until the stopping criteria is met. Namely, after each iteration, we compute active power injection mismatch for PQ and PV buses:
```math
  f_{P_i}(\mathbf x^{(\nu)}) = {V}_{i}^{(\nu)}\sum\limits_{j=1}^n {V}_{j}^{(\nu)}(G_{ij}\cos\theta_{ij}^{(\nu)}+B_{ij}\sin\theta_{ij}^{(\nu)}) - {P}_{i},
  \;\;\; i \in \mathcal{PV} \cup \mathcal{PQ},
```
and reactive power injection mismatch for PQ buses:
```math
    f_{Q_i}(\mathbf x^{(\nu)}) = {V}_{i}^{(\nu)}\sum\limits_{j=1}^n {V}_{j}^{(\nu)}(G_{ij}\sin\theta_{ij}^{(\nu)}-B_{ij}\cos\theta_{ij}^{(\nu)}) - {Q}_{i},
    \;\;\; i \in \mathcal{PQ}.    
```
The iteration loop is stopped when the following conditions are met:
```math
  \begin{aligned}
    |f_{P_i}(\mathbf x^{(\nu)})| & < \epsilon, \;\;\; i \in \mathcal{PQ} \cup \mathcal{PV} \\
    |f_{Q_i}(\mathbf x^{(\nu)})| & < \epsilon, \;\;\; i \in \mathcal{PQ},
  \end{aligned}  
```
where ``\epsilon`` is predetermined stopping criteria.

---

### [Fast Newton-Raphson Method](@id fastnewtonraphson)
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
    {f}_{P_n}(\mathbf x) &= {V}_{n}B_{n2} \Delta \theta_2 + \cdots + {V}_{n}B_{nn} \Delta \theta_n,
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
True benefits from these equations is that Jacobian matrices ``\mathbf{B}_1`` and ``\mathbf{B}_2`` are constant and should be formed only once. Note that no approximations have been introduced to the functions ``\mathbf{f}_{P}(\mathbf x)`` or ``\mathbf{f}_{Q}(\mathbf x)``, only in the way we calculate the increments of the state variables [[2]](@ref refs). Consequently, we obtain:
```math
  \begin{aligned}
    f_{P_i}(\mathbf x) &= {V}_{i}\sum\limits_{j=1}^n {V}_{j}(G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij}) - {P}_{i} = 0,
    \;\;\; i \in \mathcal{PV} \cup \mathcal{PQ}\\
    f_{Q_i}(\mathbf x) &= {V}_{i}\sum\limits_{j=1}^n {V}_{j} (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}) - {Q}_{i} = 0,
    \;\;\; i \in \mathcal{PQ}.    
  \end{aligned}    
```

It is now possible to define XB and BX schemes of the fast Newton-Raphson method:
* XB scheme: The resistance ``r_{ij}``, shunt susceptance ``\Im \{ y_{\text{sh}i} \}``, charging susceptance ``\Im \{ y_{\text{s}ij} \}`` and transformer tap ratio magnitude ``\tau_{ij}`` are ignored while forming the matrix ``\mathbf{B}_1``. The transformer phase shift angle ``\phi_{ij}`` is ignored while building the matrix ``\mathbf{B}_2``. This version is the standard fast Newton-Raphson method and has excellent convergence properties for usual cases.  
* BX scheme: The shunt susceptance ``\Im \{ y_{\text{sh}i} \}``, charging susceptance ``\Im \{ y_{\text{s}ij} \}`` and transformer tap ratio magnitude ``\tau_{ij}`` are ignored while forming the matrix ``\mathbf{B}_1``. The resistance ``r_{ij}`` and transformer phase shift angle ``\phi_{ij}`` are ignored while building the matrix ``\mathbf{B}_2``. For usual cases, the iteration count will be similar to the XB scheme, but for systems with a few or with general high ``r_{ij}/x_{ij}`` ratios the number of iterations needed to solve the power flow is considerably smaller than the number of the XB scheme [[5]](@ref refs).


In the following, we will describe the implementation aspects of the fast Newton-Rapshson method. In the beginning, we evaluate and invert matrices ``\mathbf{B}_1`` and ``\mathbf{B}_2``. More precisely, JuliaGrid uses the LU factorization of matrices ``\mathbf{B}_1`` and ``\mathbf{B}_2`` to reveal solutions through iterations.

The fast Newton-Raphson method first solves the equation:
```math
  \mathbf{\Delta \bm \theta}^{(\nu)} = \mathbf{B}_1^{-1} \mathbf{h}_{P}(\bm \theta^{(\nu)}, \mathbf V^{(\nu)}),
```
and updates the solution:
```math
  \bm{\theta}^{(\nu+1)} = \bm{\theta}^{(\nu)} + {\mathbf \Delta \bm \theta}^{(\nu)}.
```
Then, we compute active power injection mismatch for PQ and PV buses:
```math
  {h}_{P_i}(\bm \theta^{(\nu+1)}, \mathbf V^{(\nu)}) = \sum\limits_{j=1}^n {V}_{j}^{(\nu)}(G_{ij}\cos\theta_{ij}^{(\nu+1)}+B_{ij}\sin\theta_{ij}^{(\nu+1)})
  - \cfrac{{P}_{i}}{{V}_{i}^{(\nu)}}, \;\;\; i \in \mathcal{PV} \cup \mathcal{PQ},
```
and reactive power injection mismatch for PQ buses:
```math
    {h}_{Q_i}(\bm \theta^{(\nu+1)}, \mathbf V^{(\nu)}) = \sum\limits_{j=1}^n {V}_{j}^{(\nu+1)}(G_{ij}\sin\theta_{ij}^{(\nu)}-B_{ij}\cos\theta_{ij}^{(\nu+1)})
    -\cfrac{{Q}_{i}}{{V}_{i}^{(\nu)}}, \;\;\; i \in \mathcal{PQ}.    
```
The iteration loop is stopped if the following conditions are satisfied:
```math
  \begin{aligned}
    \left|{h}_{P_i}(\bm \theta^{(\nu+1)}, \mathbf V^{(\nu)}) \right| & < \epsilon, \;\;\; i \in \mathcal{PQ} \cup \mathcal{PV} \\
    \left|{h}_{Q_i}(\bm \theta^{(\nu+1)}, \mathbf V^{(\nu)}) \right| & < \epsilon, \;\;\; i \in \mathcal{PQ},
  \end{aligned}  
```
where ``\epsilon`` is predetermined stopping criteria.

The fast Newton-Raphson method further solves the equation:
```math
  \mathbf{\Delta V}^{(\nu)} = \mathbf{B}_2^{-1} \mathbf{h}_{Q}(\bm \theta^{(\nu + 1)}, \mathbf V^{(\nu)}),
```
and updates the solution:
```math
  \mathbf{V}^{(\nu+1)} = \mathbf{V}^{(\nu)} + \mathbf{\Delta V}^{(\nu)}.
```  
Then, we compute active power injection mismatch for PQ and PV buses:
```math
  {h}_{P_i}(\bm \theta^{(\nu+1)}, \mathbf V^{(\nu+1)}) =
  \sum\limits_{j=1}^n {V}_{j}^{(\nu+1)}(G_{ij}\cos\theta_{ij}^{(\nu+1)}+B_{ij}\sin\theta_{ij}^{(\nu+1)}) - \cfrac{{P}_{i}}{{V}_{i}^{(\nu+1)}},
  \;\;\; i \in \mathcal{PV} \cup \mathcal{PQ},
```
and reactive power injection mismatch for PQ buses:
```math
    {h}_{Q_i}(\bm \theta^{(\nu+1)}, \mathbf V^{(\nu+1)}) =
    \sum\limits_{j=1}^n {V}_{j}^{(\nu+1)} (G_{ij}\sin\theta_{ij}^{(\nu)}-B_{ij}\cos\theta_{ij}^{(\nu+1)}) - \cfrac{{Q}_{i}}{{V}_{i}^{(\nu+1)}},
    \;\;\; i \in \mathcal{PQ}.    
```
The iteration loop is stopped if the following conditions are satisfied:
```math
  \begin{aligned}
    \left|{h}_{P_i}(\bm \theta^{(\nu+1)}, \mathbf V^{(\nu+1)}) \right| & < \epsilon, \;\;\; i \in \mathcal{PQ} \cup \mathcal{PV} \\
    \left|{h}_{Q_i}(\bm \theta^{(\nu+1)}, \mathbf V^{(\nu+1)}) \right| & < \epsilon, \;\;\; i \in \mathcal{PQ}.
  \end{aligned}  
```

---

## [DC Power Flow](@id dcpowerflow)
The DC model is obtained by linearisation of the non-linear model. In the typical operating conditions, the difference of bus voltage angles between adjacent buses ``(i,j) \in \mathcal{E}`` is very small ``\theta_{i}-\theta_{j} \approx 0``, which implies ``\cos \theta_{ij}\approx 1`` and ``\sin \theta_{ij} \approx \theta_{ij}``. Further, all bus voltage magnitudes are ``V_i \approx 1``, ``i \in \mathcal{H}``, and all shunt susceptance elements and branch resistances can be neglected. This implies that the DC model ignores the reactive powers and transmission losses and takes into account only the active powers. Therefore, the DC power flow takes only bus voltage angles ``\mathbf x \equiv {\bm \theta}`` as state variables. Consequently, the number of state variables is ``n-1``, where one voltage angle represents the slack bus.

According to the above assumptions, we start from the [unified branch model](@ref branchmodel):
```math
    \begin{bmatrix}
      \bar{I}_{ij} \\ \bar{I}_{ji}
    \end{bmatrix} = \cfrac{1}{\text{j}x_{ij}}
    \begin{bmatrix}
      \cfrac{1}{\tau_{ij}^2} && -\alpha_{ij}^*\\
      -\alpha_{ij} && 1
    \end{bmatrix}  
    \begin{bmatrix}
      \bar{V}_{i} \\ \bar{V}_{j}
    \end{bmatrix},      
```
where ``\bar{V}_{i} = \text{e}^{\text{j}\theta_{i}}`` and ``\bar{V}_{j} = \text{e}^{\text{j}\theta_{j}}``. Further, we have:
```math
  \begin{aligned}
    \bar{I}_{ij} &= \cfrac{1}{\text{j}x_{ij}} \left[\cfrac{1}{\tau_{ij}^2} \text{e}^{\text{j}\theta_{i}} -
    \cfrac{1}{\tau_{ij}}e^{\text{j}(\phi_{ij} + \theta_j)} \right] \\
    \bar{I}_{ji} &= \cfrac{1}{\text{j}x_{ij}} \left[-\cfrac{1}{\tau_{ij}}e^{\text{j}(\theta_i - \phi_{ij})} + \text{e}^{\text{j}\theta_{j}} \right].
  \end{aligned}  
```
The active power flows are derived as follows:
```math
  \begin{aligned}
    P_{ij} &= \Re\{\bar{V}_{i}\bar{I}_{ij}^*\} =
    \Re \left\{\text{j}\cfrac{1}{x_{ij}}
    \left[\cfrac{1}{\tau_{ij}^2} - \cfrac{1}{\tau_{ij}}e^{\text{j}(\theta_i - \theta_j - \phi_{ij})} \right]  \right\} \\
    P_{ji} &= \Re\{\bar{V}_{j}\bar{I}_{ji}^*\} =
    \Re \left\{\text{j}\cfrac{1}{x_{ij}}
   \left[1-\cfrac{1}{\tau_{ij}}e^{\text{j}(-\theta_i +\theta_j + \phi_{ij})} \right]  \right\}.
  \end{aligned}  
```
The real components are:
```math
  \begin{aligned}
    P_{ij} &=\cfrac{1}{\tau_{ij}x_{ij}} \sin(\theta_{i} -\theta_{j}-\phi_{ij}) \approx \cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} -\theta_{j}-\phi_{ij}) \\
    P_{ji} &=\cfrac{1}{\tau_{ij}x_{ij}} \sin(\theta_{j} -\theta_{i}+\phi_{ij}) \approx -\cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} - \theta_{j}-\phi_{ij}).
  \end{aligned}  
```
We can conclude that ``P_{ij}=-P_{ji}`` holds. With the DC model, the linear network equations relate active power to bus voltage angles, versus complex currents to complex bus voltages in the AC case [[3]](@ref refs). Consequently, analogous to the [unified branch model](@ref branchmodel) we can write:
```math
  \begin{bmatrix}
    P_{ij} \\ P_{ji}
  \end{bmatrix} = \cfrac{1}{\tau_{ij}x_{ij}}
  \begin{bmatrix}
    1 && -1\\
    -1 && 1
  \end{bmatrix}  
  \begin{bmatrix}
    \theta_{i} \\ \theta_{j}
  \end{bmatrix} + \cfrac{\phi_{ij}}{\tau_{ij}x_{ij}}
  \begin{bmatrix}
    -1 \\ 1
  \end{bmatrix},    
```  
that is:
```math
  \begin{bmatrix}
    {P}_{ij} \\ {P}_{ji}
  \end{bmatrix} =
  \begin{bmatrix}
    C_{ij} & -C_{ij}\\
    -C_{ij} & C_{ij}
  \end{bmatrix}  
  \begin{bmatrix}
    \theta_{i} \\ \theta_{j}
  \end{bmatrix}+
  \begin{bmatrix}
    -T_{ij} \\ T_{ij}
  \end{bmatrix}.  
```

As before, let us consider an example of the DC framework, given in Figure 2, that will allow us an easy transition to the general case, where we observe:
* set of buses: ``\mathcal{H} = \{p,k,q\}``;
* set of branches: ``\mathcal{E} = \{(p,k), (k,q)\}``.
```@raw html
<img src="../../assets/dc_model.png" class="center"/>
<figcaption>Figure 2: The example with three buses and two branches.</figcaption>
&nbsp;
```

Each branch in the DC framework is described with system of equations as follows:
```math
  \begin{bmatrix}
    {P}_{pk} \\ {P}_{kp}
  \end{bmatrix} =
  \begin{bmatrix}
    C_{pk} & -C_{pk}\\
    -C_{pk} & C_{pk}
  \end{bmatrix}  
  \begin{bmatrix}
    \theta_{p} \\ \theta_{k}
  \end{bmatrix}+
  \begin{bmatrix}
    -T_{pk} \\ T_{pk}
  \end{bmatrix}  
```
```math
  \begin{bmatrix}
    {P}_{kq} \\ {P}_{qk}
  \end{bmatrix} =
  \begin{bmatrix}
    C_{kq} & -C_{kq}\\
    -C_{kq} & C_{kq}
  \end{bmatrix}  
  \begin{bmatrix}
    \theta_{k} \\ \theta_{q}
  \end{bmatrix}+
  \begin{bmatrix}
    -T_{kq} \\ T_{kq}
  \end{bmatrix}.  
```

The injection active powers into buses are:
```math
  \begin{aligned}
    P_{p} &= P_{pk} = C_{pk} \theta_{p} - C_{pk} \theta_{k} - T_{pk} \\
    P_{k} &= P_{kp} + P_{kq} - P_{\text{sh}k} = -C_{pk} \theta_{p} + C_{pk} \theta_{k} + T_{pk} + C_{kq} \theta_{k} - C_{kq} \theta_{q} - T_{kq} + {g}_{\text{sh}k} \\
    P_{q} &= {P}_{qk} = -C_{kq} \theta_{k} + C_{kq} \theta_{q} + T_{kq}.
  \end{aligned}
```
Note that the active power injected by the shunt element into the bus ``i \in \mathcal{H}`` is equal to:
```math
  P_{\text{sh}i} = \Re\{\bar{V}_{i}\bar{I}_{\text{sh}i}^*\} = \Re\{-\bar{V}_{i}{y}_{\text{sh}i}^*\bar{V}_{i}^*\} = - {g}_{\text{sh}i}.
```
The system of equations can be written in the matrix form:
```math
  \begin{bmatrix}
    P_{p} \\ P_{k} \\ P_{q}
  \end{bmatrix} =
  \begin{bmatrix}
    C_{pk} & - C_{pk} & 0 \\
    -C_{pk} & C_{pk} + C_{kq}  & -C_{kq} \\
    0 & -C_{kq} & C_{kq}
  \end{bmatrix}
  \begin{bmatrix}
    \theta_{p} \\ \theta_{k} \\ \theta_{q}
  \end{bmatrix} +
  \begin{bmatrix}
    - T_{pk} \\ T_{pk} - T_{kq} \\ T_{kq}
  \end{bmatrix} +
  \begin{bmatrix}
    0 \\ {g}_{\text{sh}k} \\ 0
  \end{bmatrix}.
```

Next, the system of equations for ``i=1,\dots,n`` can be written in the matrix form:
```math
  \mathbf {P} = \mathbf{B} \bm {\theta} + \mathbf{P_\text{gs}} + \mathbf{G}_\text{sh},
```
where:
* ``\mathbf {P} \in \mathbb{R}^{n}`` is the vector of active power injection with elements ``P_i,\;i=1,\dots,n``;
* ``\bm \theta \in \mathbb{R}^{n}`` is the vector of bus angle voltages with elements ``\theta_i,\;i=1,\dots,n``;
* ``\mathbf{P_\text{gs}} \in \mathbb{R}^{n}`` is the vector of generation shift factors with elements ``P_{\text{gs}i},\;i=1,\dots,n``, equal to:
```math
  P_{\text{gs}i} = \sum_{e \in \mathcal{E},\; e(2)=i} T_e - \sum_{e \in \mathcal{E},\; e(1)=i} T_e,  
  \;\;\; i \in \mathcal{H},
```
* ``\mathbf{G}_\text{sh} \in \mathbb{R}^{n}`` is the vector of active power consumed by shunt element  ``G_{\text{sh}i},\;i=1,\dots,n``;
* ``\mathbf{B} \in \mathbb{C}^{n \times n}`` is the bus or nodal matrix in the DC framework, with diagonal and non-diagonal elements:
  * the diagonal elements are equal to:
    ```math
    B_{ii} = \sum\limits_{e \in \mathcal{E},\; i \in e} C_{e},  \;\;\; i \in \mathcal{H},
    ```
  * the strictly upper triangular part contains elements equal to:
    ```math
    B_{ij} = -C_{e}, \;\;\;  e \in \mathcal{E},\;  i = e(1),\;  j = e(2),
    ```
  * the strictly lower triangular part contains elements equal to:
    ```math
    B_{ij} = -C_{e}, \;\;\;  e \in \mathcal{E},\;  i = e(2),\;  j = e(1).
    ```

The DC power flow solution is obtained through non-iterative procedure by solving the linear problem:
```math
    \bm {\theta} = \mathbf{B}^{-1}(\mathbf {P} - \mathbf{P_\text{gs}} - \mathbf{G}_\text{sh}).
```
Note that the slack bus voltage angle is excluded from ``\bm {\theta}``. Respectively, corresponding elements in vectors ``\mathbf {P}``, ``\mathbf{P_\text{gs}}``, ``\mathbf{G}_\text{sh}``, and corresponding column of the matrix ``\mathbf{B}`` will be removed.


### [Power Flow Analysis](@id dcpfanalysis)
JuliaGrid uses the above equation to compute bus voltage angles and then calculates other electrical quantities related to the DC power flow analysis. In the rest of this part, we define electrical quantities generated by the JuliaGrid.

Electrical quantities related to the bus ``i \in \mathcal{H}``:
* **Active power injection** can be simply obtained as:
```math
   P_i = \sum_{j \in \mathcal{H}_i} {B}_{ij} \theta_j + P_{\text{gs}i} + G_{\text{sh}i}.
```
* **Total active power generation** is determined using Tellegen's theorem:
As for the AC model, for each bus ``i \in \mathcal{H}``, Tellegen's theorem, holds:
```math
    {P}_{i} = {P}_{\text{g}i}-{P}_{\text{l}i}; \;\;\; P_{\text{g}i} = {P}_{i} + {P}_{\text{l}i}.
```  
* **Active power consumed by the shunt element** is obtained as:
```math
  {P}_{\text{sh}i} ={g}_{\text{sh}i}.
```

Electrical quantities related to the branch ``(i,j) \in \mathcal{E}``:
* **Active power flows** from/to buses are:
```math
  \begin{aligned}
    P_{ij} &= \cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} -\theta_{j}-\phi_{ij})\\
    P_{ji} &= - P_{ij}.
  \end{aligned}
```

---

## [References](@id refs)
[1] A. Wood and B. Wollenberg, Power Generation, Operation, and Control, ser. A Wiley-Interscience publication. Wiley, 1996.

[2] G. Andersson, "Modelling and analysis of electric power systems". EEH-Power Systems Laboratory, Swiss Federal Institute of Technology (ETH), Zürich, Switzerland (2008).

[3] R. D. Zimmerman, C. E. Murillo-Sanchez. MATPOWER User’s Manual, Version 7.0. 2019.

[4] D. P. Chassin, P. R. Armstrong, D. G. Chavarria-Miranda, and R. T. Guttromson, "Gauss-seidel accelerated: implementing flow solvers on field programmable gate arrays," in 2006 IEEE Power Engineering Society General Meeting, 2006, pp. 5.

[5] R. A. M. van Amerongen, "A general-purpose version of the fast decoupled load flow," in IEEE Transactions on Power Systems, vol. 4, no. 2, pp. 760-770, May 1989.
