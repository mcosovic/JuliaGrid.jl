# [Bad Data Analysis](@id BadDataTutorials)
One of the essential state estimation routines is the bad data analysis, which follows after obtaining the weighted least-squares (WLS) estimator. Its main task is to detect and identify measurement errors, and eliminate them if possible. This is usually done by processing the measurement residuals [aburbook; Ch. 5](@cite), and typically, the largest normalized residual test is used to identify bad data. The largest normalized residual test is performed after we obtain the state estimation solution in the repetitive process of identifying and eliminating bad data measurements one after another [korres2010distributed](@cite).

Additionally, the Chi-squared test, which can precede the largest normalized residual test, serves to detect the presence of bad data and quickly determine if the largest normalized residual test should be performed [aburbook; Sec. 5.4](@cite).

To begin, construct the `PowerSystem` type and formulate the AC model:
```@example BadData
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

---

Following that, we introduce the `Measurement` type, which represents a set of measurement devices ``\mathcal M``:
```@example BadData
monitoring = measurement(system)

addWattmeter!(monitoring; label = "Wattmeter 1", bus = 3, active = -0.5)
addWattmeter!(monitoring; label = "Wattmeter 2", from = 1, active = 0.2)
addWattmeter!(monitoring; label = "Wattmeter 3", bus = 3, active = 3.1)

addVarmeter!(monitoring; label = "Varmeter 1", bus = 2, reactive = -0.3)
addVarmeter!(monitoring; label = "Varmeter 3", from = 1, reactive = 0.2)

addPmu!(monitoring; label = "PMU 1", bus = 1, magnitude = 1.0, angle = 0.0)
addPmu!(monitoring; label = "PMU 2", bus = 3, magnitude = 0.9, angle = -0.2)
nothing # hide
```

---

Let the WLS estimator ``\hat{\mathbf x}`` be obtained by solving the AC state estimation:
```@example BadData
analysis = gaussNewton(monitoring)
stateEstimation!(analysis)
```

---

## [Chi-Squared Test](@id ChiTestTutorials)
Next, we perform the Chi-squared test to check for the presence of outliers:
```@example BadData
chi = chiTest(analysis; confidence = 0.96)
nothing # hide
```

At this stage, JuliaGrid uses the objective value obtained from the AC state estimation:
```math
	f(\hat{\mathbf x}) = \sum_{i=1}^k\cfrac{[z_i - h_i(\hat{\mathbf x})]^2}{v_i},
```

This value is stored in the `ChiTest` type as:
```@repl BadData
chi.objective
```

Next, retrieve the value from the Chi-squared distribution corresponding to the detection `confidence` and ``(k - s)`` degrees of freedom, where ``k`` is the number of measurement functions and ``s`` is the number of state variables. This provides the value of ``\chi^2_p(k - s)``:
```@repl BadData
chi.threshold
```

Then, the bad data detection test can be defined as:
```math
	f(\hat{\mathbf x}) \geq \chi^2_p(k - s).
```

If the inequality is satisfied, bad data is suspected in the measurement set:
```@repl BadData
chi.detect
```

---

## [Largest Normalized Residual Test](@id ResidualTestTutorials)
As indicated by the Chi-squared test, bad data is present in the measurement set. Then perform the largest normalized residual test to identify the outlier and remove it from service:
```@example BadData
outlier = residualTest!(analysis; threshold = 4.0)

nothing # hide
```

In this step, we use the largest normalized residual test following the analysis outlined in [aburbook; Sec. 5.7](@cite). More precisely, we compute all measurement residuals based on the obtained estimate of the state variables:
```math
    r_i = z_i - h_i(\hat{\mathbf x}), \;\;\; i \in \mathcal M.
```

The normalized residuals for all measurements are computed as follows:
```math
    \bar{r}_i = \cfrac{|r_i|}{\sqrt{C_{ii}}}, \;\;\; i \in \mathcal M.
```

In this equation, ``C_{ii}`` denotes the ``i``-th diagonal entry of the residual covariance matrix ``\mathbf C \in \mathbb{R}^{k \times k}``.

Next, the largest normalized residual is selected, and the ``j``-th measurement is then identified as bad data and potentially removed from service:
```math
    \bar{r}_j = \max \{\bar{r}_i, \forall i \in \mathcal{M} \}.
```

Users can access this information using the variable:
```@repl BadData
outlier.maxNormalizedResidual
```

If the largest normalized residual, denoted as ``\bar{r}_j``, satisfies the inequality:
```math
    \bar{r}_j \ge \epsilon,
```
the corresponding measurement is identified as bad data and removed from service. In this example, the bad data identification `threshold` is set to ``\epsilon = 4``. Users can verify the satisfaction of this inequality by inspecting:
```@repl BadData
outlier.detect
```

This indicates that the measurement with label:
```@repl BadData
outlier.label
```
is marked as out-of-service.

Then we can solve the system again, but this time without the out-of-service measurement:
```@example BadData
analysis = gaussNewton(monitoring)
stateEstimation!(analysis)
nothing # hide
```

Following that, we check for outliers once more:
```@example BadData
outlier = residualTest!(analysis; threshold = 4.0)
nothing # hide
```

To examine the maximum normalized residual:
```@repl BadData
outlier.maxNormalizedResidual
```

As this value is now less than the `threshold` ``\epsilon = 4``, no measurement is removed from service, indicating that there are no outliers. This can also be verified by observing the bad data flag:
```@repl BadData
outlier.detect
```

---

##### Residual Covariance Matrix
In AC state estimation, the residual covariance matrix ``\mathbf C`` is given by:
```math
    \mathbf C = \mathbf S \bm \Sigma = \bm \Sigma - \mathbf J(\hat{\mathbf x}) [\mathbf J(\hat{\mathbf x})^T \bm \Sigma^{-1} \mathbf J(\hat{\mathbf x})]^{-1} \mathbf J(\hat{\mathbf x})^T,
```
while for DC state estimation and state estimation using only PMUs, it is computed as:
```math
    \mathbf C = \mathbf S \bm \Sigma = \bm \Sigma - \mathbf H [\mathbf H^T \bm \Sigma^{-1} \mathbf H]^{-1} \mathbf H^T.
```

It is important to note that only the diagonal entries of ``\mathbf C`` are required for the normalized residual test. The main computational challenge lies in computing the inverse on the right-hand side of the equations. The JuliaGrid package uses a computationally efficient sparse inverse method, obtaining only the necessary elements.

Internally, JuliaGrid avoids forming the full inverse. If the WLS estimator was solved with `LU`, the sparse LU factorization is reused to compute the selected sparse inverse. If it was solved with `LL`, the Cholesky factorization is reused through a selected-inverse projection. For other WLS methods, JuliaGrid first attempts a local Cholesky factorization of the gain matrix and falls back to sparse LU when Cholesky is not applicable.