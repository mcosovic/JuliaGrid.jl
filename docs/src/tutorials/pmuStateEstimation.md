# [PMU State Estimation](@id PMUStateEstimationTutorials)
To initiate the process, let us construct the `PowerSystem` type and formulate the AC model:
```@example PMUSETutorial
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.5)
addBus!(system; label = 2, reactive = 0.3)
addBus!(system; label = 3, active = 0.5)

@branch(resistance = 0.02, susceptance = 0.04)
addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.6)
addBranch!(system; label = 2, from = 1, to = 3, reactance = 0.7)
addBranch!(system; label = 3, from = 2, to = 3, reactance = 0.2)

acModel!(system)
nothing # hide
```

To review, we can conceptualize the bus/branch model as the graph denoted by ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where we have the set of buses ``\mathcal{N} = \{1, \dots, n\}``, and the set of branches ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` within the power system:
```@repl PMUSETutorial
𝒩 = collect(keys(system.bus.label))
ℰ = [𝒩[system.branch.layout.from] 𝒩[system.branch.layout.to]]
```

---

Following that, we will introduce the `Measurement` type and incorporate a set of PMUs ``\mathcal{M} \equiv \bar{\mathcal{P}}`` into the graph ``\mathcal{G}``, that capture both bus voltage and branch current phasors. To construct the linear PMU state estimation model, we represent the vector of state variables, as well as phasor measurements, in the rectangular coordinate system. Thus, we initialize the `Measurement` type:
```@example PMUSETutorial
monitoring = measurement(system)
nothing # hide
```

---

!!! ukw "Notation"
    Here, when referring to a vector ``\mathbf a``, we use the notation ``\mathbf a = [a_i]`` or ``\mathbf a = [a_{ij}]``, where ``a_i`` represents the element related with bus ``i \in \mathcal N`` or measurement ``i \in \mathcal M``, while ``a_{ij}`` denotes the element related with branch ``(i,j) \in \mathcal E``.

---

## [State Estimation Model](@id PMUSEModelTutorials)
Initially, PMUs output phasor measurements in polar coordinates. However, these measurements can be interpreted in rectangular coordinates, where the real and imaginary parts of bus voltages and branch current phasors serve as measurements. Additionally, to obtain the linear system of equations, we observe a vector of state variables in rectangular coordinates ``\mathbf x \equiv[\mathbf V_\mathrm{re}, \mathbf V_\mathrm{im}]``:
* ``\mathbf V_\mathrm{re} =\big[\Re(\bar{V}_1),\dots,\Re(\bar{V}_n)\big]^T``, representing the real parts of complex bus voltages,
* ``\mathbf V_\mathrm{im} =\big[\Im(\bar{V}_1),\dots,\Im(\bar{V}_n)\big]^T``, representing the imaginary parts of complex bus voltages.

Consequently, the total number of state variables is ``s = 2n``. It is worth noting that in this approach to state estimation, we do not require the slack bus.

The primary drawback of this method stems from measurement errors, which are associated with polar coordinates. Consequently, the covariance matrix must be transformed from polar to rectangular coordinates. As a result, errors from a single PMU are correlated, leading to a non-diagonal covariance matrix. Despite this, the covariance matrix is commonly treated as diagonal, impacting the state estimation accuracy in such scenarios.

Hence, the model includes real and imaginary parts of bus voltage and current phasor measurements from the set ``\mathcal M``, contributing to the formulation of a linear system of equations:
```math
  \mathbf z=\mathbf h(\mathbf x) + \mathbf u.
```

Here, ``\mathbf h(\mathbf x)= [h_1(\mathbf x)``, ``\dots``, ``h_k(\mathbf x)]^T`` represents the vector of linear measurement functions, ``\mathbf z = [z_1, \dots, z_k]^T`` denotes the vector of measurement values, and ``\mathbf u = [u_1, \dots, u_k]^T`` represents the vector of measurement errors,  where ``k = 2|\bar{\mathcal P}|``.

These errors are assumed to follow a Gaussian distribution with a zero mean and covariance matrix ``\bm \Sigma``. The diagonal elements of ``\bm \Sigma`` correspond to the measurement variances ``\mathbf v = [v_1, \dots, v_k]^T``, while the off-diagonal elements represent the covariances between the measurement errors ``\mathbf w = [w_1, \dots, w_k]^T``.

In summary, upon defining the PMU, each ``i``-th PMU is associated with two measurement functions ``h_{2i-1}(\mathbf x)``, ``h_{2i}(\mathbf x)``, along with their respective measurement values ``z_{2i-1}``, ``z_{2i}``, as well as their variances ``v_{2i-1}``, ``v_{2i}``, and possibly covariances ``w_{2i-1}``, ``w_{2i}``.

---

##### Bus Voltage Phasor Measurements
When a PMU ``(V_i, \theta_i) \in \bar{\mathcal P}`` is introduced at bus ``i \in \mathcal N`` in this type of state estimation, users specify the measurement values, variances, and measurement functions of vectors as follows:
```math
  \mathbf z = [z_{\Re(\bar{V}_i)}, z_{\Im(\bar{V}_i)}], \;\;\;
  \mathbf v = [v_{\Re(\bar{V}_i)}, v_{\Im(\bar{V}_i)}], \;\;\;
  \mathbf h(\mathbf x) = [h_{\Re(\bar{V}_i)}(\mathbf x), h_{\Im(\bar{V}_i)}(\mathbf x)].
```

For example:
```@example PMUSETutorial
addPmu!(
  monitoring; label = "V₂, θ₂", bus = 2, magnitude = 0.9, angle = -0.1,
  varianceMagnitude = 1e-5, varianceAngle = 1e-5
)
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
    h_{\Re(\bar{V}_i)}(\mathbf x) &= \Re(\bar{V}_i)\\
    h_{\Im(\bar{V}_i)}(\mathbf x) &= \Im(\bar{V}_i).
  \end{aligned}
```

The coefficient expressions for measurement functions are as follows:
```math
  \cfrac{\mathrm \partial{h_{\Re(\bar{V}_i)}(\mathbf x)}}{\mathrm \partial \Re(\bar{V}_i)} = 1, \;\;\;
  \cfrac{\mathrm \partial{h_{\Im(\bar{V}_i)}(\mathbf x)}}{\mathrm \partial \Im(\bar{V}_i)} = 1.\;\;\;
```

In the previous example, the user neglected the covariances between the real and imaginary parts of the measurement. However, if desired, the user can also include them in the state estimation model by specifying the covariances of the vector:
```math
  \mathbf w = [w_{\Re(\bar{V}_i)}, w_{\Im(\bar{V}_i)}].
```
```@example PMUSETutorial
addPmu!(
  monitoring; label = "V₃, θ₃", bus = 3, magnitude = 0.9, angle = -0.2,
  varianceMagnitude = 1e-5, varianceAngle = 1e-5, correlated = true
)
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

##### From-Bus Current Phasor Measurements
If the user chooses to include phasor measurement ``(I_{ij}, \psi_{ij}) \in \bar{\mathcal P}`` in the state estimation model, the user will specify the measurement values, variances, and measurement functions of vectors:
```math
  \mathbf z = [z_{\Re(\bar{I}_{ij})}, z_{\Im(\bar{I}_{ij})}], \;\;\;
  \mathbf v = [v_{\Re(\bar{I}_{ij})}, v_{\Im(\bar{I}_{ij})}], \;\;\;
  \mathbf h(\mathbf x) = [h_{\Re(\bar{I}_{ij})}(\mathbf x), h_{\Im(\bar{I}_{ij})}(\mathbf x)].
```

For example:
```@example PMUSETutorial
addPmu!(
  monitoring; label = "I₂₃, ψ₂₃", from = 3, magnitude = 0.3, angle = 0.4,
  varianceMagnitude = 1e-3, varianceAngle = 1e-4
)
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
    h_{\Re(\bar{I}_{ij})}(\mathbf x) &= A\Re(\bar{V}_i) - B\Im(\bar{V}_i) - \left(C\cos\phi_{ij} - D\sin\phi_{ij}\right) \Re(\bar{V}_j) + \left(C\sin\phi_{ij} + D\cos\phi_{ij} \right) \Im(\bar{V}_j) \\
    h_{\Im(\bar{I}_{ij})}(\mathbf x) &= B\Re(\bar{V}_i) + A\Im(\bar{V}_i) - \left(C\sin \phi_{ij} + D\cos\phi_{ij}\right) \Re(\bar{V}_j) - \left(C\cos\phi_{ij} - D\sin\phi_{ij} \right)\Im(\bar{V}_j),
  \end{aligned}
```
where:
```math
  A = \cfrac{g_{ij} + g_{\mathrm{s}ij}}{\tau_{ij}^2},\;\;\;
  B = \cfrac{b_{ij}+b_{\mathrm{s}ij}} {\tau_{ij}^2},\;\;\;
  C = \cfrac{g_{ij}}{\tau_{ij}},\;\;\;
  D = \cfrac{b_{ij}}{\tau_{ij}}.
```

The coefficient expressions for measurement functions are as follows:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ij})}(\mathbf x)}}{\mathrm \partial \Re(\bar{V}_i)} &=
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ij})}(\mathbf x)}}{\mathrm \partial \Im(\bar{V}_i)} = A \\
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ij})}(\mathbf x)}} {\mathrm \partial \Re(\bar{V}_j)} &=
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ij})}(\mathbf x)}} {\mathrm \partial \Im(\bar{V}_j)} = - \left(C\cos\phi_{ij} - D\sin\phi_{ij}\right)\\
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ij})}(\mathbf x)}}{\mathrm \partial \Im(\bar{V}_i)} &=-
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ij})}(\mathbf x)}}{\mathrm \partial \Re(\bar{V}_i)} = -B \\
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ij})}(\mathbf x)}}{\mathrm \partial \Im(\bar{V}_j)} &= -
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ij})}(\mathbf x)}}{\mathrm \partial\Re(\bar{V}_j)} = \left(C\sin\phi_{ij} + D\cos\phi_{ij} \right).
  \end{aligned}
```

In the previous example, the user neglects the covariances between the real and imaginary parts of the measurement. However, if desired, the user can also include them in the state estimation model by specifying the covariances of the vector:
```math
  \mathbf w = [w_{\Re(\bar{I}_{ij})}, w_{\Im(\bar{I}_{ij})}].
```
```@example PMUSETutorial
addPmu!(
  monitoring; label = "I₁₃, ψ₁₃", from = 2, magnitude = 0.3, angle = -0.5,
  varianceMagnitude = 1e-5, varianceAngle = 1e-5, correlated = true
)
nothing # hide
```

Then, the covariances are obtained as follows:
```math
   w_{\Re(\bar{I}_{ij})} = w_{\Im(\bar{I}_{ij})} = \sin z_{\psi_{ij}} \cos z_{\psi_{ij}}(v_{I_{ij}} - v_{\psi_{ij}} z_{I_{ij}}^2).
```

---

##### To-Bus Current Phasor Measurements
If the user chooses to include phasor measurement ``(I_{ji}, \psi_{ji}) \in \bar{\mathcal P}`` in the state estimation model, the user will specify the measurement values, variances, and measurement functions of vectors:
```math
    \mathbf z = [z_{\Re(\bar{I}_{ji})}, z_{\Im(\bar{I}_{ji})}], \;\;\;
    \mathbf v = [v_{\Re(\bar{I}_{ji})}, v_{\Im(\bar{I}_{ji})}], \;\;\;
    \mathbf h(\mathbf x) = [h_{\Re(\bar{I}_{ji})}(\mathbf x), h_{\Im(\bar{I}_{ji})}(\mathbf x)].
```

For example:
```@example PMUSETutorial
addPmu!(
  monitoring; label = "I₃₂, ψ₃₂", to = 3, magnitude = 0.3, angle = -2.9,
  varianceMagnitude = 1e-5, varianceAngle = 1e-5
)
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
    h_{\Re(\bar{I}_{ji})}(\mathbf x) &= \tau_{ij}^2 A \Re(\bar{V}_j) - \tau_{ij}^2 B \Im(\bar{V}_j) - \left(C \cos\phi_{ij} + D \sin \phi_{ij}\right) \Re(\bar{V}_i) - \left( C\sin \phi_{ij} - D\cos \phi_{ij} \right) \Im(\bar{V}_i)\\
    h_{\Im(\bar{I}_{ji})}(\mathbf x) &= \tau_{ij}^2 B \Re(\bar{V}_j) + \tau_{ij}^2 A \Im(\bar{V}_j) + \left(C \sin \phi_{ij} - D \cos\phi_{ij} \right) \Re(\bar{V}_i) - \left(C\cos \phi_{ij} + D\sin \phi_{ij}\right) \Im(\bar{V}_i).
  \end{aligned}
```

The coefficient expressions for measurement functions are as follows:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ji})}(\mathbf x)}}{\mathrm \partial \Re(\bar{V}_i)} &=
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ji})}(\mathbf x)}}{\mathrm \partial \Im(\bar{V}_i)} = - \left(C \cos\phi_{ij} + D \sin \phi_{ij}\right)\\
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ji})}(\mathbf x)}} {\mathrm \partial \Re(\bar{V}_j)} &=
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ji})}(\mathbf x)}} {\mathrm \partial \Im(\bar{V}_j)} = \tau_{ij}^2A\\
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ji})}(\mathbf x)}}{\mathrm \partial \Im(\bar{V}_i)} &= -
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ji})}(\mathbf x)}}{\mathrm \partial \Re(\bar{V}_i)} = -\left(C\sin \phi_{ij} - D\cos \phi_{ij} \right) \\
    \cfrac{\mathrm \partial{h_{\Re(\bar{I}_{ji})}(\mathbf x)}}{\mathrm \partial \Im(\bar{V}_j)} &= -
    \cfrac{\mathrm \partial{h_{\Im(\bar{I}_{ji})}(\mathbf x)}}{\mathrm \partial \Re(\bar{V}_j)} = -\tau_{ij}^2B.
  \end{aligned}
```

As before, we are neglecting the covariances between the real and imaginary parts of the measurement. If desired, we can include them in the state estimation model by specifying the covariances of the vector:
```math
    \mathbf w = [w_{\Re(\bar{I}_{ji})}, w_{\Im(\bar{I}_{ji})}].
```
```@example PMUSETutorial
addPmu!(
  monitoring; label = "I₃₁, ψ₃₁", to = 2, magnitude = 0.3, angle = 2.5,
  varianceMagnitude = 1e-5, varianceAngle = 1e-5, correlated = true
)
nothing # hide
```

Then, the covariances are obtained as follows:
```math
   w_{\Re(\bar{I}_{ji})} = w_{\Im(\bar{I}_{ji})} = \sin z_{\psi_{ji}} \cos z_{\psi_{ji}}(v_{I_{ji}} - v_{\psi_{ji}} z_{I_{ji}}^2).
```

---

## [Weighted Least-Squares Estimation](@id PMUSEWLSStateEstimationTutorials)
The solution to the PMU state estimation problem is determined by solving the linear weighted least-squares (WLS) problem, represented by the following formula:
```math
	\mathbf H^T \bm \Sigma^{-1} \mathbf H \mathbf x = \mathbf H^T \bm \Sigma^{-1} \mathbf z.
```
Here, ``\mathbf z \in \mathbb{R}^k`` denotes the vector of measurement values, ``\mathbf H \in \mathbb {R}^{k \times 2n}`` represents the coefficient matrix, and ``\bm \Sigma \in \mathbb {R}^{k \times k}`` is the measurement error covariance matrix.

---

##### Implementation
JuliaGrid initiates the PMU state estimation framework by setting up the WLS model, as illustrated in the following:
```@example PMUSETutorial
analysis = pmuStateEstimation(monitoring)
nothing # hide
```

---

##### Coefficient Matrix
Using the above-described equations, JuliaGrid forms the coefficient matrix ``\mathbf H``:
```@repl PMUSETutorial
𝐇 = analysis.method.coefficient
```
In this matrix, each row corresponds to a specific measurement in the rectangular coordinate system. Therefore, the ``i``-th PMU is associated with the ``2i - 1`` index of the row, representing the real part of the phasor measurement, while the ``2i`` row corresponds to the imaginary part of the phasor measurement. Columns are ordered based on how the state variables are defined ``\mathbf x \equiv[\mathbf{V}_\mathrm{re},\mathbf{V}_\mathrm{im}]``.

---

##### Precision Matrix
JuliaGrid opts not to retain the covariance matrix ``\bm \Sigma`` but rather stores its inverse, the precision or weighting matrix denoted as ``\mathbf W = \bm \Sigma^{-1}``. The order of these values corresponds to the description provided for the coefficient matrix. Users can access these values using the following command:
```@repl PMUSETutorial
𝐖 = analysis.method.precision
```

The precision matrix does not maintain a diagonal form, indicating that correlations between the real and imaginary parts of the phasor measurements are included in the model. To ignore these correlations, simply omit the `correlated` keyword within the function that adds a PMU. For example:
```@example PMUSETutorial
monitoring = measurement(system)

@pmu(label = "PMU ?", noise = false)
addPmu!(monitoring; bus = 1, magnitude = 1.0, angle = 0.0)
addPmu!(monitoring; bus = 2, magnitude = 0.8745, angle = -0.1529)
addPmu!(monitoring; from = 1, magnitude = 0.3033, angle = -0.7136)
addPmu!(monitoring; from = 2, magnitude = 0.3142, angle = -0.4950)
addPmu!(monitoring; to = 3, magnitude = 0.2809, angle = -2.8954)
nothing # hide
```

Following this, we recreate the WLS state estimation model:
```@example PMUSETutorial
analysis = pmuStateEstimation(monitoring)
nothing # hide
```

Upon inspection, it becomes evident that the precision matrix maintains a diagonal structure:
```@repl PMUSETutorial
𝐖 = analysis.method.precision
```

---

##### Mean Vector
To retrieve the vector ``\mathbf z``, containing the means of Gaussian distributions for each measurement, users can utilize:
```@repl PMUSETutorial
𝐳 = analysis.method.mean
```
These values represent measurement values in the rectangular coordinate system as described earlier.

---

##### Estimate of State Variables
Next, the WLS equation is solved to obtain the estimate of state variables:
```math
	\hat{\mathbf x} = [\mathbf H^T \bm \Sigma^{-1} \mathbf H]^{-1} \mathbf H^T \bm \Sigma^{-1} \mathbf z.
```

This process is executed using the [`solve!`](@ref solve!(::PmuStateEstimation{WLS{Normal}})) function:
```@example PMUSETutorial
solve!(analysis)
```

The initial step involves the LU factorization of the gain matrix:
```math
	\mathbf G = \mathbf H^T \bm \Sigma^{-1} \mathbf H = \mathbf L \mathbf U.
```

!!! tip "Tip"
    By default, JuliaGrid utilizes LU factorization as the primary method to factorize the gain matrix. However, users maintain the flexibility to opt for alternative factorization methods such as LDLt or QR.

Access to the factorized gain matrix is available through:
```@repl PMUSETutorial
𝐋 = analysis.method.factorization.L
𝐔 = analysis.method.factorization.U
```

Finally, JuliaGrid obtains the solution in the rectangular coordinate system and then transforms these solutions into the standard form given in the polar coordinate system.

The estimated bus voltage magnitudes ``\hat{\mathbf V} = [\hat{V}_i]`` and angles ``\hat{\bm {\Theta}} = [\hat{\theta}_i]``, ``i \in \mathcal N``, can be retrieved using the variables:
```@repl PMUSETutorial
𝐕 = analysis.voltage.magnitude
𝚯 = analysis.voltage.angle
```

!!! note "Info"
    It is essential to note that the slack bus does not exist in the case of the PMU state estimation model.

---

##### [Alternative Formulation](@id PMUSEOrthogonalWLSStateEstimationTutorials)
The resolution of the WLS state estimation problem using the conventional method typically progresses smoothly. However, it is widely acknowledged that in certain situations common to real-world systems, this method can be vulnerable to numerical instabilities. Such conditions might impede the algorithm from converging to a satisfactory solution. In such cases, users may opt for an alternative formulation of the WLS state estimation, namely, employing an approach called orthogonal factorization [aburbook; Sec. 3.2](@cite). This approach is suitable when measurement errors are uncorrelated, and the precision matrix remains diagonal.

To address ill-conditioned situations arising from significant differences in measurement variances, users can employ an alternative approach:
```@example PMUSETutorial
analysis = pmuStateEstimation(monitoring, Orthogonal)
nothing # hide
```

To explain the method, we begin with the WLS equation:
```math
	\mathbf H^T \mathbf W \mathbf H \hat{\mathbf x} = \mathbf H^T \mathbf W \mathbf z,
```
where ``\mathbf W = \bm \Sigma^{-1}``. Subsequently, we can write:
```math
  \left({\mathbf W^{1/2}} \mathbf H\right)^T {\mathbf W^{1/2}} \mathbf H  \hat{\mathbf x} = \left({\mathbf W^{1/2}} \mathbf H\right)^T {\mathbf W^{1/2}} \mathbf z.
```

Consequently, we have:
```math
  \bar{\mathbf H}^T  \bar{\mathbf H} \hat{\mathbf x} = \bar{\mathbf H}^T  \bar{\mathbf z},
```
where:
```math
  \bar{\mathbf H} = {\mathbf W^{1/2}} \mathbf H; \;\;\; \bar{\mathbf z} = {\mathbf W^{1/2}} \mathbf z.
```

At this point, QR factorization is performed on the rectangular matrix:
```math
  \bar{\mathbf H} = {\mathbf W^{1/2}} \mathbf H = \mathbf Q \mathbf R.
```

Executing this procedure involves the [`solve!`](@ref solve!(::PmuStateEstimation{WLS{Normal}})) function:
```@example PMUSETutorial
solve!(analysis)
nothing # hide
```

Access to the factorized matrix is possible through:
```@repl PMUSETutorial
𝐐 = analysis.method.factorization.Q
𝐑 = analysis.method.factorization.R
```

To obtain the solution, JuliaGrid avoids materializing the orthogonal matrix ``\mathbf Q`` and proceeds to solve the system, resulting in the estimate of bus voltage magnitudes ``\hat{\mathbf V} = [\hat{V}_i]`` and angles ``\hat{\bm \Theta} = [\hat{\theta}_i]``, where ``i \in \mathcal N``:
```@repl PMUSETutorial
𝐕 = analysis.voltage.magnitude
𝚯 = analysis.voltage.angle
```

---

## [Least Absolute Value Estimation](@id PMUSELAVTutorials)
The least absolute value (LAV) method provides an alternative estimation approach that is considered more robust in comparison to the WLS method. The WLS state estimation problem relies on specific assumptions about measurement errors, whereas robust estimators aim to remain unbiased even in the presence of various types of measurement errors and outliers. This characteristic eliminates the need for bad data analysis, as discussed in [aburbook; Ch. 6](@cite). It is important to note that robustness often comes at the cost of increased computational complexity.

It can be demonstrated that the problem can be expressed as a linear programming problem. This section outlines the method as described in [aburbook; Sec. 6.5](@cite). To revisit, we consider the system of linear equations:
```math
  \mathbf{z}=\mathbf{h}(\mathbf x)+\mathbf{u}+\mathbf{w}.
```

The LAV state estimator is then formulated as the solution to the following optimization problem:
```math
  \begin{aligned}
    \text{minimize}& \;\;\; \sum_{i \in \mathcal M} |r_i|\\
    \text{subject\;to}& \;\;\; z_i - h_i(\mathbf x) =  r_i, \;\;\; \forall i \in \mathcal M,
  \end{aligned}
```
where ``r_i`` denotes the residual of the ``i``-th measurement.

To explicitly handle absolute values, we introduce two nonnegative variables ``u_i \ge 0`` and ``v_i \ge 0``, referred to as positive and negative deviations. This allows the optimization problem to be rewritten as:
```math
  \begin{aligned}
    \text{minimize}& \;\;\; \sum_{i \in \mathcal M} (u_i + v_i) \\
    \text{subject\;to}  & \;\;\; z_i - h_i(\mathbf x) = u_i - v_i, \;\;\; \forall i \in \mathcal M \\
                        & \;\;\; u_i \geq  0, \; v_i \geq  0, \;\;\; \forall i \in \mathcal M.
  \end{aligned}
```

To form the above optimization problem, the user can call the following function:
```@example PMUSETutorial
using Ipopt
using JuMP # hide

analysis = pmuLavStateEstimation(monitoring, Ipopt.Optimizer)
nothing # hide
```

Then the user can solve the optimization problem by:
```@example PMUSETutorial
JuMP.set_silent(analysis.method.jump) # hide
solve!(analysis)
nothing # hide
```

Users can retrieve the estimated bus voltage magnitudes ``\hat{\mathbf V} = [\hat{V}_i]`` and angles ``\hat{\bm {\Theta}} = [\hat{\theta}_i]``, ``i \in \mathcal{N}``, using:
```@repl PMUSETutorial
𝐕 = analysis.voltage.magnitude
𝚯 = analysis.voltage.angle
```

---

## [Power Analysis](@id PMUPowerAnalysisTutorials)
Once the computation of voltage magnitudes and angles at each bus is completed, various electrical quantities can be determined. JuliaGrid offers the [`power!`](@ref power!(::AcPowerFlow)) function, which enables the calculation of powers associated with buses and branches. Here is an example code snippet demonstrating its usage:
```@example PMUSETutorial
power!(analysis)
nothing # hide
```

The function stores the computed powers in the rectangular coordinate system. It calculates the following powers related to buses and branches:

| Type   | Power                                                          | Active                                           | Reactive                                         |
|:-------|:---------------------------------------------------------------|:-------------------------------------------------|:-------------------------------------------------|
| Bus    | [Injections](@ref BusInjectionsTutorials)                      | ``\mathbf P = [P_i]``                            | ``\mathbf Q = [Q_i]``                            |
| Bus    | [Generator injections](@ref PMUGeneratorPowerInjectionsManual) | ``\mathbf P_\mathrm{p} = [P_{\mathrm{p}i}]``     | ``\mathbf Q_\mathrm{p} = [Q_{\mathrm{p}i}]``     |
| Bus    | [Shunt elements](@ref BusShuntElementTutorials)                | ``\mathbf P_\mathrm{sh} = [{P}_{\mathrm{sh}i}]`` | ``\mathbf Q_\mathrm{sh} = [{Q}_{\mathrm{sh}i}]`` |
| Branch | [From-bus end flows](@ref BranchNetworkEquationsTutorials)     | ``\mathbf P_\mathrm{i} = [P_{ij}]``              | ``\mathbf Q_\mathrm{i} = [Q_{ij}]``              |
| Branch | [To-bus end flows](@ref BranchNetworkEquationsTutorials)       | ``\mathbf P_\mathrm{j} = [P_{ji}]``              | ``\mathbf Q_\mathrm{j} = [Q_{ji}]``              |
| Branch | [Shunt elements](@ref BranchShuntElementsTutorials)            | ``\mathbf P_\mathrm{s} = [P_{\mathrm{s}ij}]``    | ``\mathbf Q_\mathrm{s} = [P_{\mathrm{s}ij}]``    |
| Branch | [Series elements](@ref BranchSeriesElementTutorials)           | ``\mathbf P_\mathrm{l} = [P_{\mathrm{l}ij}]``    | ``\mathbf Q_\mathrm{l} = [Q_{\mathrm{l}ij}]``    |
|        |                                                                |                                                  |                                                  |

!!! note "Info"
    For a clear comprehension of the equations, symbols presented in this section, as well as for a better grasp of power directions, please refer to the [Unified Branch Model](@ref UnifiedBranchModelTutorials).

---

##### Power Injections
[Active and reactive power injections](@ref BusInjectionsTutorials) are stored as the vectors ``\mathbf{P} = [P_i]`` and ``\mathbf{Q} = [Q_i]``, respectively, and can be retrieved using the following commands:
```@repl PMUSETutorial
𝐏 = analysis.power.injection.active
𝐐 = analysis.power.injection.reactive
```

----

##### [Generator Power Injections](@id PMUGeneratorPowerInjectionsManual)
We can calculate the active and reactive power injections supplied by generators at each bus ``i \in \mathcal{N}`` by summing the active and reactive power injections and the active and reactive power demanded by consumers at each bus:
```math
  \begin{aligned}
    P_{\text{p}i} &= P_i + P_{\text{d}i}\\
    Q_{\text{p}i} &= Q_i + Q_{\text{d}i}.
  \end{aligned}
```

The active and reactive power injections from the generators at each bus are stored as vectors, denoted by ``\mathbf{P}_{\text{p}} = [P_{\text{p}i}]`` and ``\mathbf{Q}_{\text{p}} = [Q_{\text{p}i}]``, which can be obtained using:
```@repl PMUSETutorial
𝐏ₚ = analysis.power.supply.active
𝐐ₚ = analysis.power.supply.reactive
```

---

##### Power at Bus Shunt Elements
[Active and reactive powers](@ref BusShuntElementTutorials) associated with the shunt elements at each bus are represented by the vectors ``\mathbf{P}_{\text{sh}} = [{P}_{\text{sh}i}]`` and ``\mathbf{Q}_{\text{sh}} = [{Q}_{\text{sh}i}]``. To retrieve these powers in JuliaGrid, use the following commands:
```@repl PMUSETutorial
𝐏ₛₕ = analysis.power.shunt.active
𝐐ₛₕ = analysis.power.shunt.reactive
```

---

##### Power Flows
The resulting [active and reactive power flows](@ref BranchNetworkEquationsTutorials) at each from-bus end are stored as the vectors ``\mathbf{P}_{\text{i}} = [P_{ij}]`` and ``\mathbf{Q}_{\text{i}} = [Q_{ij}],`` respectively, and can be retrieved using the following commands:
```@repl PMUSETutorial
𝐏ᵢ = analysis.power.from.active
𝐐ᵢ = analysis.power.from.reactive
```

The vectors of [active and reactive power flows](@ref BranchNetworkEquationsTutorials) at the to-bus end are stored as ``\mathbf{P}_\mathrm{j} = [P_{ji}]`` and ``\mathbf{Q}_\mathrm{j} = [Q_{ji}]``, respectively, and can be retrieved using the following code:
```@repl PMUSETutorial
𝐏ⱼ = analysis.power.to.active
𝐐ⱼ = analysis.power.to.reactive
```

---

##### Power at Branch Shunt Elements
[Active and reactive powers](@ref BranchShuntElementsTutorials) associated with the branch shunt elements at each branch are represented by the vectors ``\mathbf{P}_{\text{s}} = [P_{\text{s}ij}]`` and ``\mathbf{Q}_{\text{s}} = [Q_{\text{s}ij}]``. We can retrieve these values using the following code:
```@repl PMUSETutorial
𝐏ₛ = analysis.power.charging.active
𝐐ₛ = analysis.power.charging.reactive
```

---

##### Power at Branch Series Elements
[Active and reactive powers](@ref BranchSeriesElementTutorials) associated with the branch series element at each branch are represented by the vectors ``\mathbf{P}_{\text{l}} = [P_{\text{l}ij}]`` and ``\mathbf{Q}_{\text{l}} = [Q_{\text{l}ij}]``. We can retrieve these values using the following code:
```@repl PMUSETutorial
𝐏ₗ = analysis.power.series.active
𝐐ₗ = analysis.power.series.reactive
```

---

## [Current Analysis](@id PMUCurrentAnalysisTutorials)
JuliaGrid offers the [`current!`](@ref current!(::AcPowerFlow)) function, which enables the calculation of currents associated with buses and branches. Here is an example code snippet demonstrating its usage:
```@example PMUSETutorial
current!(analysis)
nothing # hide
```

The function stores the computed currents in the polar coordinate system. It calculates the following currents related to buses and branches:

| Type   | Current                                                    | Magnitude                                     | Angle                                           |
|:-------|:-----------------------------------------------------------|:----------------------------------------------|:------------------------------------------------|
| Bus    | [Injections](@ref BusInjectionsTutorials)                  | ``\mathbf I = [I_i]``                         | ``\bm \psi = [\psi_i]``                         |
| Branch | [From-bus end flows](@ref BranchNetworkEquationsTutorials) | ``\mathbf I_\mathrm{i} = [I_{ij}]``           | ``\bm \psi_\mathrm{i} = [\psi_{ij}]``           |
| Branch | [To-bus end flows](@ref BranchNetworkEquationsTutorials)   | ``\mathbf I_\mathrm{j} = [I_{ji}]``           | ``\bm \psi_\mathrm{j} = [\psi_{ji}]``           |
| Branch | [Series elements](@ref BranchSeriesElementTutorials)       | ``\mathbf I_\mathrm{l} = [I_{\mathrm{l}ij}]`` | ``\bm \psi_\mathrm{l} = [\psi_{\mathrm{l}ij}]`` |
|        |                                                            |                                               |                                                 |

!!! note "Info"
    For a clear comprehension of the equations, symbols presented in this section, as well as for a better grasp of power directions, please refer to the [Unified Branch Model](@ref UnifiedBranchModelTutorials).

---

##### Current Injections
In JuliaGrid, [complex current injections](@ref BusInjectionsTutorials) are stored in the vector of magnitudes denoted as ``\mathbf{I} = [I_i]`` and the vector of angles represented as ``\bm{\psi} = [\psi_i]``. You can retrieve them using the following commands:
```@repl PMUSETutorial
𝐈 = analysis.current.injection.magnitude
𝛙 = analysis.current.injection.angle
```

---

##### Current Flows
To obtain the vectors of magnitudes ``\mathbf{I}_{\text{i}} = [I_{ij}]`` and angles ``\bm{\psi}_{\text{i}} = [\psi_{ij}]`` for the resulting [complex current flows](@ref BranchNetworkEquationsTutorials), you can use the following commands:
```@repl PMUSETutorial
𝐈ᵢ = analysis.current.from.magnitude
𝛙ᵢ = analysis.current.from.angle
```

Similarly, we can obtain the vectors of magnitudes ``\mathbf{I}_{\text{j}} = [I_{ji}]`` and angles ``\bm{\psi}_{\text{j}} = [\psi_{ji}]`` of the resulting [complex current flows](@ref BranchNetworkEquationsTutorials) using the following code:
```@repl PMUSETutorial
𝐈ⱼ = analysis.current.to.magnitude
𝛙ⱼ = analysis.current.to.angle
```

---

##### Current at Branch Series Elements
To obtain the vectors of magnitudes ``\mathbf{I}_{\text{l}} = [I_{\text{l}ij}]`` and angles ``\bm{\psi}_{\text{l}} = [\psi_{\text{l}ij}]`` of the resulting [complex current flows](@ref BranchSeriesElementTutorials), one can use the following code:
```@repl PMUSETutorial
𝐈ₗ = analysis.current.series.magnitude
𝛙ₗ = analysis.current.series.angle
```