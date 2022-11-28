# [In-depth AC and DC Model](@id inDepthACDCModel)
Network equations obtained using the unified branch model and defined below represent the basic setup used for the power system analysis. The power system network topology is usually described by the bus/branch model, where branches of the network are defined using the two-port ``\pi``-model. The bus/branch model can be represented using a graph ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where the set of nodes ``\mathcal{N} = \{1, \dots, n\}`` represents the set of buses, while the set of edges ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` represents the set of branches of the power network.

---

## [In-depth AC Model](@id inDepthACModel)
JuliaGrid is based on common network elements and benefits the unified branch model to perform various analyses based on the system of non-linear equations. To create vectors and matrices related with AC or non-linear analyses, JuliaGrid uses the function [`acModel!()`](@ref acModel!), for example:
```julia-repl
system = powerSystem("case14.h5")
acModel!(system)
```

---

#### [AC Branch Model](@id ACBranchModel)
The equivalent unified ``\pi``-model for a branch ``(i,j) \in \mathcal{E}`` incident to the buses ``\{i,j\} \in \mathcal{N}`` is shown in Figure 2.
```@raw html
<img src="../../assets/pi_model.png" class="center"/>
<figcaption>Figure 2: The equivalent branch model, where transformer is located at "from bus end" of the branch.</figcaption>
&nbsp;
```

The branch series admittance ``y_{ij}`` is inversely proportional to the branch series impedance ``z_{ij}``:
```math
    y_{ij} = \frac{1}{z_{ij}} =
    \frac{1}{{r_{ij}} + \text{j}x_{ij}} =
    \frac{r_{ij}}{r_{ij}^2 + x_{ij}^2} - \text{j}\frac{x_{ij}}{r_{ij}^2 + x_{ij}^2} = g_{ij} + \text{j}b_{ij},
```
where ``r_{ij}`` is a resistance, ``x_{ij}`` is a reactance, ``g_{ij}`` is a conductance and ``b_{ij}`` is a susceptance of the branch.
```julia-repl
julia> system.branch.parameter.resistance
julia> system.branch.parameter.reactance
julia> system.acModel.admittance
```

The branch shunt capacitive admittance (i.e. charging admittance) ``y_{\text{s}ij}`` at buses ``\{i,j\}`` is equal to:
```math
y_{\text{s}ij} = \text{j} b_{\text{s}ij}.
```

Note that JuliaGrid stores the total branch shunt capacitive susceptance ``2b_{\text{s}ij}``:
```julia-repl
julia> system.branch.parameter.susceptance
```

The transformer complex ratio ``\alpha_{ij}`` is defined:
```math
    \alpha_{ij} = \cfrac{1}{\tau_{ij}}e^{-\text{j}\phi_{ij}},
```
where ``\tau_{ij}`` is the transformer turns ratio, while ``\phi_{ij}`` is the transformer phase shift angle, always located "from bus end" of the branch.
```julia-repl
julia> system.branch.parameter.turnsRatio
julia> system.branch.parameter.shiftAngle
julia> system.acModel.transformerRatio
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

The values of the terms ``\left(({y}_{ij} + y_{\text{s}ij}) / \tau_{ij}^2\right)``, ``\left(-\alpha_{ij}^*{y}_{ij}\right)``, ``\left(-\alpha_{ij}{y}_{ij}\right)``, and ``\left({y}_{ij} + y_{\text{s}ij}\right)`` can be found stored in four separate arrays, respectively:

```julia-repl
julia> system.acModel.nodalFromFrom
julia> system.acModel.nodalFromTo
julia> system.acModel.nodalToFrom
julia> system.acModel.nodalToTo
```

Note, if ``\tau_{ij} = 1`` and ``\phi_{ij} = 0`` the model describes the line. In-phase transformers are defined if ``\phi_{ij} = 0`` and ``y_{\text{s}ij} = 0``, while phase-shifting transformers are obtained if ``y_{\text{s}ij} = 0``.

---

#### [AC Equations and Nodal Matrix](@id ACNodalMatrix)
Let us consider an example, given in Figure 3, that will allow us an easy transition to the general case. We observe system with three buses ``\mathcal{N} = \{p, k, q\}`` and two branches ``\mathcal{E} = \{(p, k), (k, q)\}``, where the bus ``k`` is incident to the shunt element with admittance ``{y}_{\text{sh}k}``.
```@raw html
<img src="../../assets/pi_model_example.png" class="center"/>
<figcaption>Figure 3: The example with three buses and two branches.</figcaption>
&nbsp;
```

According to the [unified branch model](@ref branchModelAC) each branch is described using the system of equations as follows:
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
  \end{bmatrix}.
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

The injection complex currents into buses are:
```math
  \begin{aligned}
    \bar{I}_{p} &= \bar{I}_{pk} = \cfrac{1}{\tau_{pk}^2}({y}_{pk} + y_{\text{s}pk}) \bar{V}_{p} -\alpha_{kq}^*{y}_{kq} \bar{V}_{k} \\
    \bar{I}_{k} &= \bar{I}_{kp} + \bar{I}_{kq} - \bar{I}_{\text{sh}k} =
    -\alpha_{kq}{y}_{kq} \bar{V}_{p} + ({y}_{kq} + y_{\text{s}kq}) \bar{V}_{k} +
    \cfrac{1}{\tau_{kq}^2}({y}_{kq} + y_{\text{s}kq}) \bar{V}_{k} -\alpha_{kq}^*{y}_{kq} \bar{V}_{q} + {y}_{\text{sh}k} \bar{V}_k \\
    \bar{I}_{q} &= \bar{I}_{qk} = -\alpha_{kq}{y}_{kq} \bar{V}_{k} + ({y}_{kq} + y_{\text{s}kq}) \bar{V}_{q},
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
where ``\mathbf {\bar {V}} \in \mathbb{C}^{n}`` is the vector of bus complex voltages, and ``\mathbf {\bar {I}} \in \mathbb{C}^{n}`` is the vector of injection complex currents.

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

When a branch is not incident (or adjacent) to a bus the corresponding element in the nodal admittance matrix ``\mathbf{Y}`` is equal to zero. The nodal admittance matrix ``\mathbf{Y}`` is a sparse matrix (i.e., a small number of elements are non-zeros) for real-world power systems. Although it is often assumed that the matrix ``\mathbf{Y}`` is symmetrical, it is not a general case, for example, in the presence of phase shifting transformers the matrix ``\mathbf{Y}`` is not symmetrical [[1, Sec. 9.6]](@ref inDepthACDCModelReference).

```julia-repl
julia> system.acModel.nodalMatrix
julia> system.acModel.nodalMatrixTranspose
```

---

## [In-depth DC Model](@id inDepthDCModel)
The DC model is obtained by linearisation of the non-linear model, and it provides an approximate solution. In the typical operating conditions, the difference of bus voltage angles between adjacent buses ``(i,j) \in \mathcal{E}`` is very small ``\theta_{i}-\theta_{j} \approx 0``, which implies ``\cos \theta_{ij}\approx 1`` and ``\sin \theta_{ij} \approx \theta_{ij}``. Further, all bus voltage magnitudes are ``V_i \approx 1``, ``i \in \mathcal{N}``, and all shunt susceptance elements and branch resistances can be neglected. This implies that the DC model ignores the reactive powers and transmission losses and takes into account only the active powers. Therefore, the DC power flow takes only bus voltage angles ``\bm \theta`` as state variables. To create vectors and matrices related with DC or linear analyses, JuliaGrid uses the function [`dcModel!()`](@ref dcModel!), for example:
```julia-repl
system = powerSystem("case14.h5")
dcModel!(system)
```

---

#### [DC Branch Model](@id DCBranchModel)
According to the above assumptions, we start from the [unified branch model](@ref branchModelAC):
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
where ``{1}/({\tau_{ij} x_{ij}})`` represents the branch admittance in the DC framework.
```julia-repl
julia> system.dcModel.admittance
```

We can conclude that ``P_{ij}=-P_{ji}`` holds. With the DC model, the linear network equations relate active power to bus voltage angles, versus complex currents to complex bus voltages in the AC case [[2]](@ref inDepthACDCModelReference). Consequently, analogous to the [unified branch model](@ref branchModelAC) we can write:
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

#### [DC Equations and Nodal Matrix](@id DCNodalMatrix)
As before, let us consider an example of the DC framework, given in Figure 2, that will allow us an easy transition to the general case. We observe system with three buses ``\mathcal{N} = \{p, k, q\}`` and two branches ``\mathcal{E} = \{(p, k), (k, q)\}``, where the bus ``k`` is incident to the shunt element with conductance ``{g}_{\text{sh}k}``.
```@raw html
<img src="../../assets/dc_model.png" class="center"/>
<figcaption>Figure 2: The example with three buses and two branches.</figcaption>
&nbsp;
```

Each branch in the DC framework is described with system of equations as follows:
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
  \end{bmatrix}.
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

The injection active powers into buses are:
```math
  \begin{aligned}
    P_{p} &= P_{pk} =\cfrac{1}{\tau_{pk}x_{pk}} \theta_{p} - \cfrac{1}{\tau_{pk}x_{pk}} \theta_{k} - \cfrac{\phi_{pk}}{\tau_{pk}x_{pk}} \\
    P_{k} &= P_{kp} + P_{kq} - P_{\text{sh}k} = -\cfrac{1}{\tau_{pk}x_{pk}} \theta_{p} + \cfrac{1}{\tau_{pk}x_{pk}} \theta_{k} + \cfrac{\phi_{pk}}{\tau_{pk}x_{pk}} +
    \cfrac{1}{\tau_{kq}x_{kq}} \theta_{k} - \cfrac{1}{\tau_{kq}x_{kq}} \theta_{q} - \cfrac{\phi_{kq}}{\tau_{kq}x_{kq}} + {g}_{\text{sh}k} \\
    P_{q} &= {P}_{qk} = -\cfrac{1}{\tau_{kq}x_{kq}} \theta_{k} +\cfrac{1}{\tau_{kq}x_{kq}} \theta_{q} + \cfrac{\phi_{kq}}{\tau_{kq}x_{kq}}.
  \end{aligned}
```
Note that the active power injected by the shunt element into the bus ``i \in \mathcal{N}`` is equal to:
```math
  P_{\text{sh}i} = \Re\{\bar{V}_{i}\bar{I}_{\text{sh}i}^*\} = \Re\{-\bar{V}_{i}{y}_{\text{sh}i}^*\bar{V}_{i}^*\} = - {g}_{\text{sh}i}.
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
  \mathbf {P} = \mathbf{B} \bm {\theta} + \mathbf{P_\text{gs}} + \mathbf{P}_\text{sh},
```
where ``\bm \theta \in \mathbb{R}^{n}`` is the vector of bus voltage angles.


The vector ``\mathbf {P} \in \mathbb{R}^{n}`` contains injected active powers into buses caused by generators and demands. In JuliaGrid, the vector can be recovered using an expression:
```julia-repl
julia> system.bus.supply.active - system.bus.demand.active
```

The vector ``\mathbf{P_\text{gs}} \in \mathbb{R}^{n}`` represents active powers related with non-zero shift angle of transformers.
```julia-repl
julia> system.dcModel.shiftActivePower
```

The vector ``\mathbf{P}_\text{sh} \in \mathbb{R}^{n}`` represents active powers consumed by shunt elements.
```julia-repl
julia> system.bus.shunt.conductance
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
```julia-repl
julia> system.dcModel.nodalMatrix
```

---

## [References](@id inDepthACDCModelReference)
[1] J. Grainger and W. Stevenson, *Power system analysis*, ser. McGraw-Hill series in electrical and computer engineering: Power and energy. McGraw-Hill, 1994.

[2] R. D. Zimmerman, C. E. Murillo-Sanchez, *MATPOWER User’s Manual*, Version 7.0. 2019.