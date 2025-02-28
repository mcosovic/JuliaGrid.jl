# [AC State Estimation](@id ACStateEstimationTutorials)
To initiate the process, let us construct the `PowerSystem` type and formulate the AC model:
```@example ACSETutorial
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.5)
addBus!(system; label = 2, type = 1, reactive = 0.3)
addBus!(system; label = 3, type = 1, active = 0.5)

@branch(resistance = 0.02, susceptance = 0.04)
addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.6)
addBranch!(system; label = 2, from = 1, to = 3, reactance = 0.7)
addBranch!(system; label = 3, from = 2, to = 3, reactance = 0.2)

addGenerator!(system; label = 1, bus = 1, active = 3.2, reactive = 0.2)

acModel!(system)
nothing # hide
```

To review, we can conceptualize the bus/branch model as the graph denoted by ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where we have the set of buses ``\mathcal{N} = \{1, \dots, n\}``, and the set of branches ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` within the power system:
```@repl ACSETutorial
𝒩 = collect(keys(system.bus.label))
ℰ = [𝒩[system.branch.layout.from] 𝒩[system.branch.layout.to]]
```

---

Following that, we will introduce the `Measurement` type and incorporate a set of measurement devices ``\mathcal{M}`` into the graph ``\mathcal{G}``. The AC state estimation includes a set of voltmeters ``\mathcal{V}``, ammeters ``\mathcal{I}``, wattmeters ``\mathcal{P}``, varmeters ``\mathcal{Q}``, and PMUs ``\bar{\mathcal{P}}``, with PMUs being able to integrate into AC state estimation in either rectangular coordinates or polar coordinates. This process of adding measurement devices will be carried out in the [State Estimation Model](@ref ACSEModelTutorials) section. Currently, we are only initializing the `Measurement` type at this stage:
```@example ACSETutorial
device = measurement()
nothing # hide
```

---

!!! ukw "Notation"
    Here, when referring to a vector ``\mathbf{a}``, we use the notation ``\mathbf{a} = [a_{i}]`` or ``\mathbf{a} = [a_{ij}]``, where ``a_i`` represents the element related with bus ``i \in \mathcal{N}`` or measurement ``i \in \mathcal{M}``, while ``a_{ij}`` denotes the element related with branch ``(i,j) \in \mathcal{E}``.

---

## [State Estimation Model](@id ACSEModelTutorials)
In accordance with the [AC Model](@ref ACModelTutorials), the AC state estimation treats bus voltages as state variables, which we denoted by ``\mathbf x \equiv [\bm {\Theta}, \mathbf{V}]^T``. The state vector encompasses two components:
* ``\bm {\Theta} \in \mathbb{R}^{n-1}``, representing bus voltage angles,
* ``\mathbf {V} \in \mathbb{R}^n``, representing bus voltage magnitudes.
Consequently, the total number of state variables is ``n_\text{u} = 2n-1``, accounting for the fact that the voltage angle for the slack bus is known.

Within the JuliaGrid framework for AC state estimation, the methodology encompasses bus voltage magnitudes, branch current magnitudes, active powers, reactive powers, and phasor measurements. These measurements contribute to the construction of a nonlinear system of equations:
```math
    \mathbf{z}=\mathbf{h}(\mathbf {x}) + \mathbf{u}.
```

Here, ``\mathbf{h}(\mathbf {x})= [h_1(\mathbf {x})``, ``\dots``, ``h_k(\mathbf {x})]^{{T}}`` represents the vector of nonlinear measurement functions, where ``k`` is the number of measurements, ``\mathbf{z} = [z_1,\dots,z_k]^{T}`` denotes the vector of measurement values, and ``\mathbf{u} = [u_1,\dots,u_k]^T`` represents the vector of measurement errors. It is worth noting that the number of equations in the system is equal to ``k = |\mathcal{V} \cup \mathcal{I} \cup \mathcal{P} \cup \mathcal{Q}| + 2|\bar{\mathcal{P}}|``.

These errors are assumed to follow a Gaussian distribution with a zero mean and covariance matrix ``\bm \Sigma``. The diagonal elements of ``\bm \Sigma`` correspond to the measurement variances ``\mathbf{v} = [v_1,\dots,v_k]^T``, while the off-diagonal elements represent the covariances between the measurement errors ``\mathbf{w} = [w_1,\dots,w_k]^{T}``. These covariances exist only if PMUs are observed in rectangular coordinates and correlation is required.

Hence, the nonlinear system of equations is structured according to the specific devices:
```math
    \begin{bmatrix}
      \mathbf{z}_\mathcal{V}\\[3pt]
      \mathbf{z}_\mathcal{I}\\[3pt]
      \mathbf{z}_\mathcal{P}\\[3pt]
      \mathbf{z}_\mathcal{Q}\\[3pt]
      \mathbf{z}_{\bar{\mathcal{P}}}
    \end{bmatrix} =
    \begin{bmatrix}
      \mathbf{h}_\mathcal{V}(\mathbf {x})\\[3pt]
      \mathbf{h}_\mathcal{I}(\mathbf {x})\\[3pt]
      \mathbf{h}_\mathcal{P}(\mathbf {x})\\[3pt]
      \mathbf{h}_\mathcal{Q}(\mathbf {x})\\[3pt]
      \mathbf{h}_{\bar{\mathcal{P}}}(\mathbf {x})
    \end{bmatrix} +
    \begin{bmatrix}
      \mathbf{u}_\mathcal{V}\\[3pt]
      \mathbf{u}_\mathcal{I}\\[3pt]
      \mathbf{u}_\mathcal{P}\\[3pt]
      \mathbf{u}_\mathcal{Q}\\[3pt]
      \mathbf{u}_{\bar{\mathcal{P}}}
    \end{bmatrix}
```

Please note that each error vector, denoted as ``\mathbf{u}_i``, where ``i \in \{\mathcal{V}, \mathcal{I}, \mathcal{P}, \mathcal{Q}\}``, is associated with the variance vector ``\mathbf{v}_i``.  However, for PMUs, the error vector ``\mathbf{u}_{\bar{\mathcal{P}}}``, along with its variance vector ``\mathbf{v}_{\bar{\mathcal{P}}}``, can also be associated with the covariance vector ``\mathbf{w}_{\bar{\mathcal{P}}}``.

In summary, upon user definition of the measurement devices, each ``i``-th legacy measurement device is linked to the measurement function ``h_i(\mathbf {x})``, the corresponding measurement value ``z_i``, and the measurement variance ``v_i``. Meanwhile, each ``i``-th PMU is associated with two measurement functions ``h_{2i-1}(\mathbf x)``, ``h_{2i}(\mathbf x)``, along with their respective measurement values ``z_{2i-1}``, ``z_{2i}``, as well as their variances ``v_{2i-1}``, ``v_{2i}``, and possibly covariances ``w_{2i-1}``, ``w_{2i}``.

Typically, the AC state estimator is obtained using the Gauss-Newton method or its variation, which involves constructing the Jacobian matrix. Therefore, in addition to the aforementioned elements, we also need Jacobian expressions corresponding to the measurement functions, which are also provided below.

---

##### Bus Voltage Magnitude Measurements
When introducing a voltmeter ``V_i \in \mathcal{V}`` at bus ``i \in \mathcal{N}``, users specify the measurement value, variance, and measurement function of vectors:
```math
    \mathbf{z}_\mathcal{V} = [z_{V_i}], \;\;\; \mathbf{v}_\mathcal{V} = [v_{V_i}], \;\;\; \mathbf{h}_\mathcal{V}(\mathbf {x}) = [h_{V_{i}}(\mathbf {x})].
```

For example:
```@example ACSETutorial
addVoltmeter!(system, device; label = "V₁", bus = 1, magnitude = 1.0, variance = 1e-3)
nothing # hide
```

Here, the bus voltage magnitude measurement function is simply defined as:
```math
    h_{V_{i}}(\mathbf {x}) = V_{i},
```

with the following Jacobian expression:
```math
   	\cfrac{\mathrm \partial{{h_{V_{i}}(\mathbf x)}}} {\mathrm \partial V_{i}}=1.
```

---

##### [From-Bus End Current Magnitude Measurements](@id FromCurrentMagnitudeMeasurements)
When introducing an ammeter at branch ``(i,j) \in \mathcal{E}``, it can be placed at the from-bus end, denoted as ``I_{ij} \in \mathcal{I}``, specifying the measurement value, variance, and measurement function of vectors:
```math
    \mathbf{z}_\mathcal{I} = [z_{I_{ij}}], \;\;\; \mathbf{v}_\mathcal{I} = [v_{I_{ij}}], \;\;\; \mathbf{h}_\mathcal{I}(\mathbf {x}) = [h_{I_{ij}}(\mathbf {x})].
```

For example:
```@example ACSETutorial
addAmmeter!(system, device; label = "I₁₂", from = 1, magnitude = 0.3, variance = 1e-2)
nothing # hide
```

Here, following the guidelines outlined in the [AC Model](@ref BranchNetworkEquationsTutorials), the function defining the current magnitude at the from-bus end is expressed as:
```math
    h_{I_{ij}}(\mathbf {x}) = \sqrt{A_{I_{ij}}V_i^2 + B_{I_{ij}}V_j^2 - 2[C_{I_{ij}} \cos(\theta_{ij} - \phi_{ij}) - D_{I_{ij}}\sin(\theta_{ij} - \phi_{ij})]V_iV_j},
```
where:
```math
  \begin{gathered}
    A_{I_{ij}} = \cfrac{(g_{ij} + g_{\text{s}i})^2+(b_{ij}+b_{\text{s}i})^2}{\tau_{ij}^4}, \;\;\; B_{I_{ij}} =  \cfrac{g_{ij}^2+b_{ij}^2}{\tau_{ij}^2} \\
    C_{I_{ij}} = \cfrac{g_{ij}(g_{ij}+g_{\text{s}i})+b_{ij}(b_{ij}+b_{\text{s}i})}{\tau_{ij}^3}, \;\;\; D_{I_{ij}} = \cfrac{g_{ij}b_{\text{s}i} - b_{ij}g_{\text{s}i}}{\tau_{ij}^3}.
  \end{gathered}
```

Jacobian expressions corresponding to the measurement function ``h_{I_{ij}}(\mathbf x)`` are defined as follows:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{I_{ij}}(\mathbf x)}}{\mathrm \partial \theta_{i}} &=-
    \cfrac{\mathrm \partial{h_{I_{ij}}(\mathbf x)}}{\mathrm \partial \theta_{j}} =
    \cfrac{ [C_{I_{ij}}\sin(\theta_{ij} - \phi_{ij}) + D_{I_{ij}}\cos(\theta_{ij} - \phi_{ij})]V_i V_j}{h_{I_{ij}}(\mathbf x)} \\
    \cfrac{\mathrm \partial{h_{I_{ij}}(\mathbf x)}}{\mathrm \partial V_{i}} &=
    \cfrac{A_{I_{ij}}V_i - [C_{I_{ij}}\cos(\theta_{ij} - \phi_{ij}) - D_{I_{ij}}\sin(\theta_{ij} - \phi_{ij})]V_j}{h_{I_{ij}}(\mathbf x)} \\
    \cfrac{\mathrm \partial{h_{I_{ij}}(\mathbf x)}}{\mathrm \partial V_{j}} &=
    \cfrac{B_{I_{ij}}V_j - [C_{I_{ij}}\cos(\theta_{ij} - \phi_{ij}) - D_{I_{ij}}\sin(\theta_{ij} - \phi_{ij})]V_i}{h_{I_{ij}}(\mathbf x)} .
	\end{aligned}
```

---

##### [To-Bus End Current Magnitude Measurements](@id ToCurrentMagnitudeMeasurements)
In addition to the scenario where we add ammeters at the from-bus end, an ammeter can also be positioned at the to-bus end, denoted as ``I_{ji} \in \mathcal{I}``, specifying the measurement value, variance, and measurement function of vectors:
```math
    \mathbf{z}_\mathcal{I} = [z_{I_{ji}}], \;\;\; \mathbf{v}_\mathcal{I} = [v_{I_{ji}}], \;\;\; \mathbf{h}_\mathcal{I}(\mathbf {x}) = [h_{I_{ji}}(\mathbf {x})].
```

For example:
```@example ACSETutorial
addAmmeter!(system, device; label = "I₂₁", to = 1, magnitude = 0.3, variance = 1e-3)
nothing # hide
```

Now, the measurement function is as follows:
```math
    h_{I_{ji}}(\mathbf {x}) = \sqrt{A_{I_{ji}}V_i^2 + B_{I_{ji}}V_j^2 - 2[C_{I_{ji}} \cos(\theta_{ij} - \phi_{ij}) + D_{I_{ji}}\sin(\theta_{ij} - \phi_{ij})]V_iV_j},
```
where:
```math
  \begin{gathered}
    A_{I_{ji}} = \cfrac{g_{ij}^2+b_{ij}^2}{\tau_{ij}^2}, \;\;\; B_{I_{ji}} = (g_{ij} + g_{\text{s}i})^2+(b_{ij}+b_{\text{s}i})^2 \\
    C_{I_{ji}} = \cfrac{g_{ij}(g_{ij}+g_{\text{s}i})+b_{ij}(b_{ij}+b_{\text{s}i})}{\tau_{ij}}, \;\;\; D_{I_{ji}} = \cfrac{g_{ij}b_{\text{s}i} - b_{ij}g_{\text{s}i}}{\tau_{ij}}.
  \end{gathered}
```

Jacobian expressions corresponding to the measurement function ``h_{I_{ji}}(\mathbf x)`` are defined as follows:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{I_{ji}}(\mathbf x)}}{\mathrm \partial \theta_{i}} &=-
    \cfrac{\mathrm \partial{h_{I_{ji}}(\mathbf x)}}{\mathrm \partial \theta_{j}} =
    \cfrac{[C_{I_{ji}}\sin(\theta_{ij} - \phi_{ij}) - D_{I_{ji}}\cos(\theta_{ij}- \phi_{ij})]V_i V_j}{h_{I_{ji}}(\mathbf x)} \\
    \cfrac{\mathrm \partial{h_{I_{ji}}(\mathbf x)}}{\mathrm \partial V_{i}} &=
    \cfrac{A_{I_{ji}}V_i - [C_{I_{ji}}\cos(\theta_{ij} - \phi_{ij}) + D_{I_{ji}}\sin(\theta_{ij} - \phi_{ij})]V_j}{h_{I_{ji}}(\mathbf x)} \\
    \cfrac{\mathrm \partial{h_{I_{ji}}(\mathbf x)}}{\mathrm \partial V_{j}} &=
    \cfrac{B_{I_{ji}}V_j - [C_{I_{ji}}\cos(\theta_{ij} - \phi_{ij}) + D_{I_{ji}}\sin(\theta_{ij} - \phi_{ij})]V_i}{h_{I_{ji}}(\mathbf x)} .
	\end{aligned}
```

---

##### Active Power Injection Measurements
When adding a wattmeter ``P_i \in \mathcal{P}`` at bus ``i \in \mathcal{N}``, users specify that the wattmeter measures active power injection and define measurement value, variance, and measurement function of vectors:
```math
    \mathbf{z}_\mathcal{P} = [z_{P_{i}}], \;\;\; \mathbf{v}_\mathcal{P} = [v_{P_{i}}], \;\;\; \mathbf{h}_\mathcal{P}(\mathbf {x}) = [h_{P_{i}}(\mathbf {x})].
```

For example:
```@example ACSETutorial
addWattmeter!(system, device; label = "P₃", bus = 3, active = -0.5, variance = 1e-3)
nothing # hide
```

Here, utilizing the [AC Model](@ref NodalNetworkEquationsTutorials), we derive the function defining the active power injection as follows:
```math
   h_{P_{i}}(\mathbf {x}) = {V}_{i}\sum\limits_{j \in \mathcal{N}_i} (G_{ij}\cos\theta_{ij} + B_{ij}\sin\theta_{ij}){V}_{j},
```
where ``\mathcal{N}_i`` contains buses incident to bus ``i``, including bus ``i``, with the following Jacobian expressions:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{P_{i}}(\mathbf x)}}{\mathrm \partial \theta_{i}} &=
    {V}_{i}\sum_{j \in \mathcal{N}_i} (-G_{ij}\sin\theta_{ij}+B_{ij}\cos\theta_{ij}){V}_{j}  - B_{ii}V_i^2\\
    \cfrac{\mathrm \partial{h_{P_{i}}(\mathbf x)}}{\mathrm \partial \theta_{j}} &=
    (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}){V}_{i}{V}_{j} \\
    \cfrac{\mathrm \partial{h_{P_{i}}(\mathbf x)}}{\mathrm \partial V_{i}} &=
    \sum_{j \in \mathcal{N}_i} (G_{ij}\cos\theta_{ij}+B_{ij} \sin\theta_{ij})V_{j} + G_{ii} V_i\\
    \cfrac{\mathrm \partial{h_{P_{i}}(\mathbf x)}}{\mathrm \partial V_{j}} &=
    (G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij}){V}_{i}.
  \end{aligned}
```

---

##### From-Bus End Active Power Flow Measurements
Additionally, when introducing a wattmeter at branch ``(i,j) \in \mathcal{E}``, users specify that the wattmeter measures active power flow. It can be positioned at the from-bus end, denoted as ``P_{ij} \in \mathcal{P}``, specifying the measurement value, variance, and measurement function of vectors:
```math
    \mathbf{z}_\mathcal{P} = [z_{P_{ij}}], \;\;\; \mathbf{v}_\mathcal{P} = [v_{P_{ij}}], \;\;\; \mathbf{h}_\mathcal{P}(\mathbf {x}) = [h_{P_{ij}}(\mathbf {x})].
```

For example:
```@example ACSETutorial
addWattmeter!(system, device; label = "P₁₂", from = 1, active = 0.2, variance = 1e-4)
nothing # hide
```

Here, the function describing active power flow at the from-bus end is defined as follows:
```math
    h_{P_{ij}}(\mathbf {x}) = \cfrac{g_{ij} + g_{\text{s}i}}{\tau_{ij}^2} V_{i}^2 - \cfrac{1}{\tau_{ij}} \left[g_{ij}\cos(\theta_{ij} - \phi_{ij}) + b_{ij}\sin(\theta_{ij} - \phi_{ij})\right]V_{i}V_{j},
```
with the following Jacobian expressions:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{P_{ij}}(\mathbf x)}}{\mathrm \partial \theta_{i}} &=-
    \cfrac{\mathrm \partial{h_{P_{ij}}(\mathbf x)}}{\mathrm \partial \theta_{j}} =
    \cfrac{1}{\tau_{ij}} \left[g_{ij}\sin(\theta_{ij} - \phi_{ij}) - b_{ij}\cos(\theta_{ij} - \phi_{ij})\right] V_{i}V_{j} \\
    \cfrac{\mathrm \partial{h_{P_{ij}}(\mathbf x)}}{\mathrm \partial V_{i}} &=
    2\cfrac{g_{ij} + g_{\text{s}i}}{\tau_{ij}^2} V_{i} -
    \cfrac{1}{\tau_{ij}} \left[g_{ij}\cos(\theta_{ij} - \phi_{ij}) + b_{ij}\sin(\theta_{ij} - \phi_{ij})\right] V_{j} \\
    \cfrac{\mathrm \partial{h_{P_{ij}}(\mathbf x)}}{\mathrm \partial V_{j}} &= -
    \cfrac{1}{\tau_{ij}} \left[g_{ij} \cos(\theta_{ij} - \phi_{ij}) + b_{ij} \sin(\theta_{ij} - \phi_{ij})\right] V_{i}.
	\end{aligned}
```

---

##### To-Bus End Active Power Flow Measurements
Similarly, a wattmeter can be placed at the to-bus end, denoted as ``P_{ji} \in \mathcal{P}``, specifying the measurement value, variance, and measurement function of vectors:
```math
    \mathbf{z}_\mathcal{P} = [z_{P_{ji}}], \;\;\; \mathbf{v}_\mathcal{P} = [v_{P_{ji}}], \;\;\; \mathbf{h}_\mathcal{P}(\mathbf {x}) = [h_{P_{ji}}(\mathbf {x})].
```

For example:
```@example ACSETutorial
addWattmeter!(system, device; label = "P₂₁", to = 1, active = -0.2, variance = 1e-4)
nothing # hide
```

Thus, the function describing active power flow at the to-bus end is defined as follows:
```math
    h_{P_{ji}}(\mathbf {x}) = (g_{ij} + g_{\text{s}i}) V_{j}^2 - \cfrac{1}{\tau_{ij}} \left[g_{ij} \cos(\theta_{ij} - \phi_{ij}) - b_{ij} \sin(\theta_{ij}- \phi_{ij})\right] V_{i} V_j,
```
with the following Jacobian expressions:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{P_{ji}}(\mathbf x)}}{\mathrm \partial \theta_{i}} &= -
    \cfrac{\mathrm \partial{h_{P_{ji}}(\mathbf x)}}{\mathrm \partial \theta_{j}} =
    \cfrac{1}{\tau_{ij}} \left[g_{ij}\sin(\theta_{ij} - \phi_{ij}) + b_{ij}\cos(\theta_{ij} - \phi_{ij})\right] V_{i}V_{j} \\
    \cfrac{\mathrm \partial{h_{P_{ji}}(\mathbf x)}}{\mathrm \partial V_{i}} &=  -
    \cfrac{1}{\tau_{ij}} \left[g_{ij} \cos(\theta_{ij} - \phi_{ij}) - b_{ij} \sin(\theta_{ij} - \phi_{ij})\right] V_j \\
    \cfrac{\mathrm \partial{h_{P_{ji}}(\mathbf x)}}{\mathrm \partial V_{j}} &= 2(g_{ij} + g_{\text{s}i}) V_{j}-
    \cfrac{1}{\tau_{ij}} \left[g_{ij} \cos(\theta_{ij} - \phi_{ij}) - b_{ij} \sin(\theta_{ij} - \phi_{ij})\right] V_{i}.
	\end{aligned}
```

---

##### Reactive Power Injection Measurements
When adding a varmeter ``Q_i \in \mathcal{Q}`` at bus ``i \in \mathcal{N}``, users specify that the varmeter measures reactive power injection and define the measurement value, variance, and measurement function of vectors:
```math
    \mathbf{z}_\mathcal{Q} = [z_{Q_{i}}], \;\;\; \mathbf{v}_\mathcal{Q} = [v_{Q_{i}}], \;\;\; \mathbf{h}_\mathcal{Q}(\mathbf {x}) = [h_{Q_{i}}(\mathbf {x})].
```

For example:
```@example ACSETutorial
addVarmeter!(system, device; label = "Q₃", bus = 3, reactive = 0, variance = 1e-3)
nothing # hide
```

Here, utilizing the [AC Model](@ref NodalNetworkEquationsTutorials), we derive the function defining the reactive power injection as follows:
```math
   h_{Q_{i}}(\mathbf {x}) = {V}_{i}\sum\limits_{j \in \mathcal{N}_i} (G_{ij}\sin\theta_{ij} - B_{ij}\cos\theta_{ij}){V}_{j},
```
where ``\mathcal{N}_i`` contains buses incident to bus ``i``, including bus ``i``, with the following Jacobian expressions:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{Q_{i}}(\mathbf x)}}{\mathrm \partial \theta_{i}} &=
    {V}_{i}\sum_{j \in \mathcal{N}_i} (G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij}){V}_{j} - G_{ii}V_i^2\\
    \cfrac{\mathrm \partial{h_{Q_{i}}(\mathbf x)}}{\mathrm \partial \theta_{j}} &=
    -(G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij}){V}_{i}{V}_{j} \\
    \cfrac{\mathrm \partial{h_{Q_{i}}(\mathbf x)}}{\mathrm \partial V_{i}} &=
    \sum_{j \in \mathcal{N}_i} (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}){V}_{j} - B_{ii}{V}_{i}\\
    \cfrac{\mathrm \partial{h_{Q_{i}}(\mathbf x)}}{\mathrm \partial V_{j}} &=
    (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}){V}_{i}.
  \end{aligned}
```

---

##### From-Bus End Reactive Power Flow Measurements
Additionally, when introducing a varmeter at branch ``(i,j) \in \mathcal{E}``, users specify that the varmeter measures reactive power flow. It can be positioned at the from-bus end, denoted as ``Q_{ij} \in \mathcal{Q}``, with its measurement value, variance, and measurement function included in vectors:
```math
    \mathbf{z}_\mathcal{Q} = [z_{Q_{ij}}], \;\;\; \mathbf{v}_\mathcal{Q} = [v_{Q_{ij}}], \;\;\; \mathbf{h}_\mathcal{Q}(\mathbf {x}) = [h_{Q_{ij}}(\mathbf {x})].
```

For example:
```@example ACSETutorial
addVarmeter!(system, device; label = "Q₁₂", from = 1, reactive = 0.2, variance = 1e-4)
nothing # hide
```

Here, the function describing reactive power flow at the from-bus end is defined as follows:
```math
    h_{Q_{ij}}(\mathbf {x}) = -\cfrac{b_{ij} + b_{\text{s}i}}{\tau_{ij}^2} V_{i}^2 - \cfrac{1}{\tau_{ij}}  \left[g_{ij}\sin(\theta_{ij} - \phi_{ij}) - b_{ij}\cos(\theta_{ij} - \phi_{ij})\right] V_{i}V_{j},
```
with the following Jacobian expressions:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{Q_{ij}}(\mathbf x)}}{\mathrm \partial \theta_{i}} &= -
    \cfrac{\mathrm \partial{h_{Q_{ij}}(\mathbf x)}}{\mathrm \partial \theta_{j}} = -
    \cfrac{1}{\tau_{ij}}  \left[g_{ij}\cos(\theta_{ij} - \phi_{ij}) + b_{ij}\sin(\theta_{ij} - \phi_{ij})\right] V_{i}V_{j} \\
    \cfrac{\mathrm \partial{h_{Q_{ij}}(\mathbf x)}}{\mathrm \partial V_{i}} &= -
    2\cfrac{b_{ij} + b_{\text{s}i}}{\tau_{ij}^2} V_{i} -
    \cfrac{1}{\tau_{ij}}  \left[g_{ij}\sin(\theta_{ij} - \phi_{ij}) - b_{ij}\cos(\theta_{ij} - \phi_{ij})\right] V_{j}\\
    \cfrac{\mathrm \partial{h_{Q_{ij}}(\mathbf x)}}{\mathrm \partial V_{j}} &= -
    \cfrac{1}{\tau_{ij}}  \left[g_{ij}\sin(\theta_{ij} - \phi_{ij}) - b_{ij}\cos(\theta_{ij} - \phi_{ij})\right] V_{i}.
	\end{aligned}
```

---

##### To-Bus End Reactive Power Flow Measurements
Similarly, a varmeter can be placed at the to-bus end, denoted as ``Q_{ji} \in \mathcal{Q}``, with its own measurement value, variance, and measurement function included in vectors:
```math
    \mathbf{z}_\mathcal{Q} = [z_{Q_{ji}}], \;\;\; \mathbf{v}_\mathcal{Q} = [v_{Q_{ji}}], \;\;\; \mathbf{h}_\mathcal{Q}(\mathbf {x}) = [h_{Q_{ji}}(\mathbf {x})].
```

For example:
```@example ACSETutorial
addVarmeter!(system, device; label = "Q₂₁", to = 1, reactive = -0.2, variance = 1e-4)
nothing # hide
```

Thus, the function describing reactive power flow at the to-bus end is defined as follows:
```math
    h_{Q_{ji}}(\mathbf {x}) = -(b_{ij} + b_{\text{s}i}) V_{j}^2 + \cfrac{1}{\tau_{ij}} \left[g_{ij} \sin(\theta_{ij} - \phi_{ij}) + b_{ij} \cos(\theta_{ij} - \phi_{ij})\right] V_{i}V_{j},
```
with the following Jacobian expressions:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{Q_{ji}}(\mathbf x)}}{\mathrm \partial \theta_{i}} &= -
    \cfrac{\mathrm \partial{h_{Q_{ji}}(\mathbf x)}}{\mathrm \partial \theta_{j}} =
    \cfrac{1}{\tau_{ij}}  \left[g_{ij}\cos(\theta_{ij} - \phi_{ij}) - b_{ij}\sin(\theta_{ij} - \phi_{ij})\right] V_{i}V_{j} \\
    \cfrac{\mathrm \partial{h_{Q_{ji}}(\mathbf x)}}{\mathrm \partial V_{i}} &=
    \cfrac{1}{\tau_{ij}} \left[g_{ij} \sin(\theta_{ij} - \phi_{ij}) + b_{ij} \cos(\theta_{ij} - \phi_{ij})\right] V_{j}\\
    \cfrac{\mathrm \partial{h_{Q_{ji}}(\mathbf x)}}{\mathrm \partial V_{j}} &= -
    2(b_{ij} + b_{\text{s}i}) V_{j} +
    \cfrac{1}{\tau_{ij}} \left[g_{ij} \sin(\theta_{ij} - \phi_{ij}) + b_{ij} \cos(\theta_{ij} - \phi_{ij})\right] V_{i}.
	\end{aligned}
```

---

##### Rectangular Bus Voltage Phasor Measurements
When a PMU ``(V_i, \theta_i) \in \bar{\mathcal{P}}`` is introduced at bus ``i \in \mathcal{N}``, it will be incorporated into the AC state estimation model using rectangular coordinates by default. It will define the measurement values, variances, and measurement functions of vectors:
```math
    \mathbf{z}_{\bar{\mathcal{P}}} = [z_{\Re(\bar{V}_{i})}, z_{\Im(\bar{V}_{i})}], \;\;\; \mathbf{v}_{\bar{\mathcal{P}}} = [v_{\Re(\bar{V}_{i})}, v_{\Im(\bar{V}_{i})}], \;\;\; \mathbf{h}_{\bar{\mathcal{P}}}(\mathbf {x}) = [h_{\Re(\bar{V}_{i})}(\mathbf {x}), h_{\Im(\bar{V}_{i})}(\mathbf {x})].
```

For example:
```@example ACSETutorial
addPmu!(system, device; label = "V₂, θ₂", bus = 2, magnitude = 0.9, angle = -0.1,
varianceMagnitude = 1e-5, varianceAngle = 1e-5)
nothing # hide
```

Here, measurement values are obtained according to:
```math
  \begin{aligned}
    z_{\Re(\bar{V}_i)} = z_{V_i} \cos z_{\theta_i}\\
    z_{\Im(\bar{V}_i)} = z_{V_i} \sin z_{\theta_i}.
  \end{aligned}
```

Utilizing the classical theory of propagation of uncertainty [iso1993guide](@cite), the variances can be calculated as follows:
```math
  \begin{aligned}
    v_{\Re(\bar{V}_i)} &=
    v_{V_i} \left[ \cfrac{\mathrm \partial} {\mathrm \partial z_{V_i}} (z_{V_i} \cos z_{\theta_i}) \right]^2 +
    v_{\theta_i} \left[ \cfrac{\mathrm \partial} {\mathrm \partial z_{\theta_i}} (z_{V_i} \cos z_{\theta_i})\right]^2 =
    v_{V_i} (\cos z_{\theta_i})^2 + v_{\theta_i} (z_{V_i} \sin z_{\theta_i})^2\\
    v_{\Im(\bar{V}_i)} &=
     v_{V_i} \left[ \cfrac{\mathrm \partial} {\mathrm \partial z_{V_i}} (z_{V_i} \sin z_{\theta_i}) \right]^2 +
    v_{\theta_i} \left[ \cfrac{\mathrm \partial} {\mathrm \partial z_{\theta_i}} (z_{V_i} \sin z_{\theta_i})\right]^2 =
    v_{V_i} (\sin z_{\theta_i})^2 + v_{\theta_i} (z_{V_i} \cos z_{\theta_i})^2.
  \end{aligned}
```

Lastly, the functions defining the bus voltage phasor measurement are:
```math
  \begin{aligned}
    h_{\Re(\bar{V}_{i})}(\mathbf {x}) = V_{i}\cos \theta_i\\
    h_{\Im(\bar{V}_{i})}(\mathbf {x}) = V_{i}\sin \theta_i.
  \end{aligned}
```

Jacobian expressions corresponding to the measurement function ``h_{\Re(\bar{V}_{i})}(\mathbf x)`` are defined as follows:
```math
  \begin{aligned}
   	\cfrac{\mathrm \partial{h_{\Re(\bar{V}_{i})}(\mathbf x)}}{\mathrm \partial \theta_{i}}=-V_{i}\sin \theta_i, \;\;\;
   	\cfrac{\mathrm \partial{h_{\Re(\bar{V}_{i})}(\mathbf x)}}{\mathrm \partial V_{i}}=\cos \theta_i,
    \end{aligned}
```
while Jacobian expressions corresponding to the measurement function ``h_{\Im(\bar{V}_{i})}(\mathbf x)`` are:
```math
  \begin{aligned}
   	\cfrac{\mathrm \partial{h_{\Im(\bar{V}_{i})}(\mathbf x)}}{\mathrm \partial \theta_{i}}=V_{i}\cos \theta_i,\;\;\;
   	\cfrac{\mathrm \partial{h_{\Im(\bar{V}_{i})}(\mathbf x)}}{\mathrm \partial V_{i}}=\sin \theta_i.
  \end{aligned}
```

In the previous example, the user neglects the covariances between the real and imaginary parts of the measurement. However, if desired, the user can also include them in the state estimation model by specifying the covariances of the vector:
```math
    \mathbf{w}_{\bar{\mathcal{P}}} = [w_{\Re(\bar{V}_{i})}, w_{\Im(\bar{V}_{i})}].
```
```@example ACSETutorial
addPmu!(system, device; label = "V₃, θ₃", bus = 3, magnitude = 0.9, angle = -0.2,
varianceMagnitude = 1e-5, varianceAngle = 1e-5, correlated = true)
nothing # hide
```

Then, the covariances are obtained as follows:
```math
    w_{\Re(\bar{V}_{i})} = w_{\Im(\bar{V}_{i})} =
    v_{V_i} \cfrac{\mathrm \partial} {\mathrm \partial z_{V_i}} (z_{V_i} \cos z_{\theta_i})
    \cfrac{\mathrm \partial} {\mathrm \partial z_{V_i}} (z_{V_i} \sin z_{\theta_i})  +
    v_{\theta_i} \cfrac{\mathrm \partial} {\mathrm \partial z_{\theta_i}} (z_{V_i} \cos z_{\theta_i})
    \cfrac{\mathrm \partial} {\mathrm \partial z_{\theta_i}} (z_{V_i} \sin z_{\theta_i}),
```
which results in the solution:
```math
    w_{\Re(\bar{V}_{i})} = w_{\Im(\bar{V}_{i})} = \cos z_{\theta_i} \sin z_{\theta_i}(v_{V_i} - v_{\theta_i} z_{V_i}^2).
```

---

##### Polar Bus Voltage Phasor Measurements
If the user chooses to include phasor measurement ``(V_i, \theta_i) \in \bar{\mathcal{P}}`` in polar coordinates in the AC state estimation model, the user will specify the measurement values, variances, and measurement functions of vectors:
```math
    \mathbf{z}_{\bar{\mathcal{P}}} = [z_{V_i}, z_{\theta_i}], \;\;\; \mathbf{v}_{\bar{\mathcal{P}}} = [v_{V_i}, v_{\theta_i}], \;\;\; \mathbf{h}_{\bar{\mathcal{P}}}(\mathbf {x}) = [h_{V_{i}}(\mathbf {x}), h_{\theta_{i}}(\mathbf {x})].
```

For example:
```@example ACSETutorial
addPmu!(system, device; label = "V₁, θ₁", bus = 1, magnitude = 1.0, angle = 0,
varianceMagnitude = 1e-5, varianceAngle = 1e-6, polar = true)
nothing # hide
```

Here, the functions defining the bus voltage phasor measurement are straightforward:
```math
  \begin{aligned}
    h_{V_{i}}(\mathbf {x}) = V_{i}\\
    h_{\theta_{i}}(\mathbf {x}) = \theta_{i},
  \end{aligned}
```
with the following Jacobian expressions:
```math
  \begin{aligned}
   	\cfrac{\mathrm \partial{{h_{{V}_{i}}(\mathbf x)}}}{\mathrm \partial V_{i}}=1, \;\;\;
    \cfrac{\mathrm \partial{{h_{\theta_i}(\mathbf x)}}}{\mathrm \partial \theta_{i}}=1.
    \end{aligned}
```

---

##### Rectangular From-Bus End Current Phasor Measurements
When introducing a PMU at branch ``(i,j) \in \mathcal{E}``, it can be placed at the from-bus end, denoted as ``(I_{ij}, \psi_{ij}) \in \bar{\mathcal{P}}``, and it will be integrated into the AC state estimation model using rectangular coordinates by default. Incorporating current phasor measurements in the polar coordinate system is highly susceptible to ill-conditioned problems, especially when dealing with small values of current magnitudes. This is the reason why we typically include PMUs in the rectangular coordinate system by default.

Therefore, here we specify the measurement values, variances, and measurement functions of vectors:
```math
    \mathbf{z}_{\bar{\mathcal{P}}} = [z_{\Re(\bar{I}_{ij})}, z_{\Im(\bar{I}_{ij})}], \;\;\; \mathbf{v}_{\bar{\mathcal{P}}} = [v_{\Re(\bar{I}_{ij})}, v_{\Im(\bar{I}_{ij})}], \;\;\; \mathbf{h}_{\bar{\mathcal{P}}}(\mathbf {x}) = [h_{\Re(\bar{I}_{ij})}(\mathbf {x}), h_{\Im(\bar{I}_{ij})}(\mathbf {x})].
```

For example:
```@example ACSETutorial
addPmu!(system, device; label = "I₂₃, ψ₂₃", from = 3, magnitude = 0.3, angle = 0.4,
varianceMagnitude = 1e-5, varianceAngle = 1e-4)
nothing # hide
```

Here, measurement values are obtained according to:
```math
  \begin{aligned}
    z_{\Re(\bar{I}_{ij})} = z_{I_{ij}} \cos z_{\psi_{ij}}\\
    z_{\Im(\bar{I}_{ij})} = z_{I_{ij}} \sin z_{\psi_{ij}}.
  \end{aligned}
```

Utilizing the classical theory of propagation of uncertainty [iso1993guide](@cite), the variances can be calculated as follows:
```math
  \begin{aligned}
    v_{\Re(\bar{I}_{ij})} & = v_{I_{ij}} (\cos z_{\psi_{ij}})^2 + v_{\psi_{ij}} (z_{I_{ij}} \sin z_{\psi_{ij}})^2 \\
    v_{\Im(\bar{I}_{ij})} &= v_{I_{ij}} (\sin z_{\psi_{ij}})^2 + v_{\psi_{ij}} (z_{I_{ij}} \cos z_{\psi_{ij}})^2.
  \end{aligned}
```

The functions defining the current phasor measurement at the from-bus end are:
```math
  \begin{aligned}
    h_{\Re(\bar{I}_{ij})}(\mathbf {x}) &= (A_{\psi_{ij}} \cos \theta_i - B_{\psi_{ij}} \sin \theta_i)V_i - [C_{\psi_{ij}} \cos (\theta_j + \phi_{ij}) - D_{\psi_{ij}} \sin (\theta_j + \phi_{ij})]V_j, \\
    h_{\Im(\bar{I}_{ij})}(\mathbf {x}) &= (A_{\psi_{ij}} \sin \theta_i + B_{\psi_{ij}} \cos \theta_i)V_i - [C_{\psi_{ij}} \sin (\theta_j + \phi_{ij}) + D_{\psi_{ij}} \cos (\theta_j + \phi_{ij})]V_j.
  \end{aligned}
```

Jacobian expressions corresponding to the measurement function ``h_{\Re(\bar{I}_{ij})}(\mathbf x)`` are defined as follows:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ij})}(\mathbf x)}}{\mathrm \partial \theta_{i}} &=
    -(A_{\psi_{ij}} \sin \theta_{i} + B_{\psi_{ij}} \cos \theta_{i})V_i\\
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ij})}(\mathbf x)}}{\mathrm \partial \theta_{j}} &=
    [C_{\psi_{ij}} \sin(\theta_j + \phi_{ij}) + D_{\psi_{ij}} \cos(\theta_j + \phi_{ij})] V_j \\
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ij})}(\mathbf x)}}{\mathrm \partial V_{i}} &=
     A_{\psi_{ij}}  \cos \theta_{i} - B_{\psi_{ij}}  \sin\theta_{i}\\
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ij})}(\mathbf x)}}{\mathrm \partial V_{j}} &=
    -C_{\psi_{ij}} \cos(\theta_j + \phi_{ij}) + D_{\psi_{ij}}  \sin(\theta_j + \phi_{ij}).
  \end{aligned}
```
while Jacobian expressions corresponding to the measurement function ``h_{\Im(\bar{I}_{ij})}(\mathbf x)`` are:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ij})}(\mathbf x)}}{\mathrm \partial \theta_{i}} &=
    (A_{\psi_{ij}} \cos \theta_{i} - B_{\psi_{ij}} \sin \theta_{i})V_i\\
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ij})}(\mathbf x)}}{\mathrm \partial \theta_{j}} &=
    [-C_{\psi_{ij}} \cos(\theta_j + \phi_{ij}) + D_{\psi_{ij}} \sin(\theta_j + \phi_{ij})] V_j \\
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ij})}(\mathbf x)}}{\mathrm \partial V_{i}} &=
     A_{\psi_{ij}}  \sin \theta_{i} + B_{\psi_{ij}}  \cos\theta_{i}\\
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ij})}(\mathbf x)}}{\mathrm \partial V_{j}} &=
    -C_{\psi_{ij}} \sin(\theta_j + \phi_{ij}) - D_{\psi_{ij}}  \cos(\theta_j + \phi_{ij}).
  \end{aligned}
```

In the previous example, the user neglects the covariances between the real and imaginary parts of the measurement. However, if desired, the user can also include them in the state estimation model by specifying the covariances of the vector:
```math
    \mathbf{w}_{\bar{\mathcal{P}}} = [w_{\Re(\bar{I}_{ij})}, w_{\Im(\bar{I}_{ij})}].
```
```@example ACSETutorial
addPmu!(system, device; label = "I₁₃, ψ₁₃", from = 2, magnitude = 0.3, angle = -0.5,
varianceMagnitude = 1e-4, varianceAngle = 1e-5, correlated = true)
nothing # hide
```

Then, the covariances are obtained as follows:
```math
   w_{\Re(\bar{I}_{ij})} = w_{\Im(\bar{I}_{ij})} = \sin z_{\psi_{ij}} \cos z_{\psi_{ij}}(v_{I_{ij}}  - v_{\psi_{ij}} z_{I_{ij}}^2).
```

---

##### Polar From-Bus End Current Phasor Measurements
If the user chooses to include phasor measurement ``(I_{ij}, \psi_{ij}) \in \bar{\mathcal{P}}`` in polar coordinates in the AC state estimation model, the user will specify the measurement values, variances, and measurement functions of vectors:
```math
    \mathbf{z}_{\bar{\mathcal{P}}} = [z_{I_{ij}}, z_{\psi_{ij}}], \;\;\; \mathbf{v}_{\bar{\mathcal{P}}} = [v_{I_{ij}}, v_{\psi_{ij}}], \;\;\; \mathbf{h}_{\bar{\mathcal{P}}}(\mathbf {x}) = [h_{I_{ij}}(\mathbf {x}), h_{\psi_{ij}}(\mathbf {x})].
```

For example:
```@example ACSETutorial
addPmu!(system, device; label = "I₁₂, ψ₁₂", from = 1, magnitude = 0.3, angle = -0.7,
varianceMagnitude = 1e-5, varianceAngle = 1e-4, polar = true)
nothing # hide
```

Here, the function associated with the branch current magnitude at the from-bus end remains identical to the one provided in [From-Bus End Current Magnitude Measurements](@ref FromCurrentMagnitudeMeasurements). However, the function defining the branch current angle measurement is expressed as:
```math
    h_{\psi_{ij}}(\mathbf {x}) = \mathrm{atan}\Bigg[
    \cfrac{(A_{\psi_{ij}} \sin\theta_i + B_{\psi_{ij}} \cos\theta_i)V_i - [C_{\psi_{ij}} \sin(\theta_{j}+\phi_{ij}) + D_{\psi_{ij}}\cos(\theta_{j}+\phi_{ij})]V_j}
    {(A_{\psi_{ij}} \cos\theta_i - B_{\psi_{ij}} \sin\theta_i)V_i - [C_{\psi_{ij}} \cos(\theta_{j}+\phi_{ij}) - D_{\psi_{ij}} \sin(\theta_{j}+\phi_{ij})]V_j} \Bigg],
```
where:
```math
    A_{\psi_{ij}} = \cfrac{g_{ij} + g_{\text{s}i}}{\tau_{ij}^2}, \;\;\; B_{\psi_{ij}} = \cfrac{b_{ij}+b_{\text{s}i}}{\tau_{ij}^2}, \;\;\;
    C_{\psi_{ij}} = \cfrac{g_{ij}}{\tau_{ij}}, \;\;\; D_{\psi_{ij}} = \cfrac{b_{ij}}{\tau_{ij}}.
```

Jacobian expressions associated with the branch current magnitude function ``h_{I_{ij}}(\mathbf x)`` remains identical to the one provided in [From-Bus End Current Magnitude Measurements](@ref FromCurrentMagnitudeMeasurements). Further, Jacobian expressions corresponding to the measurement function ``h_{\psi_{ij}}(\mathbf x)`` are defined as follows:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{\psi_{ij}}(\mathbf x)}}{\mathrm \partial \theta_{i}} &=
    \cfrac{A_{I_{ij}} V_i^2- [C_{I_{ij}} \cos(\theta_{ij}- \phi_{ij}) - D_{I_{ij}} \sin (\theta_{ij} - \phi_{ij}) ]V_iV_j}{h_{{I}_{ij}}^2(\mathbf x)} \\
    \cfrac{\mathrm \partial{h_{\psi_{ij}}(\mathbf x)}}{\mathrm \partial \theta_{j}} &=
    \cfrac{B_{I_{ij}} V_j^2 - [C_{I_{ij}} \cos (\theta_{ij} - \phi_{ij}) - D_{I_{ij}} \sin(\theta_{ij}- \phi_{ij})]V_iV_j}{h_{{I}_{ij}}^2(\mathbf x)} \\
    \cfrac{\mathrm \partial{h_{\psi_{ij}}(\mathbf x)}}{\mathrm \partial V_{i}} &= -
    \cfrac{[C_{I_{ij}} \sin (\theta_{ij} - \phi_{ij}) + D_{I_{ij}} \cos(\theta_{ij}- \phi_{ij})]V_j }{h_{{I}_{ij}}^2(\mathbf x)}\\
    \cfrac{\mathrm \partial{h_{\psi_{ij}}(\mathbf x)}}{\mathrm \partial V_{j}} &=
    \cfrac{[C_{I_{ij}} \sin (\theta_{ij} - \phi_{ij}) + D_{I_{ij}} \cos(\theta_{ij}- \phi_{ij})]V_i }{h_{{I}_{ij}}^2(\mathbf x)}.
  \end{aligned}
```

---

##### Rectangular To-Bus End Current Phasor Measurements
When introducing a PMU at branch ``(i,j) \in \mathcal{E}``, it can be placed at the to-bus end, denoted as ``(I_{ji}, \psi_{ji}) \in \bar{\mathcal{P}}``, and it will be integrated into the AC state estimation model using rectangular coordinates by default. The user will specify the measurement values, variances, and measurement functions of vectors:
```math
    \mathbf{z}_{\bar{\mathcal{P}}} = [z_{\Re(\bar{I}_{ji})}, z_{\Im(\bar{I}_{ji})}], \;\;\; \mathbf{v}_{\bar{\mathcal{P}}} = [v_{\Re(\bar{I}_{ji})}, v_{\Im(\bar{I}_{ji})}], \;\;\; \mathbf{h}_{\bar{\mathcal{P}}}(\mathbf {x}) = [h_{\Re(\bar{I}_{ji})}(\mathbf {x}), h_{\Im(\bar{I}_{ji})}(\mathbf {x})].
```

For example:
```@example ACSETutorial
addPmu!(system, device; label = "I₃₂, ψ₃₂", to = 3, magnitude = 0.3, angle = -2.9,
varianceMagnitude = 1e-5, varianceAngle = 1e-5)
nothing # hide
```

Here, measurement values are obtained according to:
```math
  \begin{aligned}
    z_{\Re(\bar{I}_{ji})} = z_{I_{ji}} \cos z_{\psi_{ji}}\\
    z_{\Im(\bar{I}_{ji})} = z_{I_{ji}} \sin z_{\psi_{ji}}.
  \end{aligned}
```

The variances can be calculated as follows:
```math
  \begin{aligned}
    v_{\Re(\bar{I}_{ji})} &= v_{I_{ji}} (\cos z_{\psi_{ji}})^2 + v_{\psi_{ji}} (z_{I_{ji}} \sin z_{\psi_{ji}})^2 \\
    v_{\Im(\bar{I}_{ji})} &= v_{I_{ji}} (\sin z_{\psi_{ji}})^2 + v_{\psi_{ji}} (z_{I_{ji}} \cos z_{\psi_{ji}})^2.
  \end{aligned}
```

The functions defining the current phasor measurement at the to-bus end are:
```math
  \begin{aligned}
    h_{\Re(\bar{I}_{ji})}(\mathbf {x}) &= (A_{\psi_{ji}} \cos \theta_j - B_{\psi_{ji}} \sin \theta_j)V_j - [C_{\psi_{ji}} \cos (\theta_i - \phi_{ij}) - D_{\psi_{ji}} \sin (\theta_i + \phi_{ij})]V_i\\
    h_{\Im(\bar{I}_{ji})}(\mathbf {x}) &= (A_{\psi_{ji}} \sin \theta_j + B_{\psi_{ji}} \cos \theta_j)V_j - [C_{\psi_{ji}} \sin (\theta_i + \phi_{ij}) + D_{\psi_{ji}} \cos (\theta_i + \phi_{ij})]V_i.
  \end{aligned}
```

Jacobian expressions corresponding to the measurement function ``h_{\Re(\bar{I}_{ji})}(\mathbf x)`` are defined as follows:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ji})}(\mathbf x)}}{\mathrm \partial \theta_{i}} &=
    [C_{\psi_{ji}} \sin (\theta_{i} - \phi_{ij}) + D_{\psi_{ji}} \cos (\theta_{i} - \phi_{ij})]V_i\\
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ji})}(\mathbf x)}}{\mathrm \partial \theta_{j}} &=
    -(A_{\psi_{ji}} \sin\theta_j + B_{\psi_{ji}} \cos \theta_j ) V_j \\
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ji})}(\mathbf x)}}{\mathrm \partial V_{i}} &=
    - C_{\psi_{ji}} \cos (\theta_{i} - \phi_{ij}) + D_{\psi_{ji}}  \sin(\theta_{i} - \phi_{ij})\\
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ji})}(\mathbf x)}}{\mathrm \partial V_{j}} &=
    A_{\psi_{ji}} \cos \theta_j - B_{\psi_{ji}}  \sin \theta_j.
  \end{aligned}
```
while Jacobian expressions corresponding to the measurement function ``h_{\Im(\bar{I}_{ji})}(\mathbf x)`` are:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ji})}(\mathbf x)}}{\mathrm \partial \theta_{i}} &=
    [-C_{\psi_{ji}} \cos (\theta_{i} - \phi_{ij}) + D_{\psi_{ji}} \sin (\theta_{i} - \phi_{ij})]V_i\\
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ji})}(\mathbf x)}}{\mathrm \partial \theta_{j}} &=
    (A_{\psi_{ji}} \cos\theta_j - B_{\psi_{ji}} \sin \theta_j ) V_j \\
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ji})}(\mathbf x)}}{\mathrm \partial V_{i}} &=
    - C_{\psi_{ji}} \sin (\theta_{i} - \phi_{ij}) - D_{\psi_{ji}}  \cos(\theta_{i} - \phi_{ij})\\
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ji})}(\mathbf x)}}{\mathrm \partial V_{j}} &=
    A_{\psi_{ji}} \sin \theta_j + B_{\psi_{ji}}  \cos \theta_j.
  \end{aligned}
```

As before, we are neglecting the covariances between the real and imaginary parts of the measurement. If desired, we can include them in the state estimation model by specifying the covariances of the vector:
```math
    \mathbf{w}_{\bar{\mathcal{P}}} = [w_{\Re(\bar{I}_{ji})}, w_{\Im(\bar{I}_{ji})}].
```
```@example ACSETutorial
addPmu!(system, device; label = "I₃₁, ψ₃₁", to = 2, magnitude = 0.3, angle = 2.5,
varianceMagnitude = 1e-5, varianceAngle = 1e-5, correlated = true)
nothing # hide
```

Then, the covariances are obtained as follows:
```math
   w_{\Re(\bar{I}_{ji})} = w_{\Im(\bar{I}_{ji})} = \sin z_{\psi_{ji}} \cos z_{\psi_{ji}}(v_{I_{ji}} - v_{\psi_{ji}} z_{I_{ji}}^2).
```

---

##### Polar To-Bus End Current Phasor Measurements
If the user chooses to include phasor measurement ``(I_{ji}, \psi_{ji}) \in \bar{\mathcal{P}}`` in polar coordinates in the AC state estimation model, the user will specify the measurement values, variances, and measurement functions of vectors:
```math
    \mathbf{z}_{\bar{\mathcal{P}}} = [z_{I_{ji}}, z_{\psi_{ji}}], \;\;\; \mathbf{v}_{\bar{\mathcal{P}}} = [v_{I_{ji}}, v_{\psi_{ji}}], \;\;\; \mathbf{h}_{\bar{\mathcal{P}}}(\mathbf {x}) = [h_{I_{ji}}(\mathbf {x}), h_{\psi_{ji}}(\mathbf {x})].
```

For example:
```@example ACSETutorial
addPmu!(system, device; label = "I₂₁, ψ₂₁", to = 1, magnitude = 0.3, angle = 2.3,
varianceMagnitude = 1e-2, varianceAngle = 1e-3, polar = true)
nothing # hide
```

Here, the function associated with the branch current magnitude at the to-bus end remains identical to the one provided in [To-Bus End Current Magnitude Measurements](@ref ToCurrentMagnitudeMeasurements). However, the function defining the branch current angle measurement is expressed as:
```math
    h_{\psi_{ji}}(\mathbf {x}) =  \mathrm{atan}\Bigg[
    \cfrac{(A_{\psi_{ji}} \sin\theta_j + B_{\psi_{ji}} \cos\theta_j)V_j - [C_{\psi_{ji}} \sin(\theta_{i}-\phi_{ij}) + D_{\psi_{ji}}\cos(\theta_{i}-\phi_{ij})]V_i}
    {(A_{\psi_{ji}} \cos\theta_j - B_{\psi_{ji}} \sin\theta_j)V_j - [C_{\psi_{ji}} \cos(\theta_{i}-\phi_{ij}) - D_{\psi_{ji}} \sin(\theta_{i}-\phi_{ij})]V_i} \Bigg],
```
where:
```math
    A_{\psi_{ji}} = g_{ij} + g_{\text{s}i}, \;\;\; B_{\psi_{ji}} = b_{ij} + b_{\text{s}i}, \;\;\;
    C_{\psi_{ji}} = \cfrac{g_{ij}}{\tau_{ij}}, \;\;\; D_{\psi_{ji}} = \cfrac{b_{ij}}{\tau_{ij}}.
```

Jacobian expressions associated with the branch current magnitude function ``h_{I_{ji}}(\mathbf x)`` remains identical to the one provided in [To-Bus End Current Magnitude Measurements](@ref ToCurrentMagnitudeMeasurements). Further, Jacobian expressions corresponding to the measurement function ``h_{\psi_{ji}}(\mathbf x)`` are defined as follows:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{\psi_{ji}}(\mathbf x)}}{\mathrm \partial \theta_{i}} &=
    \cfrac{A_{I_{ji}} V_i^2- [C_{I_{ji}} \cos(\theta_{ij}- \phi_{ij}) + D_{I_{ji}} \sin (\theta_{ij} - \phi_{ij}) ]V_iV_j}{h_{{I}_{ji}}^2(\mathbf x)} \\
    \cfrac{\mathrm \partial{h_{\psi_{ji}}(\mathbf x)}}{\mathrm \partial \theta_{j}} &=
    \cfrac{B_{I_{ji}} V_j^2 - [C_{I_{ji}} \cos (\theta_{ij} - \phi_{ij}) + D_{I_{ji}} \sin(\theta_{ij}- \phi_{ij})]V_iV_j}{h_{{I}_{ji}}^2(\mathbf x)} \\
    \cfrac{\mathrm \partial{h_{\psi_{ji}}(\mathbf x)}}{\mathrm \partial V_{i}} &=
    -\cfrac{[C_{I_{ji}} \sin (\theta_{ij} - \phi_{ij}) - D_{I_{ji}} \cos(\theta_{ij}- \phi_{ij})]V_j }{h_{{I}_{ji}}^2(\mathbf x)}\\
    \cfrac{\mathrm \partial{h_{\psi_{ji}}(\mathbf x)}}{\mathrm \partial V_{j}} &=
    \cfrac{[C_{I_{ji}} \sin (\theta_{ij} - \phi_{ij}) - D_{I_{ji}} \cos(\theta_{ij}- \phi_{ij})]V_i }{h_{{I}_{ji}}^2(\mathbf x)}.
  \end{aligned}
```

---

## [Weighted Least-Squares Estimation](@id ACSEWLSStateEstimationTutorials)
Given the available set of measurements ``\mathcal{M}``, the weighted least-squares estimator ``\hat{\mathbf x}``, i.e., the solution of the weighted least-squares problem, can be found using the Gauss-Newton method:
```math
		\Big[\mathbf J (\mathbf x^{(\nu)})^{T} \bm \Sigma^{-1} \mathbf J (\mathbf x^{(\nu)})\Big] \mathbf \Delta \mathbf x^{(\nu)} =
		\mathbf J (\mathbf x^{(\nu)})^{T} \bm \Sigma^{-1} \mathbf r (\mathbf x^{(\nu)})
```
```math
		\mathbf x^{(\nu+1)} = \mathbf x^{(\nu)} + \mathbf \Delta \mathbf x^{(\nu)},
```
where ``\nu = \{0,1,2,\dots\} `` is the iteration index, ``\mathbf \Delta \mathbf x \in \mathbb {R}^{n_{\text{u}}} `` is the vector of increments of the state variables, ``\mathbf J (\mathbf x)\in \mathbb {R}^{k \times n_{\text{u}}}`` is the Jacobian matrix of measurement functions ``\mathbf h (\mathbf x)`` at ``\mathbf x=\mathbf x^{(\nu)}``, ``\bm \Sigma \in \mathbb {R}^{k \times k}`` is a measurement error covariance matrix, and ``\mathbf r (\mathbf x) = \mathbf{z} - \mathbf h (\mathbf x)`` is the vector of residuals [monticellibook; Ch. 10](@cite). It is worth noting that assuming uncorrelated measurement errors leads to a diagonal covariance matrix ``\bm \Sigma`` corresponding to measurement variances. However, when incorporating PMUs in a rectangular coordinate system and aiming to observe error correlation, this matrix loses its diagonal form.

The non-linear or AC state estimation represents a non-convex problem arising from the non-linear measurement functions [weng2012semidefinite](@cite). Due to the fact that the values of state variables usually fluctuate in narrow boundaries, the non-linear model represents the mildly non-linear problem, where solutions are in a reasonable-sized neighborhood which enables the use of the Gauss-Newton method. The Gauss-Newton method can produce different rates of convergence, which can be anywhere from linear to quadratic [hansen2013least; Sec. 9.2](@cite). The convergence rate in regard to power system state estimation depends on the topology and measurements, and if parameters are consistent (e.g., free bad data measurement set), the method shows near quadratic convergence rate [monticellibook; Sec. 11.2](@cite).

---

##### Initialization
Let us begin by setting up a new set of measurements for the defined power system:
```@example ACSETutorial
device = measurement()

@wattmeter(label = "Watmeter ?")
addWattmeter!(system, device; bus = 3, active = -0.5, variance = 1e-3)
addWattmeter!(system, device; from = 1, active = 0.2, variance = 1e-4)

@varmeter(label = "Varmeter ?")
addVarmeter!(system, device; bus = 2, reactive = -0.3, variance = 1e-3)
addVarmeter!(system, device; from = 1, reactive = 0.2, variance = 1e-4)

@pmu(label = "PMU ?")
addPmu!(system, device; bus = 1, magnitude = 1.0, angle = 0, polar = true)
addPmu!(system, device; bus = 3, magnitude = 0.9, angle = -0.2)
nothing # hide
```

To compute the voltage magnitudes and angles of buses using the Gauss-Newton method in JuliaGrid, we need to first execute the [`acModel!`](@ref acModel!) function to set up the system. Then, initialize the Gauss-Newton method using the [`gaussNewton`](@ref gaussNewton) function. The following code snippet demonstrates this process:
```@example ACSETutorial
acModel!(system)
analysis = gaussNewton(system, device)
nothing # hide
```

Initially, the [`gaussNewton`](@ref gaussNewton) function constructs the mean vector holding measurement values:
```@repl ACSETutorial
𝐳 = analysis.method.mean
```

Additionally, it forms the precision or weighting matrix denoted as ``\mathbf W = \bm \Sigma^{-1}``. We can access these values using the following command:
```@repl ACSETutorial
𝐖 = analysis.method.precision
```

Finally, using initial bus voltage magnitudes and angles from the `PowerSystem` type, the function creates the initial vector ``\mathbf{x}^{(0)}`` of bus voltage magnitudes ``\mathbf{V}^{(0)}`` and angles ``\bm{\Theta}^{(0)}`` for the Gauss-Newton method:
```@repl ACSETutorial
𝐕⁽⁰⁾ = analysis.voltage.magnitude
𝚯⁽⁰⁾ = analysis.voltage.angle
```
Here, we utilize a "flat start" approach in our method. It is important to keep in mind that when dealing with initial conditions in this manner, the Gauss-Newton method may encounter difficulties.

---

##### Iterative Process
To apply the Gauss-Newton method, JuliaGrid provides the [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}})) function. This function is utilized iteratively until a stopping criterion is met, as demonstrated in the following code snippet:
```@example ACSETutorial
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
```

The function [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}})) calculates the vector of residuals at each iteration using the equation:
```math
  \mathbf r (\mathbf x^{(\nu)}) = \mathbf{z} - \mathbf h (\mathbf x^{(\nu)}).
```
The resulting vector from these calculations is stored in the residual variable of the `ACStateEstimation` type and can be accessed through the following line of code:
```@repl ACSETutorial
𝐫 = analysis.method.residual
```

The order of the residual vector follows a specific pattern. If all device types exist, the first ``|\mathcal{V}|`` elements correspond to voltmeters, followed by ``|\mathcal{I}|`` elements corresponding to ammeters. Then we have ``|\mathcal{P}|`` elements for wattmeters and ``|\mathcal{Q}|`` elements for varmeters. Finally, we have ``2|\bar{\mathcal{P}}|`` elements for PMUs. The order of these elements within specific devices follows the same order as they appear in the input data defined by the `Measurement` type.

At the same time, the function forms the Jacobian matrix ``\mathbf{J} (\mathbf{x}^{(\nu)})`` and calculates the gain matrix ``\mathbf{G} (\mathbf{x}^{(\nu)})`` using:
```math
		\mathbf G (\mathbf x^{(\nu)}) = \mathbf J (\mathbf x^{(\nu)})^{T} \bm \Sigma^{-1} \mathbf J (\mathbf x^{(\nu)})
```

The Jacobian matrix and factorized gain matrix are stored in the `ACStateEstimation` type and can be accessed after each iteration:
```@repl ACSETutorial
𝐉 = analysis.method.jacobian
𝐋 = analysis.method.factorization.L
𝐔 = analysis.method.factorization.U
```

Then finally, the function computes the vector of state variable increments using the equation:
```math
		\mathbf \Delta \mathbf x^{(\nu)} = \mathbf G (\mathbf x^{(\nu)})^{-1} \mathbf J (\mathbf x^{(\nu)})^{T} \bm \Sigma^{-1} \mathbf r (\mathbf x^{(\nu)})
```

!!! tip "Tip"
    By default, JuliaGrid uses LU factorization as the primary method for factorizing the gain matrix ``\mathbf{G} = \mathbf{L}\mathbf{U}``, aiming to compute the increments. Nevertheless, users have the flexibility to opt for QR or LDLt factorization as an alternative method.

Increment values are stored in the `ACStateEstimation` type and can be accessed after each iteration:
```@repl ACSETutorial
𝚫𝐱 = analysis.method.increment
```

Here again, the JuliaGrid implementation of the AC state estimation follows a specific order to store the increment vector and Jacobian matrix. The vector of increments first contains ``n`` increments of bus voltage angles ``\mathbf \Delta \bm{\Theta}``, followed by ``n`` increments of bus voltage magnitudes ``\mathbf \Delta \mathbf{V}``. This order also corresponds to the columns of the Jacobian matrix, while the order of rows of the Jacobian is defined according to the order of the residual vector.

Note that the increment vector and Jacobian matrix hold the slack bus with a known voltage angle. An element of the increment vector and a column of the Jacobian matrix are not deleted, and the presence on the slack bus is handled internally by JuliaGrid, which is evident from the factorization of the gain matrix.

The function [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}})) adds the computed increment term to the previous solution to obtain a new solution:
```math
  \mathbf {x}^{(\nu + 1)} = \mathbf {x}^{(\nu)} + \mathbf \Delta \mathbf {x}^{(\nu)}.
```

Therefore, the bus voltage magnitudes ``\mathbf{V} = [V_i]`` and angles ``\bm{\Theta} = [\theta_i]`` are stored in the following vectors:
```@repl ACSETutorial
𝐕 = analysis.voltage.magnitude
𝚯 = analysis.voltage.angle
```

Finally, the [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}})) function provides the maximum absolute value of state variable increments, typically employed as the termination criterion for the iteration loop. Specifically, if it falls below a predefined stopping criterion ``\epsilon``, the algorithm converges:
```math
  \max \{|\Delta x_i|,\; \forall i \} < \epsilon.
```

---

##### Jacobian Matrix
As a reminder, the Jacobian matrix consists of ``n`` columns representing bus voltage angles ``\bm{\Theta}``, followed by ``n`` columns representing bus voltage magnitudes ``\mathbf{V}``. The arrangement of rows is structured such that the first ``|\mathcal{V}|`` rows correspond to voltmeters, followed by ``|\mathcal{I}|`` rows corresponding to ammeters. Then, we have ``|\mathcal{P}|`` rows for wattmeters and ``|\mathcal{Q}|`` rows for varmeters. Finally, there are ``2|\bar{\mathcal{P}}|`` rows for PMUs. The elements are computed based on the provided Jacobian expressions.

---

##### Precision Matrix
Let us revisit the precision matrix ``\mathbf W``. In the previous example, we introduced a PMU in rectangular coordinates without considering correlations between measurement errors. Now, let us update that PMU to include correlation between measurement errors:
```@example ACSETutorial
updatePmu!(system, device, analysis; label = "PMU 2", correlated = true)
nothing # hide
```

Subsequently, we can examine the updated precision matrix ``\mathbf W``:
```@repl ACSETutorial
𝐖 = analysis.method.precision
```

Observing the precision matrix, we notice that it loses its diagonal form due to the inclusion of measurement covariances in the model.

---

##### Alternative Formulation
The resolution of the WLS state estimation problem using the conventional method typically progresses smoothly. However, it is widely acknowledged that in certain situations common to real-world systems, this method can be vulnerable to numerical instabilities. Such conditions might impede the algorithm from converging to a satisfactory solution. In such cases, users may opt for an alternative formulation of the WLS state estimation, namely, employing an approach called orthogonal factorization [aburbook; Sec. 3.2](@cite).

This approach is suitable when measurement errors are uncorrelated, and the precision matrix remains diagonal. Therefore, as a preliminary step, we need to eliminate the correlation, as we did previously:
```@example ACSETutorial
updatePmu!(system, device; label = "PMU 2", correlated = false)
nothing # hide
```

To address ill-conditioned situations arising from significant differences in measurement variances, users can now employ the orthogonal factorization approach:
```@example ACSETutorial
analysis = gaussNewton(system, device, Orthogonal)

for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
nothing # hide
```

To explain the method, we begin with the WLS equation:
```math
	  \Big[\mathbf J (\mathbf x^{(\nu)})^{T} \mathbf W \mathbf J (\mathbf x^{(\nu)})\Big] \mathbf \Delta \mathbf x^{(\nu)} =
		\mathbf J (\mathbf x^{(\nu)})^{T} \mathbf W \mathbf r (\mathbf x^{(\nu)})
```
where ``\mathbf W = \bm \Sigma^{-1}``. Subsequently, we can write:
```math
  \left[{\mathbf W^{1/2}} \mathbf J (\mathbf x^{(\nu)})\right]^{T}  {\mathbf W^{1/2}} \mathbf J (\mathbf x^{(\nu)})  \Delta \mathbf x^{(\nu)} =
  \left[{\mathbf W^{1/2}} \mathbf J (\mathbf x^{(\nu)})\right]^{T} {\mathbf W^{1/2}} \mathbf r (\mathbf x^{(\nu)}).
```

Consequently, we have:
```math
  \bar{\mathbf J}(\mathbf x^{(\nu)})^{T}  \bar{\mathbf J}(\mathbf x^{(\nu)}) \Delta \mathbf x^{(\nu)} = \bar{\mathbf J}(\mathbf x^{(\nu)})^{T}  \bar{\mathbf r} (\mathbf x^{(\nu)}),
```
where:
```math
  \bar{\mathbf J}(\mathbf x^{(\nu)}) = {\mathbf W^{1/2}} \mathbf J (\mathbf x^{(\nu)}), \;\;\; \bar{\mathbf r} (\mathbf x^{(\nu)}) = {\mathbf W^{1/2}} \mathbf r (\mathbf x^{(\nu)}).
```

Therefore, within each iteration of the Gauss-Newton method, JuliaGrid conducts QR factorization on the rectangular matrix:
```math
  \bar{\mathbf J}(\mathbf x^{(\nu)}) = {\mathbf W^{1/2}} \mathbf J (\mathbf x^{(\nu)}) = \mathbf{Q}\mathbf{R}.
```

Access to the factorized matrix is possible through:
```@repl ACSETutorial
𝐐 = analysis.method.factorization.Q
𝐑 = analysis.method.factorization.R
```

To obtain the solution, JuliaGrid avoids explicitly forming the orthogonal matrix ``\mathbf{Q}``. Once the algorithm converges, estimates of bus voltage magnitudes ``\hat{\mathbf V} = [\hat{V}_i]`` and angles ``\hat{\bm {\Theta}} = [\hat{\theta}_i]``, where ``i \in \mathcal{N}``  can be accessed using variables:
```@repl ACSETutorial
𝐕 = analysis.voltage.magnitude
𝚯 = analysis.voltage.angle
```

---

## [Bad Data Processing](@id ACBadDataTutorials)
Besides the state estimation algorithm, one of the essential state estimation routines is the bad data processing, whose main task is to detect and identify measurement errors, and eliminate them if possible. This is usually done by processing the measurement residuals [aburbook; Ch. 5](@cite), and typically, the largest normalized residual test is used to identify bad data. The largest normalized residual test is performed after we obtained the solution of the state estimation in the repetitive process of identifying and eliminating bad data measurements one after another [korres2010distributed](@cite).

To illustrate this process, let us introduce a new measurement that contains an obvious outlier:
```@example ACSETutorial
addWattmeter!(system, device; bus = 3, active = 5.1, variance = 1e-3)
nothing # hide
```

Subsequently, we will construct the AC state estimation model and solve it:
```@example ACSETutorial
analysis = gaussNewton(system, device)
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
nothing # hide
```

Now, the bad data processing can be executed:
```@example ACSETutorial
outlier = residualTest!(system, device, analysis; threshold = 4.0)
nothing # hide
```

In this step, we employ the largest normalized residual test, guided by the analysis outlined in [aburbook; Sec. 5.7](@cite). To be more precise, we compute all measurement residuals based on the obtained estimate of state variables:
```math
    r_i = z_i - h_i(\hat {\mathbf x}), \;\;\; i \in \mathcal{M}.
```

The normalized residuals for all measurements are computed as follows:
```math
    \bar{r}_{i} = \cfrac{|r_i|}{\sqrt{C_{ii}}} = \cfrac{|r_i|}{\sqrt{S_{ii}\Sigma_{ii}}}, \;\;\; i \in \mathcal{M}.
```

In this equation, we denote the diagonal entries of the residual covariance matrix ``\mathbf C \in \mathbb{R}^{k \times k}`` as ``C_{ii} = S_{ii}\Sigma_{ii}``, where ``S_{ii}`` is the diagonal entry of the residual sensitivity matrix ``\mathbf S`` representing the sensitivity of the measurement residuals to the measurement errors. For this specific configuration, the relationship is expressed as:
```math
    \mathbf C = \mathbf S \bm \Sigma = \bm \Sigma - \mathbf J (\hat {\mathbf x}) [\mathbf J (\hat {\mathbf x})^T \bm \Sigma^{-1} \mathbf J (\hat {\mathbf x})]^{-1} \mathbf J (\hat {\mathbf x})^T.
```
It is important to note that only the diagonal entries of ``\mathbf C`` are required. To obtain the inverse, the JuliaGrid package utilizes a computationally efficient sparse inverse method, retrieving only the necessary elements of the inverse.

The subsequent step involves selecting the largest normalized residual, and the ``j``-th measurement is then suspected as bad data and potentially removed from the measurement set ``\mathcal{M}``:
```math
    \bar{r}_{j} = \text{max} \{\bar{r}_{i}, i \in \mathcal{M} \}.
```

Users can access this information using the variable:
```@repl ACSETutorial
outlier.maxNormalizedResidual
```

If the largest normalized residual, denoted as ``\bar{r}_{j}``, satisfies the inequality:
```math
    \bar{r}_{j} \ge \epsilon,
```
the corresponding measurement is identified as bad data and subsequently removed. In this example, the bad data identification `threshold` is set to ``\epsilon = 4``. Users can verify the satisfaction of this inequality by inspecting:
```@repl ACSETutorial
outlier.detect
```

This indicates that the measurement labeled as:
```@repl ACSETutorial
outlier.label
```
is removed from the measurement set and marked as out-of-service.

Subsequently, we can solve the system again, but this time without the removed measurement:
```@example ACSETutorial
analysis = gaussNewton(system, device)
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
nothing # hide
```

Following that, we check for outliers once more:
```@example ACSETutorial
outlier = residualTest!(system, device, analysis; threshold = 4.0)
nothing # hide
```

To examine the value:
```@repl ACSETutorial
outlier.maxNormalizedResidual
```

As this value is now less than the `threshold` ``\epsilon = 4``, the measurement is not removed, or there are no outliers. This can also be verified by observing the bad data flag:
```@repl ACSETutorial
outlier.detect
```

---

## [Least Absolute Value Estimation](@id ACLAVTutorials)
The least absolute value (LAV) method provides an alternative estimation approach that is considered more robust in comparison to the WLS method. The WLS state estimation problem relies on specific assumptions about measurement errors, whereas robust estimators aim to remain unbiased even in the presence of various types of measurement errors and outliers. This characteristic eliminates the need for bad data processing, as discussed in [aburbook; Ch. 6](@cite). It is important to note that robustness often comes at the cost of increased computational complexity.

This section outlines the method as described in [aburbook; Sec. 6.5](@cite). Hence, we consider the system of nonlinear equations:
```math
  \mathbf{z}=\mathbf{h}(\mathbf x)+\mathbf{u}.
```

Subsequently, the LAV state estimator is derived as the solution to the optimization problem:
```math
  \begin{aligned}
    \text{minimize}& \;\;\; \sum_{i \in \mathcal{M}} |r_i|\\
    \text{subject\;to}& \;\;\; z_i - h_i(\mathbf x) =  r_i, \;\;\; \forall i \in \mathcal{M},
  \end{aligned}
```
where ``r_i`` represents the ``i``-th measurement residual. Let ``\eta_i`` be defined in a manner that ensures:
```math
  |r_i| \leq \eta_i,
```
and replace the above inequality with two equalities using two non-negative slack variables ``q_i`` and ``w_i``:
```math
  \begin{aligned}
    r_i - q_i &= -\eta_i \\
    r_i + w_i &= \eta_i.
  \end{aligned}
```

Let us now define two additional non-negative variables ``\overline{r}_i`` and ``\underline{r}_i``, which satisfy the following relationships:
```math
  \begin{aligned}
    r_i &= \overline{r}_i - \underline{r}_i\\
    \overline{r}_i &= \cfrac{1}{2} q_i \\
    \underline{r}_i &= \cfrac{1}{2} w_i.
  \end{aligned}
```

Then, the above two equalities become:
```math
  \begin{aligned}
    r_i - 2\overline{r}_i &= -2 \eta_i \\
    r_i + 2 \underline{r}_i &= 2 \eta_i,
  \end{aligned}
```
that is:
```math
  \begin{aligned}
    \overline{r}_i + \underline{r}_i = \eta_i.
  \end{aligned}
```

Next, we define a vector of state variables according to two additional nonnegative vectors ``\overline{\mathbf x}  \in \mathbb {R}_{\ge 0}^{n_\text{u}}`` and ``\underline{\mathbf x} \in \mathbb {R}_{\ge 0}^{n_\text{u}}``, which satisfy the following relationships:
```math
    \mathbf x = \overline{\mathbf x} - \underline{\mathbf x}
```

Hence, the optimization problem can be written:
```math
  \begin{aligned}
    \text{minimize}& \;\;\; \sum_{i \in \mathcal{M}} (\overline{r}_i + \underline{r}_i) \\
    \text{subject\;to}  & \;\;\; h_i(\overline{\mathbf x} - \underline{\mathbf x}) + \overline{r}_i - \underline{r}_i = z_i, \;\;\; \forall i \in \mathcal{M} \\
                        & \;\;\; \overline{r}_i \geq  0, \; \underline{r}_i \geq  0, \;\;\; \forall i \in \mathcal{M} \\
                        & \;\;\; \overline{\mathbf x} \succeq \mathbf 0, \; \underline{\mathbf x} \succeq \mathbf 0.
  \end{aligned}
```

To form the above optimization problem, the user can call the following function:
```@example ACSETutorial
using Ipopt
using JuMP # hide

analysis = acLavStateEstimation(system, device, Ipopt.Optimizer)
nothing # hide
```

Then the user can solve the optimization problem by:
```@example ACSETutorial
JuMP.set_silent(analysis.method.jump) # hide
solve!(system, analysis)
nothing # hide
```
As a result, we obtain optimal values for the four non-negative variables, while the state estimator is obtained by:
```math
    \hat{\mathbf x} = \overline{\mathbf x} - \underline{\mathbf x}.
```

Users can retrieve the estimated bus voltage magnitudes ``\hat{\mathbf V} = [\hat{V}_i]`` and angles ``\hat{\bm {\Theta}} = [\hat{\theta}_i]``, ``i \in \mathcal{N}``, using:
```@repl ACSETutorial
𝐕 = analysis.voltage.magnitude
𝚯 = analysis.voltage.angle
```

---

## [Power Analysis](@id ACPowerAnalysisTutorials)
Once the computation of voltage magnitudes and angles at each bus is completed, various electrical quantities can be determined. JuliaGrid offers the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) function, which enables the calculation of powers associated with buses and branches. Here is an example code snippet demonstrating its usage:
```@example ACSETutorial
power!(system, analysis)
nothing # hide
```

The function stores the computed powers in the rectangular coordinate system. It calculates the following powers related to buses and branches:

| Type   | Power                                                         | Active                                          | Reactive                                        |
|:-------|:--------------------------------------------------------------|:------------------------------------------------|:------------------------------------------------|
| Bus    | [Injections](@ref BusInjectionsTutorials)                     | ``\mathbf{P} = [P_i]``                          | ``\mathbf{Q} = [Q_i]``                          |
| Bus    | [Generator injections](@ref ACGeneratorPowerInjectionsManual) | ``\mathbf{P}_{\text{p}} = [P_{\text{p}i}]``     | ``\mathbf{Q}_{\text{p}} = [Q_{\text{p}i}]``     |
| Bus    | [Shunt elements](@ref BusShuntElementTutorials)               | ``\mathbf{P}_{\text{sh}} = [{P}_{\text{sh}i}]`` | ``\mathbf{Q}_{\text{sh}} = [{Q}_{\text{sh}i}]`` |
| Branch | [From-bus end flows](@ref BranchNetworkEquationsTutorials)    | ``\mathbf{P}_{\text{i}} = [P_{ij}]``            | ``\mathbf{Q}_{\text{i}} = [Q_{ij}]``            |
| Branch | [To-bus end flows](@ref BranchNetworkEquationsTutorials)      | ``\mathbf{P}_{\text{j}} = [P_{ji}]``            | ``\mathbf{Q}_{\text{j}} = [Q_{ji}]``            |
| Branch | [Shunt elements](@ref BranchShuntElementsTutorials)           | ``\mathbf{P}_{\text{s}} = [P_{\text{s}ij}]``    | ``\mathbf{P}_{\text{s}} = [P_{\text{s}ij}]``    |
| Branch | [Series elements](@ref BranchSeriesElementTutorials)          | ``\mathbf{P}_{\text{l}} = [P_{\text{l}ij}]``    | ``\mathbf{Q}_{\text{l}} = [Q_{\text{l}ij}]``    |

!!! note "Info"
    For a clear comprehension of the equations, symbols presented in this section, as well as for a better grasp of power directions, please refer to the [Unified Branch Model](@ref UnifiedBranchModelTutorials).

---

##### Power Injections
[Active and reactive power injections](@ref BusInjectionsTutorials) are stored as the vectors ``\mathbf{P} = [P_i]`` and ``\mathbf{Q} = [Q_i]``, respectively, and can be retrieved using the following commands:
```@repl ACSETutorial
𝐏 = analysis.power.injection.active
𝐐 = analysis.power.injection.reactive
```

----

##### [Generator Power Injections](@id ACGeneratorPowerInjectionsManual)
We can calculate the active and reactive power injections supplied by generators at each bus ``i \in \mathcal{N}`` by summing the active and reactive power injections and the active and reactive power demanded by consumers at each bus:
```math
  \begin{aligned}
    P_{\text{p}i} &= P_i + P_{\text{d}i}\\
    Q_{\text{p}i} &= Q_i + Q_{\text{d}i}.
  \end{aligned}
```

The active and reactive power injections from the generators at each bus are stored as vectors, denoted by ``\mathbf{P}_{\text{p}} = [P_{\text{p}i}]`` and ``\mathbf{Q}_{\text{p}} = [Q_{\text{p}i}]``, which can be obtained using:
```@repl ACSETutorial
𝐏ₚ = analysis.power.supply.active
𝐐ₚ = analysis.power.supply.reactive
```

---

##### Power at Bus Shunt Elements
[Active and reactive powers](@ref BusShuntElementTutorials) associated with the shunt elements at each bus are represented by the vectors ``\mathbf{P}_{\text{sh}} = [{P}_{\text{sh}i}]`` and ``\mathbf{Q}_{\text{sh}} = [{Q}_{\text{sh}i}]``. To retrieve these powers in JuliaGrid, use the following commands:
```@repl ACSETutorial
𝐏ₛₕ = analysis.power.shunt.active
𝐐ₛₕ = analysis.power.shunt.reactive
```

---

##### Power Flows
The resulting [active and reactive power flows](@ref BranchNetworkEquationsTutorials) at each from-bus end are stored as the vectors ``\mathbf{P}_{\text{i}} = [P_{ij}]`` and ``\mathbf{Q}_{\text{i}} = [Q_{ij}],`` respectively, and can be retrieved using the following commands:
```@repl ACSETutorial
𝐏ᵢ = analysis.power.from.active
𝐐ᵢ = analysis.power.from.reactive
```

Similarly, the vectors of [active and reactive power flows](@ref BranchNetworkEquationsTutorials) at the to-bus end are stored as ``\mathbf{P}_{\text{j}} = [P_{ji}]`` and ``\mathbf{Q}_{\text{j}} = [Q_{ji}]``, respectively, and can be retrieved using the following code:
```@repl ACSETutorial
𝐏ⱼ = analysis.power.to.active
𝐐ⱼ = analysis.power.to.reactive
```

---

##### Power at Branch Shunt Elements
[Active and reactive powers](@ref BranchShuntElementsTutorials) associated with the branch shunt elements at each branch are represented by the vectors ``\mathbf{P}_{\text{s}} = [P_{\text{s}ij}]`` and ``\mathbf{Q}_{\text{s}} = [Q_{\text{s}ij}]``. We can retrieve these values using the following code:
```@repl ACSETutorial
𝐏ₛ = analysis.power.charging.active
𝐐ₛ = analysis.power.charging.reactive
```

---

##### Power at Branch Series Elements
[Active and reactive powers](@ref BranchSeriesElementTutorials) associated with the branch series element at each branch are represented by the vectors ``\mathbf{P}_{\text{l}} = [P_{\text{l}ij}]`` and ``\mathbf{Q}_{\text{l}} = [Q_{\text{l}ij}]``. We can retrieve these values using the following code:
```@repl ACSETutorial
𝐏ₗ = analysis.power.series.active
𝐐ₗ = analysis.power.series.reactive
```

---

## [Current Analysis](@id PMUCurrentAnalysisTutorials)
JuliaGrid offers the [`current!`](@ref current!(::PowerSystem, ::ACPowerFlow)) function, which enables the calculation of currents associated with buses and branches. Here is an example code snippet demonstrating its usage:
```@example ACSETutorial
current!(system, analysis)
nothing # hide
```

The function stores the computed currents in the polar coordinate system. It calculates the following currents related to buses and branches:

| Type   | Current                                                    | Magnitude                                    | Angle                                          |
|:-------|:-----------------------------------------------------------|:---------------------------------------------|:-----------------------------------------------|
| Bus    | [Injections](@ref BusInjectionsTutorials)                  | ``\mathbf{I} = [I_i]``                       | ``\bm{\psi} = [\psi_i]``                       |
| Branch | [From-bus end flows](@ref BranchNetworkEquationsTutorials) | ``\mathbf{I}_{\text{i}} = [I_{ij}]``         | ``\bm{\psi}_{\text{i}} = [\psi_{ij}]``         |
| Branch | [To-bus end flows](@ref BranchNetworkEquationsTutorials)   | ``\mathbf{I}_{\text{j}} = [I_{ji}]``         | ``\bm{\psi}_{\text{j}} = [\psi_{ji}]``         |
| Branch | [Series elements](@ref BranchSeriesElementTutorials)       | ``\mathbf{I}_{\text{l}} = [I_{\text{l}ij}]`` | ``\bm{\psi}_{\text{l}} = [\psi_{\text{l}ij}]`` |

!!! note "Info"
    For a clear comprehension of the equations, symbols presented in this section, as well as for a better grasp of power directions, please refer to the [Unified Branch Model](@ref UnifiedBranchModelTutorials).

---

##### Current Injections
In JuliaGrid, [complex current injections](@ref BusInjectionsTutorials) are stored in the vector of magnitudes denoted as ``\mathbf{I} = [I_i]`` and the vector of angles represented as ``\bm{\psi} = [\psi_i]``. You can retrieve them using the following commands:
```@repl ACSETutorial
𝐈 = analysis.current.injection.magnitude
𝛙 = analysis.current.injection.angle
```

---

##### Current Flows
To obtain the vectors of magnitudes ``\mathbf{I}_{\text{i}} = [I_{ij}]`` and angles ``\bm{\psi}_{\text{i}} = [\psi_{ij}]`` for the resulting [complex current flows](@ref BranchNetworkEquationsTutorials), you can use the following commands:
```@repl ACSETutorial
𝐈ᵢ = analysis.current.from.magnitude
𝛙ᵢ = analysis.current.from.angle
```

Similarly, we can obtain the vectors of magnitudes ``\mathbf{I}_{\text{j}} = [I_{ji}]`` and angles ``\bm{\psi}_{\text{j}} = [\psi_{ji}]`` of the resulting [complex current flows](@ref BranchNetworkEquationsTutorials) using the following code:
```@repl ACSETutorial
𝐈ⱼ = analysis.current.to.magnitude
𝛙ⱼ = analysis.current.to.angle
```

---

##### Current at Branch Series Elements
To obtain the vectors of magnitudes ``\mathbf{I}_{\text{l}} = [I_{\text{l}ij}]`` and angles ``\bm{\psi}_{\text{l}} = [\psi_{\text{l}ij}]`` of the resulting [complex current flows](@ref BranchSeriesElementTutorials), one can use the following code:
```@repl ACSETutorial
𝐈ₗ = analysis.current.series.magnitude
𝛙ₗ = analysis.current.series.angle
```