# [In-depth AC Model](@id inDepthACModel)
Network equations obtained using the unified branch model and defined below represent the basic setup used for the power system analysis. The power system network topology is usually described by the bus/branch model, where branches of the network are defined using the two-port ``\pi``-model. The bus/branch model can be represented using a graph ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where the set of nodes ``\mathcal{N} = \{1, \dots, n\}`` represents the set of buses, while the set of edges ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` represents the set of branches of the power network.

---

## [Branch Model](@id branchModelAC)
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
```@repl
system.branch.parameter.resistance
system.branch.parameter.reactance
system.acModel.admittance
```

The branch shunt capacitive admittance (i.e. charging admittance) ``y_{\text{s}ij}`` at buses ``\{i,j\}`` is equal to:
```math
y_{\text{s}ij} = \text{j} b_{\text{s}ij}.
```

Note that JuliaGrid stores the total branch shunt capacitive susceptance ``2b_{\text{s}ij}``:
```@repl
julia> system.branch.parameter.susceptance
```

The transformer complex ratio ``\alpha_{ij}`` is defined:
```math
    \alpha_{ij} = \cfrac{1}{\tau_{ij}}e^{-\text{j}\phi_{ij}},
```
where ``\tau_{ij}`` is the transformer turns ratio, while ``\phi_{ij}`` is the transformer phase shift angle, always located "from bus end" of the branch.

```@setup abc
using JuliaGrid
system = powerSystem()
```

```@repl abc
system.branch.parameter.turnsRatio
system.branch.parameter.shiftAngle
system.acModel.transformerRatio
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

```@repl
julia> system.acModel.nodalFromFrom
julia> system.acModel.nodalFromTo
julia> system.acModel.nodalToFrom
julia> system.acModel.nodalToTo
```

Note, if ``\tau_{ij} = 1`` and ``\phi_{ij} = 0`` the model describes the line. In-phase transformers are defined if ``\phi_{ij} = 0`` and ``y_{\text{s}ij} = 0``, while phase-shifting transformers are obtained if ``y_{\text{s}ij} = 0``.

---

## [System of Equations and Nodal Matrix](@id nodalMatrixAC)
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

When a branch is not incident (or adjacent) to a bus the corresponding element in the nodal admittance matrix ``\mathbf{Y}`` is equal to zero. The nodal admittance matrix ``\mathbf{Y}`` is a sparse matrix (i.e., a small number of elements are non-zeros) for real-world power systems. Although it is often assumed that the matrix ``\mathbf{Y}`` is symmetrical, it is not a general case, for example, in the presence of phase shifting transformers the matrix ``\mathbf{Y}`` is not symmetrical [[1, Sec. 9.6]](@ref inDepthACModelReference).

```@repl
julia> system.acModel.nodalMatrix
julia> system.acModel.nodalMatrixTranspose
```

---

## [References](@id inDepthACModelReference)
[1] J. Grainger and W. Stevenson, *Power system analysis*, ser. McGraw-Hill series in electrical and computer engineering: Power and energy. McGraw-Hill, 1994.
