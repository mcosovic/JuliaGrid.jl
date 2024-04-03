# [DC State Estimation](@id DCStateEstimationTutorials)
To initiate the process, let us construct the `PowerSystem` composite type and formulate the DC model:
```@example DCSETutorial
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, angle = 0.0)
addBus!(system; label = 2, type = 1, active = 0.1)
addBus!(system; label = 3, type = 1, active = 1.3)
addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.2)
addBranch!(system; label = 2, from = 1, to = 3, reactance = 0.1)
addBranch!(system; label = 3, from = 2, to = 3, reactance = 0.3)
addGenerator!(system; label = 1, bus = 1, active = 3.2)

dcModel!(system)
nothing # hide
```

To review, we can conceptualize the bus/branch model as the graph denoted by ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where we have the set of buses ``\mathcal{N} = \{1, \dots, n\}``, and the set of branches ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` within the power system:
```@repl DCSETutorial
𝒩 = collect(keys(system.bus.label))
ℰ = [𝒩[system.branch.layout.from] 𝒩[system.branch.layout.to]]
```

---

Subsequently, we will establish the `Measurement` composite type and incorporate a set of active power measurements ``\mathcal{P}`` into the graph ``\mathcal{G}``. These measurements are acquired using wattmeters:
```@example DCSETutorial
device = measurement()

@wattmeter(label = "Wattmeter ?")
addWattmeter!(system, device; from = 1, active = 0.27, variance = 1e-4, noise = false)
addWattmeter!(system, device; bus = 3, active = -1.21, variance = 1e-3, noise = false)
addWattmeter!(system, device; to = 1, active = -0.28, variance = 1e-4, noise = false)

nothing # hide
```

---

In typical scenarios, the DC state estimation model relies solely on active power measurements. However, we allow the possibility for the user to include bus voltage angle measurements from PMUs, represented as the set ``\bar{\mathcal{P}}_A``:
```@example DCSETutorial
@pmu(label = "PMU ?", varianceAngleBus = 1e-5)
addPmu!(system, device; bus = 2, magnitude = 1.0, angle = -0.06, noise = false)
addPmu!(system, device; bus = 3, magnitude = 1.0, angle = -0.12, noise = false)

nothing # hide
```

As a result, JuliaGrid is capable of conducting DC state estimation utilizing a set of measurement devices denoted as ``\mathcal{M} = \mathcal{P} \cup \bar{\mathcal{P}}_A``, which includes active power flow and injection measurements obtained from wattmeters, as well as bus voltage angle measurements from PMUs.

---

!!! ukw "Notation"
    In this section, when referring to a vector ``\mathbf{a}``, we use the notation ``\mathbf{a} = [a_{i}]`` or ``\mathbf{a} = [a_{ij}]``, where ``a_i`` represents the element associated with bus ``i \in \mathcal{N}`` or measurement ``i \in \mathcal{M}``, and ``a_{ij}`` represents the element associated with branch ``(i,j) \in \mathcal{E}``.

---

## [State Estimation Model](@id DCSEModelTutorials)
In accordance with the [DC Model](@ref DCModelTutorials), the DC state estimation is derived through the linearization of the non-linear model. In this linearized model, all bus voltage magnitudes are assumed to be ``V_i \approx 1``, ``i \in \mathcal{N}``. Additionally, shunt elements and branch resistances are neglected. This simplification implies that the DC model disregards reactive powers and transmission losses, focusing solely on active powers. Consequently, the DC state estimation considers only bus voltage angles, represented as ``\mathbf x \equiv \bm {\Theta}``, as the state variables. As a result, the total number of state variables is ``n-1``, with one voltage angle corresponding to the slack bus.

Within the JuliaGrid framework for DC state estimation, the methodology encompasses both active power flow and injection measurements from the set ``\mathcal{P}``, along with bus voltage angle measurements represented by the set ``\bar{\mathcal{P}}_A``. These measurements contribute to the construction of a linear system of equations:
```math
    \mathbf{z}=\mathbf{h}(\bm {\Theta})+\mathbf{u},
```
where ``\mathbf{h}(\bm {\Theta})=`` ``[h_1(\bm {\Theta})``, ``\dots``, ``h_k(\bm {\Theta})]^{{T}}`` is the vector of linear measurement functions, ``\mathbf{z} = [z_1,\dots,z_k]^{\mathrm{T}}`` is the vector of measurement values, and ``\mathbf{u} = [u_1,\dots,u_k]^{\mathrm{T}}`` is the vector of uncorrelated measurement errors, and this defines the vector of measurement variances ``\mathbf{v} = [v_1,\dots,v_k]^{\mathrm{T}}``, where ``k = |\mathcal{M}|``.

Therefore, the linear system of equations can be represented based on the specific devices from which measurements originate, whether wattmeters or PMUs:
```math
    \begin{bmatrix}
      \mathbf{z}_\mathcal{P}\\[3pt]
      \mathbf{z}_{\bar{\mathcal{P}}_A}
    \end{bmatrix} =
    \begin{bmatrix}
      \mathbf{h}_\mathcal{P}(\bm {\Theta})\\[3pt]
      \mathbf{h}_{\bar{\mathcal{P}}_A}(\bm {\Theta})
    \end{bmatrix} +
    \begin{bmatrix}
      \mathbf{u}_\mathcal{P}\\[3pt]
      \mathbf{u}_{\bar{\mathcal{P}}_A}
    \end{bmatrix}
```

In summary, upon user definition of the measurement devices, each ``i``-th measurement device is linked to the measurement function ``h_i(\bm {\Theta})``, the corresponding measurement value ``z_i``, and the measurement variance ``v_i``.

---

##### Active Power Flow Measurement Functions
The vector ``\mathbf{h}_\mathcal{P}(\bm {\Theta})`` comprises functions representing active power flow measurements. Following the guidelines outlined in the [DC Model](@ref DCBranchNetworkEquationsTutorials), the functions describing active power flows at the branch ``(i,j) \in \mathcal{E}`` at the "from" and "to" bus ends are defined as follows:
```math
  \begin{aligned}
    h_{P_{ij}}(\cdot) &= \cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} -\theta_{j}-\phi_{ij})\\
    h_{P_{ji}}(\cdot) &= -\cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} -\theta_{j}-\phi_{ij}).
  \end{aligned}
```

---

##### Active Power Injection Measurement Functions
Moreover, the vector ``\mathbf{h}_\mathcal{P}(\bm {\Theta})`` incorporates functions designed for measuring active power injections. Utilizing the [DC Model](@ref DCNodalNetworkEquationsTutorials), the function defining the active power injection into bus ``i \in \mathcal{N}`` can be derived as follows:
```math
   h_{P_{i}}(\cdot) = B_{ii}\theta_i + \sum_{j \in \mathcal{N}_i \setminus i} {B}_{ij} \theta_j + P_{\text{tr}i} + P_{\text{sh}i},
```
where ``\mathcal{N}_i \setminus i`` contains buses incident to bus ``i``, excluding bus ``i``.

---

##### Bus Voltage Angle Measurement Functions
The vector ``\mathbf{h}_{\bar{\mathcal{P}}_A}(\bm {\Theta})`` comprises functions for measuring bus voltage angles. The function defining the bus voltage angle at bus ``i \in \mathcal{N}`` is straightforward:
```math
    h_{\theta_{i}}(\cdot) = \theta_{i}.
```

---

##### Measurement Values and Variances
The vectors containing the measurement values ``\mathbf{z}_\mathcal{P} = [z_i]`` and variances ``\mathbf{v}_\mathcal{P} = [v_i]`` for wattmeters, where ``i \in \mathcal{P}``, are stored in the variables:
```@repl DCSETutorial
𝐳ₚ = device.wattmeter.active.mean
𝐯ₚ = device.wattmeter.active.variance
```

Similarly, the vectors containing the measurement values ``\mathbf{z}_{\bar{\mathcal{P}}_A} = [z_i]`` and variances ``\mathbf{v}_{\bar{\mathcal{P}}_A} = [v_i]`` for PMUs, where ``i \in \bar{\mathcal{P}}_A``, are stored in the variables:
```@repl DCSETutorial
𝐳ₚₐ = device.pmu.angle.mean
𝐯ₚₐ = device.pmu.angle.variance
```

---

## [Weighted Least-squares Estimation](@id DCSEWLSStateEstimationTutorials)
The solution to the DC state estimation problem is determined by solving the linear weighted least-squares (WLS) problem, represented by the following formula:
```math
	\mathbf H^{T} \bm \Sigma^{-1} \mathbf H \bm {\Theta} = \mathbf H^{T} \bm \Sigma^{-1} (\mathbf z - \mathbf{c}).
```
Here, the vector of measurement values ``\mathbf z \in \mathbb {R}^{k}``, the vector of constant terms ``\mathbf c \in \mathbb {R}^{k}``, the coefficient matrix ``\mathbf {H} \in \mathbb {R}^{k \times n}``, and the diagonal measurement error covariance matrix ``\bm \Sigma \in \mathbb {R}^{k \times k}``, where the diagonal elements hold measurement variances, are defined as follows:
```math
    \mathbf z =
    \begin{bmatrix}
      \mathbf{z}_\mathcal{P}\\[3pt]
      \mathbf{z}_{\bar{\mathcal{P}}_A}
    \end{bmatrix}; \;\;\;
    \mathbf c =
    \begin{bmatrix}
      \mathbf{c}_\mathcal{P}\\[3pt]
      \mathbf{c}_{\bar{\mathcal{P}}_A}\\[3pt]
    \end{bmatrix}; \;\;\;
    \mathbf H =
    \begin{bmatrix}
      \mathbf {H}_\mathcal{P} \\[3pt]
      \mathbf {H}_{\bar{\mathcal{P}}_A}
	\end{bmatrix}; \;\;\;
  \bm \Sigma =
    \begin{bmatrix}
	   \bm \Sigma_\mathcal{P} & \mathbf{0} \\
     \mathbf{0} & \bm \Sigma_{\bar{\mathcal{P}}_A}
	\end{bmatrix}.
```
The inclusion of the vector ``\mathbf{c}_\mathcal{P}`` is necessary due to the fact that measurement functions associated with active power measurements may include constant terms, especially when there are non-zero shift angles of transformers or shunt elements in the system consuming active powers, as evident from the provided measurement functions. On the other hand, the presence of ``\mathbf{c}_{\bar{\mathcal{P}}_A}`` is required when the angle of the slack bus is non-zero.

---

##### Implementation
JuliaGrid initiates the DC state estimation framework by setting up the WLS model, as illustrated in the following:
```@example DCSETutorial
analysis = dcWlsStateEstimation(system, device)
nothing # hide
```

---

##### Coefficient Matrix
To generate the coefficient matrix in JuliaGrid, measurement functions are utilized. Specifically, for active power flow measurements, the coefficient expressions corresponding to the measurement functions ``h_{P_{ij}}(\cdot)`` and ``h_{P_{ji}}(\cdot)`` are defined as follows:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{P_{ij}}(\cdot)}}{\mathrm \partial \theta_{i}} = \cfrac{1}{\tau_{ij} x_{ij}}; \;\;\;
    \cfrac{\mathrm \partial{{h_{P_{ij}}}(\cdot)}}{\mathrm \partial \theta_{j}} = -\cfrac{1}{\tau_{ij} x_{ij}} \\
    \cfrac{\mathrm \partial{h_{P_{ji}}(\cdot)}}{\mathrm \partial \theta_{i}} = -\cfrac{1}{\tau_{ij} x_{ij}}; \;\;\;
  \cfrac{\mathrm \partial{{h_{P_{ji}}}(\cdot)}}{\mathrm \partial \theta_{j}} = \cfrac{1}{\tau_{ij} x_{ij}}.
  \end{aligned}
```

Furthermore, for active power injection measurements, the coefficient expressions corresponding to the measurement function ``h_{P_{i}}(\cdot)`` are defined as follows:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{P_{i}}(\cdot)}}{\mathrm \partial \theta_{i}} = B_{ii}; \;\;\;
  \cfrac{\mathrm \partial{{h_{P_{i}}}(\cdot)}}{\mathrm \partial \theta_{j}} = {B}_{ij}.
  \end{aligned}
```

Lastly, for bus voltage angle measurements, the coefficient expressions are as follows:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{\theta_{i}}(\cdot)}}{\mathrm \partial \theta_{i}} = 1; \;\;\;
    \cfrac{\mathrm \partial{{h_{\theta_{i}}}(\cdot)}}{\mathrm \partial \theta_{j}} = 0.
  \end{aligned}
```

Using the above-described equations, JuliaGrid forms the coefficient matrix ``\mathbf{H} \in \mathbb{R}^{k \times n}``:
```@repl DCSETutorial
𝐇 = analysis.method.coefficient
```
Each row in the matrix corresponds to a specific measurement. The first ``|\mathcal{P}|`` rows correspond to wattmeters, ordered as users add wattmeters, while the last ``|{\bar{\mathcal{P}}_A}|`` rows correspond to PMUs, also in the order users add PMUs.

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

This process is executed using the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimation{LinearWLS{Normal}})) function:
```@example DCSETutorial
solve!(system, analysis)
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

It is essential to note that the slack bus voltage angle is temporarily excluded from the gain matrix ``\mathbf G`` during computation. It is important to emphasize that this internal handling does not alter the stored elements, such as the coefficient matrix.

---

##### [Alternative Formulation](@id DCSEOrthogonalWLSStateEstimationTutorials)
The resolution of the WLS state estimation problem using the conventional method typically progresses smoothly. However, it is widely acknowledged that in certain situations common to real-world systems, this method can be vulnerable to numerical instabilities. Such conditions might impede the algorithm from converging to a satisfactory solution. In such cases, users may opt for an alternative formulation of the WLS state estimation, namely, employing an approach called orthogonal factorization [[1, Sec. 3.2]](@ref DCStateEstimationReferenceManual).

To address ill-conditioned situations arising from significant differences in measurement variances, users can employ an alternative approach:
```@example DCSETutorial
analysis = dcWlsStateEstimation(system, device, Orthogonal)
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

Executing this procedure involves the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimation{LinearWLS{Normal}})) function:
```@example DCSETutorial
solve!(system, analysis)
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

## [Bad Data Processing](@id DCSEBadDataTutorials)
Besides the state estimation algorithm, one of the essential state estimation routines is the bad data processing, whose main task is to detect and identify measurement errors, and eliminate them if possible. This is usually done by processing the measurement residuals [[1, Ch. 5]](@ref DCSEReferenceTutorials), and typically, the largest normalized residual test is used to identify bad data. The largest normalized residual test is performed after we obtained the solution of the state estimation in the repetitive process of identifying and eliminating bad data measurements one after another [[2]](@ref DCSEReferenceTutorials).

To illustrate this process, let us introduce a new measurement that contains an obvious outlier:
```@example DCSETutorial
addWattmeter!(system, device; bus = 3, active = 5.1, variance = 1e-4, noise = false)

nothing # hide
```

Subsequently, we will construct the WLS state estimation model and solve it:
```@example DCSETutorial
analysis = dcWlsStateEstimation(system, device)
solve!(system, analysis)
nothing # hide
```

Now, the bad data processing can be executed:
```@example DCSETutorial
residualTest!(system, device, analysis; threshold = 4.0)
nothing # hide
```

In this step, we employ the largest normalized residual test, guided by the analysis outlined in [[1, Sec. 5.7]](@ref DCSEReferenceTutorials). To be more precise, we compute all measurement residuals based on the obtained estimate of state variables:
```math
    r_{i} = z_i - h_i(\hat {\bm {\Theta}}), \;\;\; i \in \mathcal{M}.
```

The normalized residuals for all measurements are computed as follows:
```math
    \bar{r}_{i} = \cfrac{|r_i|}{\sqrt{C_{ii}}} = \cfrac{|r_i|}{\sqrt{S_{ii}\Sigma_{ii}}}, \;\;\; i \in \mathcal{M},
```

In this equation, we denote the diagonal entries of the residual covariance matrix ``\mathbf C \in \mathbb{R}^{k \times k}`` as ``C_{ii} = S_{ii}\Sigma_{ii}``, where ``S_{ii}`` is the diagonal entry of the residual sensitivity matrix ``\mathbf S`` representing the sensitivity of the measurement residuals to the measurement errors. For this specific configuration, the relationship is expressed as:
```math
    \mathbf C = \mathbf S \bm \Sigma = \bm \Sigma - \mathbf H [\mathbf H^T \bm \Sigma^{-1} \mathbf H]^{-1} \mathbf H^T.
```
It is important to note that only the diagonal entries of ``\mathbf C`` are required. To obtain the inverse, the JuliaGrid package utilizes a computationally efficient sparse inverse method, retrieving only the necessary elements of the inverse.

The subsequent step involves selecting the largest normalized residual, and the ``j``-th measurement is then suspected as bad data and potentially removed from the measurement set ``\mathcal{M}``:
```math
    \bar{r}_{j} = \text{max} \{\bar{r}_{i}, i \in \mathcal{M} \},
```

Users can access this information using the variable:
```@repl DCSETutorial
analysis.outlier.maxNormalizedResidual
```

If the largest normalized residual, denoted as ``\bar{r}_{j}``, satisfies the inequality:
```math
    \bar{r}_{j} \ge \epsilon,
```
the corresponding measurement is identified as bad data and subsequently removed. In this example, the bad data identification `threshold` is set to ``\epsilon = 4``. Users can verify the satisfaction of this inequality by inspecting the variable:
```@repl DCSETutorial
analysis.outlier.detect
```

This indicates that the measurement labeled as:
```@repl DCSETutorial
analysis.outlier.label
```
is removed from the DC model and marked as out-of-service.


Subsequently, we can immediately solve the system again, but this time without the removed measurement:
```@example DCSETutorial
solve!(system, analysis)
nothing # hide
```

Following that, we check for outliers once more:
```@example DCSETutorial
residualTest!(system, device, analysis; threshold = 4.0)
nothing # hide
```

To examine the value:
```@repl DCSETutorial
analysis.outlier.maxNormalizedResidual
```

As this value is now less than the `threshold` ``\epsilon = 4``, the measurement is not removed, or there are no outliers. This can also be verified by observing the bad data flag:
```@repl DCSETutorial
analysis.outlier.detect
```

---

## [Least Absolute Value Estimation](@id DCSELAVTutorials)
The least absolute value (LAV) method provides an alternative estimation approach that is considered more robust in comparison to the WLS method. The WLS state estimation problem relies on specific assumptions about measurement errors, whereas robust estimators aim to remain unbiased even in the presence of various types of measurement errors and outliers. This characteristic eliminates the need for bad data processing, as discussed in [[1, Ch. 6]](@ref DCSEReferenceTutorials). It is important to note that robustness often comes at the cost of increased computational complexity.

It can be demonstrated that the problem can be expressed as a linear programming problem. This section outlines the method as described in [[1, Sec. 6.5]](@ref DCSEReferenceTutorials). To revisit, we consider the system of linear equations:
```math
  \mathbf{z}=\mathbf{h}(\bm {\Theta})+\mathbf{u}.
```

Subsequently, the LAV state estimator is derived as the solution to the optimization problem:
```math
  \begin{aligned}
    \text{minimize}& \;\;\; \mathbf a^T |\mathbf r|\\
    \text{subject\;to}& \;\;\; \mathbf{z} - \mathbf{H}\bm {\Theta} - \mathbf{c} =\mathbf r.
  \end{aligned}
```
Here, ``\mathbf a \in \mathbb {R}^{k}`` is the vector with all entries equal to one, and ``\mathbf r`` represents the vector of measurement residuals. Let ``\bm \eta`` be defined in a manner that ensures:
```math
  |\mathbf r| \preceq \bm \eta,
```
and replace the above inequality with two equalities using the introduction of two non-negative slack variables ``\mathbf q \in \mathbb {R}_{\ge 0}^{k}`` and ``\mathbf w \in \mathbb {R}_{\ge 0}^{k}``:
```math
  \begin{aligned}
    \mathbf r - \mathbf q &= -\bm \eta \\
    \mathbf r + \mathbf w &= \bm \eta.
  \end{aligned}
```

Let us now define four additional non-negative variables:
```math
    \bm {\Theta}_x \in \mathbb {R}_{\ge 0}^{n}; \;\;\; \bm {\Theta}_y  \in \mathbb {R}_{\ge 0}^{n}; \;\;\;
    \mathbf {r}_x \in \mathbb {R}_{\ge 0}^{k}; \;\;\; \mathbf {r}_y \in \mathbb {R}_{\ge 0}^{k},
```
where:
```math
    \bm {\Theta} = \bm {\Theta}_x - \bm {\Theta}_y; \;\;\; \mathbf r = \mathbf {r}_x - \mathbf {r}_y\\
    \mathbf {r}_x = \cfrac{1}{2} \mathbf q; \;\;\;  \mathbf {r}_y = \cfrac{1}{2} \mathbf w.
```
Then, the above two equalities become:
```math
  \begin{aligned}
    \mathbf r - 2\mathbf {r}_x &= -2\bm \eta \\
    \mathbf r + 2 \mathbf {r}_y &= 2\bm \eta,
  \end{aligned}
```
that is:
```math
  \begin{aligned}
    \mathbf {r}_x + \mathbf {r}_y = \bm \eta; \;\;\; \mathbf r = \mathbf {r}_x - \mathbf {r}_y.
  \end{aligned}
```

Hence, the optimization problem can be written:
```math
  \begin{aligned}
    \text{minimize}& \;\;\; \mathbf a^T (\mathbf {r}_x + \mathbf {r}_y)\\
    \text{subject\;to}& \;\;\; \mathbf{H}(\bm {\Theta}_x - \bm {\Theta}_y) + \mathbf {r}_x - \mathbf {r}_y = \mathbf{z} - \mathbf{c}   \\
                       & \;\;\; \bm {\Theta}_x \succeq \mathbf 0, \; \bm {\Theta}_y \succeq \mathbf 0 \\
                       & \;\;\; \mathbf {r}_x \succeq \mathbf 0, \; \mathbf {r}_y \succeq \mathbf 0.
  \end{aligned}
```

To form the above optimization problem, the user can call the following function:
```@example DCSETutorial
using Ipopt
using JuMP # hide

analysis = dcLavStateEstimation(system, device, Ipopt.Optimizer)
nothing # hide
```

Then the user can solve the optimization problem by:
```@example DCSETutorial
JuMP.set_silent(analysis.method.jump) # hide
solve!(system, analysis)
nothing # hide
```
As a result, we obtain optimal values for the four additional non-negative variables, while the state estimator is obtained by:
```math
    \hat{\bm {\Theta}} = \bm {\Theta}_x - \bm {\Theta}_y.
```

Users can retrieve the estimated bus voltage angles ``\hat{\bm {\Theta}} = [\hat{\theta}_i]``, ``i \in \mathcal{N}``, using the variable:
```@repl DCSETutorial
𝚯 = analysis.voltage.angle
```

---

## [Power Analysis](@id DCSEPowerAnalysisTutorials)
After obtaining the solution from the DC state estimation, we can calculate powers related to buses and branches using the [`power!`](@ref power!(::PowerSystem, ::DC)) function:
```@example DCSETutorial
power!(system, analysis)
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
The vector of active power injected by generators to the buses, denoted by ``\mathbf{P}_{\text{p}} = [P_{\text{p}i}]``, can be obtained using:
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

---

## [References](@id DCSEReferenceTutorials)
[1] A. Abur and A. Exposito, *Power System State Estimation: Theory and Implementation*, Taylor & Francis, 2004.

[2] G. Korres, "A distributed multiarea state estimation," *IEEE Trans. Power Syst.*, vol. 26, no. 1, pp. 73–84, Feb. 2011.

[3] M. Cosovic, M. Delalic, D. Raca, and D. Vukobratovic, "Observability analysis for large-scale power systems using factor graphs," *IEEE Trans. Power Syst.*, 36(5), 4791-4799.

[4] A. Monticelli, *State Estimation in Electric Power Systems: A Generalized Approach*, ser. Kluwer international series in engineering and computer science. Springer US, 1999.

[5] H. Horisberger, "Observability analysis for power systems with measurement deficiencies," *IFAC Proceedings Volumes*, vol. 18, no. 7, pp.51–58, 1985.

[6] N. M. Manousakis and G. N. Korres, "Observability analysis for power systems including conventional and phasor measurements," *in Proc. MedPower 2010*, Agia Napa, 2010, pp. 1-8.
