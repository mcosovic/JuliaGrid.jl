# [AC and DC Model](@id ACDCModelTutorials)
The power system analyses commonly utilize the unified branch model that provides linear relationships between voltages and currents. However, as the focus is on power calculations rather than current calculations, the resulting equations become nonlinear, posing challenges in solving them [[1]](@ref ACDCModelReferenceTutorials). Hence, to accurately analyze power systems without any approximations, we use the AC model, which is a crucial component of our framework. In contrast, to obtain a linear system of equations for various DC analyses, we introduce approximations in the unified branch model, resulting in the DC model.

A common way to describe the power system network topology is through the bus/branch model, which employs the two-port ``\pi``-model, which results in the unified branch model. The bus/branch model can be represented by a graph denoted by ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where the set of nodes ``\mathcal{N} = \{1, \dots, n\}`` corresponds to buses, and the set of edges ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` represents the branches of the power network.

Let us now construct the power system:
```@example ACDCModel
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

@power(MW, MVAr, MVA)
@voltage(pu, deg, V)

system = powerSystem()

addBus!(system; label = 1, type = 3)
addBus!(system; label = 2, type = 1, active = 21.7, reactive = 12.7)
addBus!(system; label = 3, type = 2, conductance = 2.1, susceptance = 1.2)

addBranch!(system; from = 1, to = 2, resistance = 0.02, reactance = 0.06, susceptance = 0.05)
addBranch!(system; from = 1, to = 3, reactance = 0.21, turnsRatio = 0.98, shiftAngle = 1.2)
addBranch!(system; from = 2, to = 3, resistance = 0.13, reactance = 0.26, conductance = 1e-3)

addGenerator!(system; bus = 1, active = 40.0, reactive = 42.4)
nothing #hide
```

The given example provides the set of buses and branches:
```@repl ACDCModel
𝒩 = collect(keys(sort(system.bus.label)))
ℰ = [system.branch.layout.from system.branch.layout.to]
```

!!! ukw "Notation"
    In this section, when referring to a vector ``\mathbf{a}``, we use the notation ``\mathbf{a} = [a_{ij}]``, where ``a_{ij}`` represents the generic element associated with the branch ``(i,j) \in \mathcal{E}``.

---

## [AC Model](@id ACModelTutorials)
JuliaGrid is based on common network elements and benefits from the unified branch model to perform various analyses based on the system of nonlinear equations. To generate matrices and vectors for AC or nonlinear analysis, JuliaGrid employs the [`acModel!`](@ref acModel!) function. To demonstrate the usage of this function, consider the power system defined in the previous example. In order to apply the [`acModel!`](@ref acModel!) function to this power system, the following code can be executed:
```@example ACDCModel
acModel!(system)
nothing #hide
```

---

##### [Unified Branch Model](@id UnifiedBranchModelTutorials)
The equivalent unified ``\pi``-model for a branch ``(i,j) \in \mathcal{E}`` incident to the buses ``\{i,j\} \in \mathcal{N}`` is shown in Figure 1.
```@raw html
<img src="../../assets/pi_model.svg" class="center" width="600"/>
<figcaption>Figure 1: The equivalent branch model, where the transformer is located at "from" bus end of the branch.</figcaption>
&nbsp;
```

!!! note "Info"
    The directions of the currents ``\bar{I}_{ij}``, ``\bar{I}_{ji}``, ``\bar{I}_{\text{s}i}``, and ``\bar{I}_{\text{s}j}`` are initially defined to come out from the nodes or buses. This convention proves particularly valuable during power flow analyses. In cases where active or reactive power is positive, it signifies alignment with the assumed current direction, flowing away from the bus. Conversely, when power is negative, the direction is reversed, indicating a flow towards the bus. These current directions, in conjunction with ``\bar{I}_{\text{s}ij}``, are consistently employed by JuliaGrid in its calculations of powers or currents.

The branch series admittance ``y_{ij}`` is inversely proportional to the branch series impedance ``z_{ij}``:
```math
    y_{ij} = \frac{1}{z_{ij}} =
    \frac{1}{{r_{ij}} + \text{j}x_{ij}} =
    \frac{r_{ij}}{r_{ij}^2 + x_{ij}^2} - \text{j}\frac{x_{ij}}{r_{ij}^2 + x_{ij}^2} = g_{ij} + \text{j}b_{ij},
```
where ``r_{ij}`` is a resistance, ``x_{ij}`` is a reactance, ``g_{ij}`` is a conductance and ``b_{ij}`` is a susceptance of the branch.

The vectors of resistances, denoted by ``\mathbf{r} = [r_{ij}]``, and reactances, denoted by ``\mathbf{x} = [x_{ij}]``, are stored in the variables:
```@repl ACDCModel
𝐫 = system.branch.parameter.resistance
𝐱 = system.branch.parameter.reactance
```
Moreover, the `acModel` stores the computed vector of branch series admittances ``\mathbf{y} = [y_{ij}]``:
```@repl ACDCModel
𝐲 = system.model.ac.admittance
```

The branch shunt admittance ``y_{\text{s}ij}`` is equal to:
```math
y_{\text{s}ij} = g_{\text{s}ij} + \text{j} b_{\text{s}ij},
```
where ``g_{\text{s}ij}`` represents the shunt conductance of the branch, and ``b_{\text{s}ij}`` represents the shunt susceptance. Both of these values are positive for real line sections. It is worth noting that while the shunt conductance ``g_{\text{s}ij}`` is often insignificantly small and can be ignored in many cases, it is included in the analyses to ensure comprehensive consideration of all potential scenarios.

Within JuliaGrid, the total shunt conductances and susceptances of branches are stored. In order to obtain the vectors ``\mathbf{g}_\text{s} = [g_{\text{s}ij}]`` and ``\mathbf{b}_\text{s} = [b_{\text{s}ij}]``, the conductances and susceptances must be distributed by considering the ends of the branches:
```@repl ACDCModel
𝐠ₛ = 0.5 * system.branch.parameter.conductance
𝐛ₛ = 0.5 * system.branch.parameter.susceptance
```

The transformer complex ratio ``\alpha_{ij}`` is defined:
```math
    \alpha_{ij} = \cfrac{1}{\tau_{ij}}e^{-\text{j}\phi_{ij}},
```
where ``\tau_{ij} \neq 0`` is a transformer turns ratio, while ``\phi_{ij}`` is a transformer phase shift angle, always located "from" bus end of the branch. Note, if ``\tau_{ij} = 1`` and ``\phi_{ij} = 0`` the model describes the line. In-phase transformers are defined if ``\tau_{ij} \neq 1``, ``\phi_{ij} = 0``, and ``y_{\text{s}ij} = 0``, while phase-shifting transformers are obtained if ``\tau_{ij} \neq 1``, ``\phi_{ij} \neq 0``, and ``y_{\text{s}ij} = 0``.

These transformer parameters are stored in the vectors ``\bm{\tau} = [\tau_{ij}]`` and ``\bm{\phi} = [\phi_{ij}]``, respectively:
```@repl ACDCModel
𝛕 = system.branch.parameter.turnsRatio
𝚽 = system.branch.parameter.shiftAngle
```

Using Kirchhoff's circuit laws, the unified branch model can be described by complex expressions:
```math
  \begin{bmatrix}
    \bar{I}_{ij} \\ \bar{I}_{ji}
  \end{bmatrix} =
  \begin{bmatrix}
    \cfrac{1}{\tau_{ij}^2}({y}_{ij} + y_{\text{s}ij}) & -\alpha_{ij}^*{y}_{ij}\\
    -\alpha_{ij}{y}_{ij} & {y}_{ij} + y_{\text{s}ij}
  \end{bmatrix}
  \begin{bmatrix}
    \bar{V}_{i} \\ \bar{V}_{j}
  \end{bmatrix}.
```

The values of the vectors ``\mathbf{y}_{\text{ii}} = [({y}_{ij} + y_{\text{s}ij}) / \tau_{ij}^2]``, ``\mathbf{y}_{\text{ij}} = [-\alpha_{ij}^*{y}_{ij}]``, ``\mathbf{y}_{\text{ji}} = [-\alpha_{ij}{y}_{ij}]``, and ``\mathbf{y}_{\text{jj}} = [{y}_{ij} + y_{\text{s}ij}]`` can be found stored in the variables:

```@repl ACDCModel
𝐲ᵢᵢ = system.model.ac.nodalFromFrom
𝐲ᵢⱼ = system.model.ac.nodalFromTo
𝐲ⱼᵢ = system.model.ac.nodalToFrom
𝐲ⱼⱼ = system.model.ac.nodalToTo
```

---

##### [System of Equations and Nodal Matrix](@id SystemEquationsNodalMatrixTutorials)
Let us consider an example, given in Figure 2, that will allow us an easy transition to the general case. We observe system with three buses ``\mathcal{N} = \{p, k, q\}`` and two branches ``\mathcal{E} = \{(p, k), (k, q)\}``, where the bus ``k`` is incident to the shunt element with admittance ``{y}_{\text{sh}k}``.
```@raw html
<img src="../../assets/pi_model_example.svg" class="center" width="710"/>
<figcaption>Figure 2: The example of the system with three buses and two branches.</figcaption>
&nbsp;
```
!!! note "Info"
    The current ``\bar{I}_{\text{sh}k}`` follows the convention of coming out from the bus in terms of its direction. When calculating powers related to shunt elements, this current direction is assumed. Therefore, in cases where power is positive, it signifies alignment with the assumed current direction, emerging away from the bus. Conversely, when power is negative, the direction is reversed, indicating a flow towards the bus.

According to the [unified branch model](@ref UnifiedBranchModelTutorials) each branch is described using the system of equations as follows:
```math
  \begin{bmatrix}
    \bar{I}_{pk} \\ \bar{I}_{kp}
  \end{bmatrix} =
  \begin{bmatrix}
    \cfrac{1}{\tau_{pk}^2}({y}_{pk} + y_{\text{s}pk}) & -\alpha_{pk}^*{y}_{pk}\\
    -\alpha_{pk}{y}_{pk} & {y}_{pk} + y_{\text{s}pk}
  \end{bmatrix}
  \begin{bmatrix}
    \bar{V}_{p} \\ \bar{V}_{k}
  \end{bmatrix}
```
```math
  \begin{bmatrix}
    \bar{I}_{kq} \\ \bar{I}_{qk}
  \end{bmatrix} =
  \begin{bmatrix}
    \cfrac{1}{\tau_{kq}^2}({y}_{kq} + y_{\text{s}kq}) & -\alpha_{kq}^*{y}_{kq}\\
    -\alpha_{kq}{y}_{kq} & {y}_{kq} + y_{\text{s}kq}
  \end{bmatrix}
  \begin{bmatrix}
    \bar{V}_{k} \\ \bar{V}_{q}
  \end{bmatrix}.
```

The complex current injections at buses are:
```math
  \begin{aligned}
    \bar{I}_{p} &= \bar{I}_{pk} = \cfrac{1}{\tau_{pk}^2}({y}_{pk} + y_{\text{s}pk}) \bar{V}_{p} -\alpha_{kq}^*{y}_{kq} \bar{V}_{k} \\
    \bar{I}_{k} &= \bar{I}_{kp} + \bar{I}_{kq} + \bar{I}_{\text{sh}k} =
    -\alpha_{kq}{y}_{kq} \bar{V}_{p} + ({y}_{kq} + y_{\text{s}kq}) \bar{V}_{k} +
    \cfrac{1}{\tau_{kq}^2}({y}_{kq} + y_{\text{s}kq}) \bar{V}_{k} -\alpha_{kq}^*{y}_{kq} \bar{V}_{q} + {y}_{\text{sh}k} \bar{V}_k \\
    \bar{I}_{q} &= \bar{I}_{qk} = -\alpha_{kq}{y}_{kq} \bar{V}_{k} + ({y}_{kq} + y_{\text{s}kq}) \bar{V}_{q}.
  \end{aligned}
```
The system of equations can be written in the matrix form:
```math
  \begin{bmatrix}
    \bar{I}_{p} \\ \bar{I}_{k} \\ \bar{I}_{q}
  \end{bmatrix} =
  \begin{bmatrix}
    \cfrac{1}{\tau_{pk}^2}({y}_{pk} + y_{\text{s}pk}) & -\alpha_{kq}^*{y}_{kq} & 0 \\
   -\alpha_{kq}{y}_{kq} & {y}_{kq} + y_{\text{s}kq} + \cfrac{1}{\tau_{kq}^2}({y}_{kq} + y_{\text{s}kq}) + {y}_{\text{sh}k}  & -\alpha_{kq}^*{y}_{kq} \\
    0 & -\alpha_{kq}{y}_{kq} & {y}_{kq} + y_{\text{s}kq}
  \end{bmatrix}
  \begin{bmatrix}
    \bar{V}_{p} \\ \bar{V}_{k} \\ \bar{V}_{q}
  \end{bmatrix}.
```

Next, the system of equations for buses ``i=1, \dots, n`` can be written in the matrix form:
```math
  \mathbf {\bar {I}} = \mathbf{Y} \mathbf {\bar {V}},
```
where ``\mathbf {\bar {V}} \in \mathbb{C}^{n}`` is the vector of bus complex voltages, and ``\mathbf {\bar {I}} \in \mathbb{C}^{n}`` is the vector of complex current injections at buses.

The matrix ``\mathbf{Y} = \mathbf{G} + \text{j}\mathbf{B} \in \mathbb{C}^{n \times n}`` is the bus or nodal admittance matrix, with elements:
  * the diagonal elements, where ``i \in \mathcal{N}``,  are equal to:
    ```math
    Y_{ii} = G_{ii} + \text{j}B_{ii} = {y}_{\text{sh}i} +
    \sum\limits_{e \in \mathcal{E}, \; e(1) = i} \cfrac{1}{\tau_{ij}^2}({y}_{ij} + y_{\text{s}ij}) + \sum\limits_{e \in \mathcal{E}, \; e(2) = i} ({y}_{ij} + y_{\text{s}ij}),
    ```
  * the non-diagonal elements, where ``i = e(1),\;  j = e(2), \; e \in \mathcal{E}``, are equal to:
    ```math
    Y_{ij} = G_{ij} + \text{j}B_{ij} = -\alpha_{ij}^*{y}_{ij}
    ```
    ```math
    Y_{ji} = G_{ji} + \text{j}B_{ji} =  -\alpha_{ij}{y}_{ij}.
    ```

When a branch is not incident (or adjacent) to a bus the corresponding element in the nodal admittance matrix ``\mathbf{Y}`` is equal to zero. The nodal admittance matrix ``\mathbf{Y}`` is a sparse (i.e., a small number of elements are non-zeros) for real-world power systems. Although it is often assumed that the matrix ``\mathbf{Y}`` is symmetrical, it is not a general case, for example, in the presence of phase shifting transformers the matrix ``\mathbf{Y}`` is not symmetrical [[2, Sec. 9.6]](@ref ACDCModelReferenceTutorials). JuliaGrid stores both the matrix ``\mathbf{Y}`` and its transpose ``\mathbf{Y}^T`` in the `acModel` variable of the `PowerSystem` composite type:
```@repl ACDCModel
𝐘 = system.model.ac.nodalMatrix
𝐘ᵀ = system.model.ac.nodalMatrixTranspose
```

---

## [DC Model](@id DCModelTutorials)
The DC model is obtained by linearisation of the nonlinear model, and it provides an approximate solution. In the typical operating conditions, the difference of bus voltage angles between adjacent buses ``(i,j) \in \mathcal{E}`` is very small ``\theta_{i}-\theta_{j} \approx 0``, which implies ``\cos \theta_{ij}\approx 1`` and ``\sin \theta_{ij} \approx \theta_{ij}``. Further, all bus voltage magnitudes are ``V_i \approx 1``, ``i \in \mathcal{N}``, and all branch shunt admittances and branch resistances can be neglected. This implies that the DC model ignores the reactive powers and transmission losses and takes into account only the active powers. Therefore, the DC power flow takes only bus voltage angles ``\bm \theta`` as variables. To create vectors and matrices related to DC or linear analyses, JuliaGrid uses the function [`dcModel!`](@ref dcModel!). Therefore, we can continue with the previous example:
```@example ACDCModel
dcModel!(system)
nothing # hide
```

---

##### [Unified Branch Model](@id DCUnifiedBranchModelTutorials)
According to the above assumptions, we start from the [unified branch model](@ref UnifiedBranchModelTutorials):
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
    P_{ji} &=\cfrac{1}{\tau_{ij}x_{ij}} \sin(\theta_{j} -\theta_{i}+\phi_{ij}) \approx -\cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} - \theta_{j}-\phi_{ij}),
  \end{aligned}
```
where ``{1}/({\tau_{ij} x_{ij}})`` represents the branch admittance in the DC framework. To recall, the `PowerSystem` composite type stores the reactances as vector ``\mathbf{x} = [x_{ij}]`` in the variable:
```@repl ACDCModel
𝐱 = system.branch.parameter.reactance
```

Furthermore, the computed branch admittances in the DC framework are stored in the vector ``\mathbf{y} = [{1}/({\tau_{ij} x_{ij}})]``:
```@repl ACDCModel
𝐲 = system.model.dc.admittance
```

We can conclude that ``P_{ij}=-P_{ji}`` holds. With the DC model, the linear network equations relate active powers to bus voltage angles, versus complex currents to complex bus voltages in the AC model [[3]](@ref ACDCModelReferenceTutorials). Consequently, analogous to the [unified branch model](@ref UnifiedBranchModelTutorials) we can write:
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
  \end{bmatrix}.
```

---

##### [System of Equations and Nodal Matrix](@id SystemEquationsNodalMatrixTutorials)
As before, let us consider an example of the DC framework, given in Figure 3, that will allow us an easy transition to the general case. We observe system with three buses ``\mathcal{N} = \{p, k, q\}`` and two branches ``\mathcal{E} = \{(p, k), (k, q)\}``, where the bus ``k`` is incident to the shunt element with conductance ``{g}_{\text{sh}k}``.
```@raw html
<img src="../../assets/dc_model.svg" class="center" width="600" />
<figcaption>Figure 3: The example of the system with three buses and two branches.</figcaption>
&nbsp;
```

Each branch in the DC framework is described with a system of equations as follows:
```math
  \begin{bmatrix}
    P_{pk} \\ P_{kp}
  \end{bmatrix} = \cfrac{1}{\tau_{pk}x_{pk}}
  \begin{bmatrix}
    1 && -1\\
    -1 && 1
  \end{bmatrix}
  \begin{bmatrix}
    \theta_{p} \\ \theta_{k}
  \end{bmatrix} + \cfrac{\phi_{pk}}{\tau_{pk}x_{pk}}
  \begin{bmatrix}
    -1 \\ 1
  \end{bmatrix}
```
```math
  \begin{bmatrix}
    P_{kq} \\ P_{qk}
  \end{bmatrix} = \cfrac{1}{\tau_{kq}x_{kq}}
  \begin{bmatrix}
    1 && -1\\
    -1 && 1
  \end{bmatrix}
  \begin{bmatrix}
    \theta_{k} \\ \theta_{q}
  \end{bmatrix} + \cfrac{\phi_{kq}}{\tau_{kq}x_{kq}}
  \begin{bmatrix}
    -1 \\ 1
  \end{bmatrix}.
```

The active power injections at buses are:
```math
  \begin{aligned}
    P_{p} &= P_{pk} =\cfrac{1}{\tau_{pk}x_{pk}} \theta_{p} - \cfrac{1}{\tau_{pk}x_{pk}} \theta_{k} - \cfrac{\phi_{pk}}{\tau_{pk}x_{pk}} \\
    P_{k} &= P_{kp} + P_{kq} + P_{\text{sh}k} = -\cfrac{1}{\tau_{pk}x_{pk}} \theta_{p} + \cfrac{1}{\tau_{pk}x_{pk}} \theta_{k} + \cfrac{\phi_{pk}}{\tau_{pk}x_{pk}} +
    \cfrac{1}{\tau_{kq}x_{kq}} \theta_{k} - \cfrac{1}{\tau_{kq}x_{kq}} \theta_{q} - \cfrac{\phi_{kq}}{\tau_{kq}x_{kq}} + {g}_{\text{sh}k} \\
    P_{q} &= {P}_{qk} = -\cfrac{1}{\tau_{kq}x_{kq}} \theta_{k} +\cfrac{1}{\tau_{kq}x_{kq}} \theta_{q} + \cfrac{\phi_{kq}}{\tau_{kq}x_{kq}},
  \end{aligned}
```
where the active power injected by the shunt element at the bus ``k`` is equal to:
```math
  P_{\text{sh}k} = \Re\{\bar{V}_{k}\bar{I}_{\text{sh}k}^*\} = \Re\{\bar{V}_{k}{y}_{\text{sh}k}^*\bar{V}_{k}^*\} = V_k^2 {g}_{\text{sh}k} = {g}_{\text{sh}k}.
```
The system of equations can be written in the matrix form:
```math
  \begin{bmatrix}
    P_{p} \\ P_{k} \\ P_{q}
  \end{bmatrix} =
  \begin{bmatrix}
    \cfrac{1}{\tau_{pk}x_{pk}} & - \cfrac{1}{\tau_{pk}x_{pk}} & 0 \\
    -\cfrac{1}{\tau_{pk}x_{pk}} & \cfrac{1}{\tau_{pk}x_{pk}} + \cfrac{1}{\tau_{kq}x_{kq}}  & -\cfrac{1}{\tau_{kq}x_{kq}} \\
    0 & -\cfrac{1}{\tau_{kq}x_{kq}} &\cfrac{1}{\tau_{kq}x_{kq}}
  \end{bmatrix}
  \begin{bmatrix}
    \theta_{p} \\ \theta_{k} \\ \theta_{q}
  \end{bmatrix} +
  \begin{bmatrix}
    - \cfrac{\phi_{pk}}{\tau_{pk}x_{pk}} \\ \cfrac{\phi_{pk}}{\tau_{pk}x_{pk}} - \cfrac{\phi_{kq}}{\tau_{kq}x_{kq}} \\ \cfrac{\phi_{kq}}{\tau_{kq}x_{kq}}
  \end{bmatrix} +
  \begin{bmatrix}
    0 \\ {g}_{\text{sh}k} \\ 0
  \end{bmatrix}.
```

Next, the system of equations for ``i=1,\dots,n`` can be written in the matrix form:
```math
  \mathbf {P} = \mathbf{B} \bm {\theta} + \mathbf{P_\text{tr}} + \mathbf{P}_\text{sh},
```
where ``\bm \theta \in \mathbb{R}^{n}`` is the vector of bus voltage angles.

The vector ``\mathbf {P} \in \mathbb{R}^{n}`` contains active power injections at buses caused by generators and demands. In JuliaGrid, the vector can be recovered using a command:
```@repl ACDCModel
𝐏 = system.bus.supply.active - system.bus.demand.active
```

The vector ``\mathbf{P_\text{tr}} \in \mathbb{R}^{n}`` represents active powers related to the non-zero shift angle of transformers. This vector is stored in the `dcModel` variable, and we can access it using:
```@repl ACDCModel
𝐏ₜᵣ = system.model.dc.shiftActivePower
```

The vector ``\mathbf{P}_\text{sh} \in \mathbb{R}^{n}`` represents active powers consumed by shunt elements. We can access this vector using:
```@repl ACDCModel
𝐏ₛₕ = system.bus.shunt.conductance
```

The bus or nodal matrix in the DC framework is given as ``\mathbf{B} \in \mathbb{C}^{n \times n}``, with elements:
  * the diagonal elements, where ``i \in \mathcal{N}``,  are equal to:
    ```math
    B_{ii} = \sum\limits_{e \in \mathcal{E},\; i \in e} \cfrac{1}{\tau_{ij}x_{ij}},
    ```
  * the non-diagonal elements, where ``i = e(1),\;  j = e(2), \; e \in \mathcal{E}``, are equal to:
    ```math
    B_{ij} = -\cfrac{1}{\tau_{ij}x_{ij}}
    ```
    ```math
    B_{ji} = -\cfrac{1}{\tau_{ij}x_{ij}}.
    ```

The sparse nodal matrix ``\mathbf{B}`` is stored in the `dcModel` variable, and we can access it using:
```@repl ACDCModel
𝐁 = system.model.dc.nodalMatrix
```

---

## [References](@id ACDCModelReferenceTutorials)
[1] G. Andersson, *Power system analysis*, EEH-Power Systems Laboratory, ETH Zurich, Lecture Notes 2012.

[2] J. Grainger and W. Stevenson, *Power system analysis*, ser. McGraw-Hill series in electrical and computer engineering: Power and energy. McGraw-Hill, 1994.

[3] R. D. Zimmerman, C. E. Murillo-Sanchez, *MATPOWER User’s Manual*, Version 7.0. 2019.