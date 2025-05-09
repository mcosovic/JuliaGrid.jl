# [DC State Estimation](@id DCStateEstimationTutorials)
To initiate the process, let us construct the `PowerSystem` type and formulate the DC model:
```@example DCSETutorial
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, angle = 0.0)
addBus!(system; label = 2, active = 0.1)
addBus!(system; label = 3, active = 1.3)

addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.2)
addBranch!(system; label = 2, from = 1, to = 3, reactance = 0.1)
addBranch!(system; label = 3, from = 2, to = 3, reactance = 0.3)

dcModel!(system)
nothing # hide
```

To review, we can conceptualize the bus/branch model as the graph denoted by ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where we have the set of buses ``\mathcal{N} = \{1, \dots, n\}``, and the set of branches ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` within the power system:
```@repl DCSETutorial
𝒩 = collect(keys(system.bus.label))
ℰ = [𝒩[system.branch.layout.from] 𝒩[system.branch.layout.to]]
```

---

Following that, we will introduce the `Measurement` type and incorporate a set of measurement devices ``\mathcal{M}`` into the graph ``\mathcal{G}``. In typical scenarios, the DC state estimation model relies solely on active power measurements  originating from the set of wattmeters ``\mathcal{P}``. However, we provide the option for users to include measurements from the set of PMUs ``\bar{\mathcal{P}}``. Specifically, we utilize only the PMUs installed at the buses ``\bar{\mathcal{P}}_\text{b} \subset \bar{\mathcal{P}}`` that measure bus voltage angles. This process of adding measurement devices will be carried out in the [State Estimation Model](@ref DCSEModelTutorials) section. Currently, we are only initializing the `Measurement` type:
```@example DCSETutorial
monitoring = measurement(system)
nothing # hide
```

---

!!! ukw "Notation"
    Here, when referring to a vector ``\mathbf{a}``, we use the notation ``\mathbf{a} = [a_{i}]`` or ``\mathbf{a} = [a_{ij}]``, where ``a_i`` represents the element related with bus ``i \in \mathcal{N}`` or measurement ``i \in \mathcal{M}``, while ``a_{ij}`` denotes the element related with branch ``(i,j) \in \mathcal{E}``.

---

## [State Estimation Model](@id DCSEModelTutorials)
In accordance with the [DC Model](@ref DCModelTutorials), the DC state estimation is derived through the linearization of the non-linear model. In this linearized model, all bus voltage magnitudes are assumed to be ``V_i \approx 1``, ``i \in \mathcal{N}``. Additionally, shunt elements and branch resistances are neglected. This simplification implies that the DC model disregards reactive powers and transmission losses, focusing solely on active powers. Consequently, the DC state estimation considers only bus voltage angles, represented as ``\mathbf x \equiv \bm {\Theta}``, as the state variables. As a result, the total number of state variables is ``n-1``, with one voltage angle corresponding to the slack bus.

Within the JuliaGrid framework for DC state estimation, the methodology encompasses both active power flow and injection measurements from the set ``\mathcal{P}``, along with bus voltage angle measurements represented by the set ``\bar{\mathcal{P}}_\text{b}``. These measurements contribute to the construction of a linear system of equations:
```math
    \mathbf{z}=\mathbf{h}(\bm {\Theta})+\mathbf{u},
```
where ``\mathbf{h}(\bm {\Theta})=`` ``[h_1(\bm {\Theta})``, ``\dots``, ``h_k(\bm {\Theta})]^{{T}}`` is the vector of linear measurement functions, ``\mathbf{z} = [z_1,\dots,z_k]^{\mathrm{T}}`` is the vector of measurement values, and ``\mathbf{u} = [u_1,\dots,u_k]^{\mathrm{T}}`` is the vector of uncorrelated measurement errors, and this defines the vector of measurement variances ``\mathbf{v} = [v_1,\dots,v_k]^{\mathrm{T}}``, where ``k = |\mathcal{M}|``.

Therefore, the linear system of equations can be represented based on the specific devices from which measurements originate, whether wattmeters or PMUs:
```math
    \begin{bmatrix}
      \mathbf{z}_\mathcal{P}\\[3pt]
      \mathbf{z}_{\bar{\mathcal{P}}_\text{b}}
    \end{bmatrix} =
    \begin{bmatrix}
      \mathbf{h}_\mathcal{P}(\bm {\Theta})\\[3pt]
      \mathbf{h}_{\bar{\mathcal{P}}_\text{b}}(\bm {\Theta})
    \end{bmatrix} +
    \begin{bmatrix}
      \mathbf{u}_\mathcal{P}\\[3pt]
      \mathbf{u}_{\bar{\mathcal{P}}_\text{b}}.
    \end{bmatrix}
```

In summary, upon user definition of the measurement devices, each ``i``-th measurement device is linked to the measurement function ``h_i(\bm {\Theta})``, the corresponding measurement value ``z_i``, and the measurement variance ``v_i``.

---

##### Active Power Injection Measurements
When adding a wattmeter ``P_i \in \mathcal{P}`` at bus ``i \in \mathcal{N}``, users specify that the wattmeter measures active power injection and define measurement value, variance and measurement function of vectors:
```math
    \mathbf{z}_\mathcal{P} = [z_{P_{i}}], \;\;\; \mathbf{v}_\mathcal{P} = [v_{P_{i}}], \;\;\; \mathbf{h}_\mathcal{P}(\bm {\Theta}) = [h_{P_{i}}(\bm {\Theta})].
```

For example:
```@example DCSETutorial
addWattmeter!(monitoring; label = "P₃", bus = 3, active = -1.30, variance = 1e-3)
nothing # hide
```

Here, utilizing the [DC Model](@ref DCNodalNetworkEquationsTutorials), we derive the function defining the active power injection as follows:
```math
   h_{P_{i}}(\bm {\Theta}) = B_{ii}\theta_i + \sum_{j \in \mathcal{N}_i \setminus i} {B}_{ij} \theta_j + P_{\text{tr}i} + P_{\text{sh}i},
```
where ``\mathcal{N}_i \setminus i`` contains buses incident to bus ``i``, excluding bus ``i``, with the following coefficient expressions:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{P_{i}}(\bm {\Theta})}}{\mathrm \partial \theta_{i}} = B_{ii}, \;\;\;
  \cfrac{\mathrm \partial{{h_{P_{i}}}(\bm {\Theta})}}{\mathrm \partial \theta_{j}} = {B}_{ij}.
  \end{aligned}
```

---

##### From-Bus End Active Power Flow Measurements
Additionally, when introducing a wattmeter at branch ``(i,j) \in \mathcal{E}``, users specify that the wattmeter measures active power flow. It can be positioned at the from-bus end, denoted as ``P_{ij} \in \mathcal{P}``, specifying the measurement value, variance and measurement function of vectors:
```math
    \mathbf{z}_\mathcal{P} = [z_{P_{ij}}], \;\;\; \mathbf{v}_\mathcal{P} = [v_{P_{ij}}], \;\;\; \mathbf{h}_\mathcal{P}(\bm {\Theta}) = [h_{P_{ij}}(\bm {\Theta})].
```

For example:
```@example DCSETutorial
addWattmeter!(monitoring; label = "P₁₂", from = 1, active = 0.28, variance = 1e-4)
nothing # hide
```

Here, the function describing active power flow at the from-bus end is defined as follows:
```math
  h_{P_{ij}}(\bm {\Theta}) = \cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} -\theta_{j}-\phi_{ij}),
```
with the following coefficient expressions:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{P_{ij}}(\bm {\Theta})}}{\mathrm \partial \theta_{i}} = \cfrac{1}{\tau_{ij} x_{ij}}, \;\;\;
    \cfrac{\mathrm \partial{{h_{P_{ij}}}(\bm {\Theta})}}{\mathrm \partial \theta_{j}} = -\cfrac{1}{\tau_{ij} x_{ij}}.
  \end{aligned}
```

---

##### To-Bus End Active Power Flow Measurements
Similarly, a wattmeter can be placed at the to-bus end, denoted as ``P_{ji} \in \mathcal{P}``, specifying the measurement value, variance and measurement function of vectors:
```math
    \mathbf{z}_\mathcal{P} = [z_{P_{ji}}], \;\;\; \mathbf{v}_\mathcal{P} = [v_{P_{ji}}], \;\;\; \mathbf{h}_\mathcal{P}(\bm {\Theta}) = [h_{P_{ji}}(\bm {\Theta})].
```

For example:
```@example DCSETutorial
addWattmeter!(monitoring; label = "P₂₁", to = 1, active = -0.28, variance = 1e-4)
nothing # hide
```

Thus, the function describing active power flow at the to-bus end is defined as follows:
```math
  h_{P_{ji}}(\bm {\Theta}) = -\cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} -\theta_{j}-\phi_{ij}),
```
with the following coefficient expressions:
```math
  \cfrac{\mathrm \partial{h_{P_{ji}}(\bm {\Theta})}}{\mathrm \partial \theta_{i}} = -\cfrac{1}{\tau_{ij} x_{ij}}, \;\;\;
  \cfrac{\mathrm \partial{{h_{P_{ji}}}(\bm {\Theta})}}{\mathrm \partial \theta_{j}} = \cfrac{1}{\tau_{ij} x_{ij}}.
```

---

##### Bus Voltage Angle Measurements
If the user opts to include phasor measurements that measure bus voltage angle at bus ``i \in \mathcal{N}``, denoted as ``\theta_i \in \bar{\mathcal{P}}_\text{b}``, the user will specify the measurement values, variances, and measurement functions of vectors:
```math
    \mathbf{z}_{\bar{\mathcal{P}}_\text{b}} = [z_{\theta_i}], \;\;\; \mathbf{v}_{\bar{\mathcal{P}}_\text{b}} = [v_{\theta_i}], \;\;\; \mathbf{h}_{\bar{\mathcal{P}}_\text{b}}(\bm {\Theta}) = [h_{\theta_{i}}(\bm {\Theta})].
```

For example:
```@example DCSETutorial
addPmu!(
  monitoring; label = "V₁, θ₁", bus = 1, magnitude = 1.0, angle = 0,
  varianceMagnitude = 1e-5, varianceAngle = 1e-6
)
nothing # hide
```

Here, the function defining the bus voltage angle measurement is straightforward:
```math
    h_{\theta_{i}}(\bm {\Theta}) = \theta_{i},
```
with the following coefficient expression:
```math
  \cfrac{\mathrm \partial{{h_{\theta_i}(\bm {\Theta})}}}{\mathrm \partial \theta_{i}}=1.
```

---

## [Weighted Least-Squares Estimation](@id DCSEWLSStateEstimationTutorials)
The solution to the DC state estimation problem is determined by solving the linear weighted least-squares (WLS) problem, represented by the following formula:
```math
	\mathbf H^{T} \bm \Sigma^{-1} \mathbf H \bm {\Theta} = \mathbf H^{T} \bm \Sigma^{-1} (\mathbf z - \mathbf{c}).
```

Here, ``\mathbf z \in \mathbb {R}^{k}`` denotes the vector of measurement values, the vector ``\mathbf c \in \mathbb {R}^{k}`` holds constant terms, ``\mathbf {H} \in \mathbb {R}^{k \times (n-1)}`` represents the coefficient matrix, and ``\bm \Sigma \in \mathbb {R}^{k \times k}`` is the measurement error covariance matrix, where the diagonal elements hold measurement variances.

The inclusion of the vector ``\mathbf{c}`` is necessary due to the fact that measurement functions associated with active power measurements may include constant terms, especially when there are non-zero shift angles of transformers or shunt elements in the system consuming active powers, as evident from the provided measurement functions.

---

##### Implementation
JuliaGrid initiates the DC state estimation framework by setting up the WLS model, as illustrated in the following:
```@example DCSETutorial
analysis = dcStateEstimation(monitoring)
nothing # hide
```

---

##### Coefficient Matrix
Using the above-described equations, JuliaGrid forms the coefficient matrix ``\mathbf{H} \in \mathbb{R}^{k \times (n-1)}``:
```@repl DCSETutorial
𝐇 = analysis.method.coefficient
```
Each row in the matrix corresponds to a specific measurement. The first ``|\mathcal{P}|`` rows correspond to wattmeters, ordered as users add wattmeters, while the last ``|{\bar{\mathcal{P}}_\text{b}}|`` rows correspond to PMUs, also in the order users add PMUs.

---

##### Precision Matrix
JuliaGrid opts not to retain the covariance matrix ``\bm \Sigma`` but rather stores its inverse, the precision or weighting matrix denoted as ``\mathbf W = \bm \Sigma^{-1}``. The order of these values corresponds to the description provided for the coefficient matrix. Users can access these values using the following command:
```@repl DCSETutorial
𝐖 = analysis.method.precision
```

---

##### Mean Vector
Users can access the vector ``\mathbf z - \mathbf{c}``, which contains the means of Gaussian distributions describing each measurement, using the following command:
```@repl DCSETutorial
𝐳 = analysis.method.mean
```
In the context of the power system, where phase-shifting transformers and shunt elements consuming active powers are absent, and the slack angle has a zero value, the vector ``\mathbf{c}= \mathbf{0}``. Consequently, the vector of means holds values that are equal to the measurement values.

---

##### Estimate of State Variables
Once the model is established, we solve the WLS equation to derive the estimate of bus voltage angles:
```math
	\hat{\bm {\Theta}} = [\mathbf H^{T} \bm \Sigma^{-1} \mathbf H]^{-1} \mathbf H^{T} \bm \Sigma^{-1} (\mathbf z - \mathbf{c}).
```

This process is executed using the [`solve!`](@ref solve!(::DcStateEstimation{WLS{Normal}})) function:
```@example DCSETutorial
solve!(analysis)
```

The initial step involves the LU factorization of the gain matrix:
```math
	\mathbf G = \mathbf H^{T} \bm \Sigma^{-1} \mathbf H = \mathbf L \mathbf U.
```

!!! tip "Tip"
    By default, JuliaGrid utilizes LU factorization as the primary method to factorize the gain matrix. However, users maintain the flexibility to opt for alternative factorization methods such as LDLt or QR.

Access to the factorized gain matrix is available through:
```@repl DCSETutorial
𝐋 = analysis.method.factorization.L
𝐔 = analysis.method.factorization.U
```

Finally, the estimated bus voltage angles ``\hat{\bm {\Theta}} = [\hat{\theta}_i]``, ``i \in \mathcal{N}``, can be retrieved using the variable:
```@repl DCSETutorial
𝚯 = analysis.voltage.angle
```

It is essential to note that the slack bus voltage angle is temporarily excluded from the gain matrix ``\mathbf G`` during computation. It is important to emphasize that this internal handling does not alter the stored elements.

---

##### [Alternative Formulation](@id DCSEOrthogonalWLSStateEstimationTutorials)
The resolution of the WLS state estimation problem using the conventional method typically progresses smoothly. However, it is widely acknowledged that in certain situations common to real-world systems, this method can be vulnerable to numerical instabilities. Such conditions might impede the algorithm from converging to a satisfactory solution. In such cases, users may opt for an alternative formulation of the WLS state estimation, namely, employing an approach called orthogonal factorization [aburbook; Sec. 3.2](@cite).

To address ill-conditioned situations arising from significant differences in measurement variances, users can employ an alternative approach:
```@example DCSETutorial
analysis = dcStateEstimation(monitoring, Orthogonal)
nothing # hide
```

To explain the method, we begin with the WLS equation:
```math
	\mathbf H^{T} \mathbf W \mathbf H \bm {\Theta} = \mathbf H^{T} \mathbf W (\mathbf z - \mathbf{c}),
```
where ``\mathbf W = \bm \Sigma^{-1}``. Subsequently, we can write:
```math
  \left({\mathbf W^{1/2}} \mathbf H\right)^{T}  {\mathbf W^{1/2}} \mathbf H  \bm {\Theta} = \left({\mathbf W^{1/2}} \mathbf H\right)^{T} {\mathbf W^{1/2}} (\mathbf z - \mathbf{c}).
```

Consequently, we have:
```math
  \bar{\mathbf{H}}^{T}  \bar{\mathbf{H}} \bm {\Theta} = \bar{\mathbf{H}}^{T}  \bar{\mathbf{z}},
```
where:
```math
  \bar{\mathbf{H}} = {\mathbf W^{1/2}} \mathbf H; \;\;\; \bar{\mathbf{z}} = {\mathbf W^{1/2}} (\mathbf z - \mathbf{c}).
```

At this point, QR factorization is performed on the rectangular matrix:
```math
  \bar{\mathbf{H}} = {\mathbf W^{1/2}} \mathbf H = \mathbf{Q}\mathbf{R}.
```

Executing this procedure involves the [`solve!`](@ref solve!(::DcStateEstimation{WLS{Normal}})) function:
```@example DCSETutorial
solve!(analysis)
nothing # hide
```

Access to the factorized matrix is possible through:
```@repl DCSETutorial
𝐐 = analysis.method.factorization.Q
𝐑 = analysis.method.factorization.R
```

To obtain the solution, JuliaGrid avoids materializing the orthogonal matrix ``\mathbf{Q}`` and proceeds to solve the system, resulting in the estimate of state variables ``\hat{\bm {\Theta}} = [\hat{\theta}_i]``, where ``i \in \mathcal{N}``:
```@repl DCSETutorial
𝚯 = analysis.voltage.angle
```

---

## [Least Absolute Value Estimation](@id DCSELAVTutorials)
The least absolute value (LAV) method provides an alternative estimation approach that is considered more robust in comparison to the WLS method. The WLS state estimation problem relies on specific assumptions about measurement errors, whereas robust estimators aim to remain unbiased even in the presence of various types of measurement errors and outliers. This characteristic eliminates the need for bad data analysis, as discussed in [aburbook; Ch. 6](@cite). It is important to note that robustness often comes at the cost of increased computational complexity.

It can be demonstrated that the problem can be expressed as a linear programming problem. This section outlines the method as described in [aburbook; Sec. 6.5](@cite). To revisit, we consider the system of linear equations:
```math
  \mathbf{z}=\mathbf{h}(\bm {\Theta})+\mathbf{u}.
```

The LAV state estimator is then formulated as the solution to the following optimization problem:
```math
  \begin{aligned}
    \text{minimize}& \;\;\; \sum_{i \in \mathcal M} |r_i|\\
    \text{subject\;to}& \;\;\; z_i - h_i(\bm {\Theta}) =  r_i, \;\;\; \forall i \in \mathcal M,
  \end{aligned}
```
where ``r_i`` denotes the residual of the ``i``-th measurement.

To explicitly handle absolute values, we introduce two nonnegative variables ``u_i \ge 0`` and ``v_i \ge 0``, referred to as positive and negative deviations. This allows the optimization problem to be rewritten as:
```math
  \begin{aligned}
    \text{minimize}& \;\;\; \sum_{i \in \mathcal M} (u_i + v_i) \\
    \text{subject\;to}  & \;\;\; z_i - h_i(\bm {\Theta}) = u_i - v_i, \;\;\; \forall i \in \mathcal M \\
                        & \;\;\; u_i \geq  0, \; v_i \geq  0, \;\;\; \forall i \in \mathcal M.
  \end{aligned}
```

To form the above optimization problem, the user can call the following function:
```@example DCSETutorial
using Ipopt
using JuMP # hide

analysis = dcLavStateEstimation(monitoring, Ipopt.Optimizer)
nothing # hide
```

Then the user can solve the optimization problem by:
```@example DCSETutorial
JuMP.set_silent(analysis.method.jump) # hide
solve!(analysis)
nothing # hide
```

Users can retrieve the estimated bus voltage angles ``\hat{\bm {\Theta}} = [\hat{\theta}_i]``, ``i \in \mathcal{N}``, using the variable:
```@repl DCSETutorial
𝚯 = analysis.voltage.angle
```

---

## [Power Analysis](@id DCSEPowerAnalysisTutorials)
After obtaining the solution from the DC state estimation, we can calculate powers related to buses and branches using the [`power!`](@ref power!(::DC)) function:
```@example DCSETutorial
power!(analysis)
nothing # hide
```

!!! note "Info"
    For a clear comprehension of the equations, symbols provided below, as well as for a better grasp of power directions, please refer to the [Unified Branch Model](@ref UnifiedBranchModelTutorials).

---

##### Power Injections
[Active power injections](@ref DCBusInjectionTutorials) are stored as the vector ``\mathbf{P} = [P_i]``, and can be retrieved using the following commands:
```@repl DCSETutorial
𝐏 = analysis.power.injection.active
```

---

##### Generator Power Injections
We can determine the active power supplied by generators to the buses by summing the active power injections and the active power demanded by consumers at each bus:
```math
    P_{\text{p}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}.
```
The vector of active power injected by generators into the buses, denoted by ``\mathbf{P}_{\text{p}} = [P_{\text{p}i}]``, can be obtained using:
```@repl DCSETutorial
𝐏ₚ = analysis.power.supply.active
```

---

##### Power Flows
The resulting [active power flows](@ref DCBranchNetworkEquationsTutorials) are stored as the vector ``\mathbf{P}_{\text{i}} = [P_{ij}]``, which can be retrieved using:
```@repl DCSETutorial
𝐏ᵢ = analysis.power.from.active
```

Similarly, the resulting [active power flows](@ref DCBranchNetworkEquationsTutorials) are stored as the vector ``\mathbf{P}_{\text{j}} = [P_{ji}]``, which can be retrieved using:
```@repl DCSETutorial
𝐏ⱼ = analysis.power.to.active
```