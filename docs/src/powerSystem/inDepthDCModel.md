# [In-depth DC Model](@id inDepthDCModel)

The DC model is obtained by linearisation of the non-linear model, and it provides an approximate solution. In the typical operating conditions, the difference of bus voltage angles between adjacent buses ``(i,j) \in \mathcal{E}`` is very small ``\theta_{i}-\theta_{j} \approx 0``, which implies ``\cos \theta_{ij}\approx 1`` and ``\sin \theta_{ij} \approx \theta_{ij}``. Further, all bus voltage magnitudes are ``V_i \approx 1``, ``i \in \mathcal{N}``, and all shunt susceptance elements and branch resistances can be neglected. This implies that the DC model ignores the reactive powers and transmission losses and takes into account only the active powers. Therefore, the DC power flow takes only bus voltage angles ``\bm \theta`` as state variables.

---

## [Branch Model](@id branchModelDC)
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

We can conclude that ``P_{ij}=-P_{ji}`` holds. With the DC model, the linear network equations relate active power to bus voltage angles, versus complex currents to complex bus voltages in the AC case [[1]](@ref inDepthDCModelReference). Consequently, analogous to the [unified branch model](@ref branchModelAC) we can write:
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

## [System of Equations and Nodal Matrix](@id nodalMatrixDC)
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

## [References](@id inDepthDCModelReference)
[1] R. D. Zimmerman, C. E. Murillo-Sanchez, *MATPOWER User’s Manual*, Version 7.0. 2019.
