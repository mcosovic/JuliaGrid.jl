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
analysis = dcStateEstimation(system, device)
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

This process is executed using the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS})) function:
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
analysis = dcStateEstimation(system, device, Orthogonal)
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

Executing this procedure involves the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS})) function:
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
analysis = dcStateEstimation(system, device)
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

analysis = dcStateEstimation(system, device, Ipopt.Optimizer)
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

## [Observability Analysis](@id DCSEObservabilityAnalysisTutorials)
The state estimation algorithm aims to estimate the values of the state variables based on the measurement model described as a system of equations. Prior to applying the state estimation algorithm, the observability analysis determines the existence and uniqueness of the solution for the underlying system of equations. In cases where a unique solution is not guaranteed, the observability analysis identifies observable islands and prescribes an additional set of equations (pseudo-measurements) to achieve a unique solution [[3]](@ref DCSEReferenceTutorials).

---

##### Identification of Observable Islands
Within the DC state estimation framework, observable islands are defined exclusively using measurements from wattmeters. This approach aligns with the standard observability analysis for nonlinear state estimation in power systems, typically performed on the linear decoupled measurement model [[4, Ch. 7]](@ref DCSEReferenceTutorials).

Let us illustrate this concept with the following example, where measurements form an unobservable system:
```@example DCSEObservability
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.1)
addBus!(system; label = "Bus 3", type = 1, active = 0.05)
addBus!(system; label = "Bus 4", type = 1, active = 0.05)
addBus!(system; label = "Bus 5", type = 1, active = 0.05)
addBus!(system; label = "Bus 6", type = 1, active = 0.05)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 3", to = "Bus 5", reactance = 0.01)
addBranch!(system; label = "Branch 4", from = "Bus 3", to = "Bus 4", reactance = 0.01)
addBranch!(system; label = "Branch 5", from = "Bus 5", to = "Bus 6", reactance = 0.01)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)

device = measurement()

@wattmeter(label = "Wattmeter ?: !")
addWattmeter!(system, device; from = "Branch 1", active = 0.31, variance = 1e-4)
addWattmeter!(system, device; from = "Branch 3", active = 0.09, variance = 1e-4)
addWattmeter!(system, device; bus = "Bus 3", active = -0.05, variance = 1e-4)
addWattmeter!(system, device; bus = "Bus 3", active = -0.05, variance = 1e-4)

nothing # hide
``` 

If the system lacks observability, the observability analysis needs to identify all potential observable islands that can be independently solved. An observable island is defined as follows: It is a segment of the power system where the flows across all branches within that island can be calculated solely from the available measurements. This independence holds regardless of the values chosen for angular reference [[4, Sec. 7.1.1]](@ref DCSEReferenceTutorials). Within this context, two types of observable islands are evident:
* flow observale islands,
* maximal observable islands.

The selection between them relies on the power system's structure and the available measurements. Opting for detecting only flow observable islands simplifies the island detection function's complexity but increases the complexity in the restoration function compared to identifying maximal observable islands.

---

##### Flow Observale Islands
To identify flow observable islands, JuliaGrid employs a topological method outlined in [[5]](@ref DCSEReferenceTutorials). The process begins with the examination of all active power flow measurements from wattmeters, aiming to determine the largest sets of connected buses within the network linked by branches with active power flow measurements. Subsequently, the analysis considers individual boundary or tie active power injection measurements, involving two islands that may potentially be merged into a single observable island. The user can initiate this process by calling the function:
```@example DCSEObservability
islands = islandTopologicalFlow(system, device.wattmeter)
nothing # hide
``` 

As a result, four flow observable islands are identified. The first island comprises `Bus 1` and `Bus 2`, the second island is formed by `Bus 3` and `Bus 5`, while the third and fourth islands consist of `Bus 4` and `Bus 6`, respectively:
```@repl DCSEObservability
islands.island
nothing # hide
```

Additionally, users can inspect the tie buses and branches resulting from the observability analysis we conducted:
```@repl DCSEObservability
islands.tie.bus
islands.tie.branch
nothing # hide
```
This tie data will be utilized throughout the restoration step, where we introduce pseudo-measurements to merge the observable flow islands obtained.

---

##### Maximal Observale Islands
To identify maximal observable islands, we extend the analysis with an additional processing step. After processing individual injection tie measurements, we are left with a series of injection measurements that are not entirely contained within any observable zone. In this set of remaining tie injections, we now examine pairs involving three and only three previously determined observable zones (including individual buses). If we find such a pair, the three islands may be merged, and all injection measurements involving only nodes of this new island are excluded from further consideration. The procedure then restarts at the stage where we process tie active power injection measurements involving two and only two islands. If no mergers are possible with pairs, we then consider sets of three injection measurements involving four islands, and so on [[5]](@ref DCSEReferenceTutorials). The user can initiate this by calling the function:
```@example DCSEObservability
islands = islandTopological(system, device.wattmeter)
nothing # hide
``` 

The outcome reveals the identification of two maximal observable islands:
```@repl DCSEObservability
islands.island
nothing # hide
```
It is evident that upon comparing this result with the flow observable islands, the merging of the two injection measurements at `Bus 3` consolidated the first, second, and third flow observable islands into a single island.

Here we can observe tie data:
```@repl DCSEObservability
islands.tie.bus
islands.tie.branch
nothing # hide
```
Compared to the tie data obtained after detecting flow observable islands, we now have a smaller set, indicating that the restoration step will be more computationally efficient.

---

##### Observability Restoration
After determining the islands, the observability analysis merges these islands in a manner that protect previously determined observable states from being altered by the new set of equations defined by the additional measurements, called pseudo-measurements. In general, this can be achieved by ensuring that the set of new measurements forms a non-redundant set [[4, Sec. 7.3.2]](@ref DCSEReferenceTutorials), i.e., the set of equations must be linearly independent with respect to the global system. The goal of observability restoration is to find this non-redundant set.

As a consequence, the power system is divided into ``m`` islands. Subsequently, we focus on the set of measurements ``\mathcal{M}_\text{r} \subset \mathcal{M}``, which exclusively consists of:
* active power injection measurements at tie buses,
* bus voltage angle measurements.
These measurements are retained from the phase where we identify observable islands and are crucial in determining whether or not we need additional pseudo-measurements to be included in the measurement set ``\mathcal{M}``. In this specific example, we do not have active power injection measurements at tie buses remaining after the identification of maximal observable islands. However, if we proceed with flow observable islands to the restoration step, we will have two injection measurements at `Bus 3`.

However, let us introduce the matrix ``\mathbf W_{\text{r}} \in \mathbb{R}^{r \times m}``, where ``r = |\mathcal{M}_\text{r}|``. This matrix can be conceptualized as the coefficient matrix of a reduced network with ``m`` columns corresponding to islands and ``r`` rows associated with the set ``\mathcal{M}_\text{r}``. The measurement functions linked to the set ``\mathcal{M}_\text{r}`` define the coefficient matrix ``\mathbf H_\text{r}``, and the matrix ``\mathbf W_{\text{r}}`` can be constructed by summing the columns of ``\mathbf H_\text{r}`` that belong to a specific island [[6]](@ref DCSEReferenceTutorials).

Subsequently, we require the set of pseudo-measurements ``\mathcal{M}_\text{p}``. For instance, let us define this set as follows:
```@example DCSEObservability
pseudo = measurement()

addWattmeter!(system, pseudo; label = "Pseudo 1", bus = "Bus 1", active = 0.31)
addWattmeter!(system, pseudo; label = "Pseudo 2", bus = "Bus 6", active = -0.05)
nothing # hide
```  

Next, we define the reduced coefficient matrix ``\mathbf W_{\text{p}} \in \mathbb{R}^{p \times m}`` associated with the pseudo-measurement set ``\mathcal{M}_\text{p}``. From all pseudo-measurements forming the matrix`` \mathbf W_{\text{p}}``, the restoration step will utilize only the following:
* active power flow measurements between tie buses,
* active power injection measurements at tie buses,
* bus voltage angle measurements,
where ``p = |\mathcal{M}_\text{p}|``. In the current example, the pseudo-measurement `Pseudo 2` will contribute to the construction of the matrix ``\mathbf W_{\text{p}}``. Similar to the previous case, measurement functions linked to the set ``\mathcal{M}_\text{p}`` define the coefficient matrix ``\mathbf H_\text{p}``, and the matrix ``\mathbf W_{\text{p}}`` can be viewed as the sum of the columns of ``\mathbf H_\text{p}`` belonging to a specific flow island. Additionally, users have the option to include bus voltage angle measurements from PMUs. In this scenario, restoration can be conducted without merging observable islands into one island, as each island becomes globally observable when one angle is known.

Additionally, it is important to note that during the restoration step, JuliaGrid initially processes active power measurements and subsequently handles bus voltage angle measurements if they are present in the set of pseudo-measurements. Consequently, users can execute the observability restoration procedure with the following:
```@example DCSEObservability
restorationGram!(system, device, pseudo, islands; threshold = 1e-6)
nothing # hide
``` 

The function constructs the reduced coefficient matrix as follows:
```math
  \mathbf W = \begin{bmatrix} \mathbf W_{\text{r}} \\ \mathbf W_{\text{p}} \end{bmatrix},
```
and forms the corresponding Gram matrix:
```math
  \mathbf M = \mathbf W \mathbf W^T.
```

The decomposition of ``\mathbf M`` into its ``\mathbf Q`` and ``\mathbf R`` factors is achieved through QR factorization. Non-redundant measurements are identified by non-zero diagonal elements in ``\mathbf R``. Specifically, if the diagonal element satisfies:
```math
    |R_{ii}| < \epsilon,
```
JuliaGrid designates the corresponding measurement as redundant, where ``\epsilon`` represents a pre-determined zero pivot `threshold`, set to `1e-6` in this example. The minimal set of pseudo-measurements for observability restoration corresponds to the non-zero diagonal elements at positions associated with the candidate pseudo-measurements. It is essential to note that an inappropriate choice of the zero pivot threshold may adversely affect observability restoration. Additionally, there is a possibility that the set of pseudo-measurements ``\mathcal{M}_\text{p}`` may not be sufficient for achieving observability restoration.

Consequently, the `Pseudo 2` measurement successfully restores observability, and this measurement is added to the `device` variable, which stores actual measurements:
```@repl DCSEObservability
device.wattmeter.label
nothing # hide
```

Here, we can verify the updated islands structure with the inclusion of the new pseudo-measurement:
```@example DCSEObservability
islands = islandTopological(system, device.wattmeter)
nothing # hide
``` 

Furthermore, we can confirm that the system is observable:
```@repl DCSEObservability
islands.island
nothing # hide
```

Next, we can construct the DC state estimation model and resolve it to obtain estimates of bus voltage angles:
```@example DCSEObservability
analysis = dcStateEstimation(system, device)
solve!(system, analysis)
nothing # hide
```

---

## [Power Analysis](@id DCSEPowerAnalysisTutorials)
After obtaining the solution from the DC state estimation, we can calculate powers related to buses and branches using the [`power!`](@ref power!(::PowerSystem, ::DC)) function:
```@example DCSEObservability
power!(system, analysis)
nothing # hide
```

!!! note "Info"
    For a clear comprehension of the equations, symbols provided below, as well as for a better grasp of power directions, please refer to the [Unified Branch Model](@ref UnifiedBranchModelTutorials).

---

##### Power Injections
[Active power injections](@ref DCBusInjectionTutorials) are stored as the vector ``\mathbf{P} = [P_i]``, and can be retrieved using the following commands:
```@repl DCSEObservability
𝐏 = analysis.power.injection.active
```

---

##### Generator Power Injections
We can determine the active power supplied by generators to the buses by summing the active power injections and the active power demanded by consumers at each bus:
```math
    P_{\text{p}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}.
```
The vector of active power injected by generators to the buses, denoted by ``\mathbf{P}_{\text{p}} = [P_{\text{p}i}]``, can be obtained using:
```@repl DCSEObservability
𝐏ₚ = analysis.power.supply.active
```

---

##### Power Flows
The resulting [active power flows](@ref DCBranchNetworkEquationsTutorials) are stored as the vector ``\mathbf{P}_{\text{i}} = [P_{ij}]``, which can be retrieved using:
```@repl DCSEObservability
𝐏ᵢ = analysis.power.from.active
```

Similarly, the resulting [active power flows](@ref DCBranchNetworkEquationsTutorials) are stored as the vector ``\mathbf{P}_{\text{j}} = [P_{ji}]``, which can be retrieved using:
```@repl DCSEObservability
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
