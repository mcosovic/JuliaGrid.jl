# [Bad Data Analysis](@id BadDataTutorials)
One of the essential state estimation routines is the bad data analysis, which follows after obtaining the weighted least-squares (WLS) estimator. Its main task is to detect and identify measurement errors, and eliminate them if possible. This is usually done by processing the measurement residuals [aburbook; Ch. 5](@cite), and typically, the largest normalized residual test is used to identify bad data. The largest normalized residual test is performed after we obtained the solution of the state estimation in the repetitive process of identifying and eliminating bad data measurements one after another [korres2010distributed](@cite).

Additionally, the Chi-squared test, which can precede the largest normalized residual test, serves to detect the presence of bad data and quickly determine if the largest normalized residual test should be performed [aburbook; Sec. 5.4](@cite).

To initiate the process, let us construct the `PowerSystem` type and formulate the AC model:
```@example BadData
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

---

Following that, we introduce the `Measurement` type, which represents a set of measurement devices ``\mathcal M``:
```@example BadData
device = measurement()

addWattmeter!(system, device; label = "Watmeter 1", bus = 3, active = -0.5)
addWattmeter!(system, device; label = "Watmeter 2", from = 1, active = 0.2)
addWattmeter!(system, device; label = "Watmeter 3", bus = 3, active = 3.1)

addVarmeter!(system, device; label = "Varmeter 1", bus = 2, reactive = -0.3)
addVarmeter!(system, device; label = "Varmeter 3", from = 1, reactive = 0.2)

addPmu!(system, device; label = "PMU 1", bus = 1, magnitude = 1.0, angle = 0.0)
addPmu!(system, device; label = "PMU 2", bus = 3, magnitude = 0.9, angle = -0.2)
nothing # hide
```

---

Let the WLS estimator ``\hat {\mathbf x}`` be obtained by solving the AC state estimation:
```@example BadData
analysis = gaussNewton(system, device)
stateEstimation!(system, analysis)
```

---

## [Chi-Squared Test](@id ChiTestTutorials)
Next, we perform the chi-squared test to check for the presence of outliers:
```@example BadData
chi = chiTest(system, device, analysis; confidence = 0.96)
```

At this stage, JuliaGrid uses the objective value obtained from the AC state estimation:
```math
	f(\hat{\mathbf x}) = \sum_{i=1}^k\cfrac{[z_i - h_i(\hat{\mathbf x})]^2}{v_i},
```

This value is stored in the `ChiTest` type as:
```@repl BadData
chi.objective
```

Next, retrieve the value from the Chi-squared distribution corresponding to the detection `confidence` and ``(k - s)`` degrees of freedom, where ``k`` is the number of measurement functions and ``s`` is the number of state variables. This provides the value of ``\chi^2_{p}(k - s)``:
```@repl BadData
chi.treshold
```

Then, the bad data test can be defined as:
```math
	f(\hat{\mathbf x}) \geq \chi^2_{p}(k - s).
```

If the inequality is satisfied, bad data is suspected in the measurement set:
```@repl BadData
chi.detect
```

---

## [Largest Normalized Residual Test](@id ResidualTestTutorials)
As observed from the Chi-squared test, bad data is present in the measurement set. We then perform the largest normalized residual test to identify the outlier and remove it from the measurements:
```@example BadData
outlier = residualTest!(system, device, analysis; threshold = 4.0)

nothing # hide
```

In this step, we employ the largest normalized residual test, guided by the analysis outlined in [aburbook; Sec. 5.7](@cite). To be more precise, we compute all measurement residuals based on the obtained estimate of state variables:
```math
    r_i = z_i - h_i(\hat {\mathbf x}), \;\;\; i \in \mathcal M.
```

The normalized residuals for all measurements are computed as follows:
```math
    \bar{r}_i  = \cfrac{|r_i|}{\sqrt{S_{ii}\Sigma_{ii}}} = \cfrac{|r_i|}{\sqrt{C_{ii}}}, \;\;\; i \in \mathcal M.
```

In this equation, we denote the diagonal entries of the residual covariance matrix ``\mathbf C \in \mathbb{R}^{k \times k}`` as ``C_{ii} = S_{ii}\Sigma_{ii}``, where ``S_{ii}`` is the diagonal entry of the residual sensitivity matrix ``\mathbf S`` representing the sensitivity of the measurement residuals to the measurement errors.

The subsequent step involves selecting the largest normalized residual, and the ``j``-th measurement is then suspected as bad data and potentially removed from the measurement set ``\mathcal{M}``:
```math
    \bar{r}_{j} = \text{max} \{\bar{r}_{i}, \forall i \in \mathcal{M} \}.
```

Users can access this information using the variable:
```@repl BadData
outlier.maxNormalizedResidual
```

If the largest normalized residual, denoted as ``\bar{r}_{j}``, satisfies the inequality:
```math
    \bar{r}_{j} \ge \epsilon,
```
the corresponding measurement is identified as bad data and subsequently removed. In this example, the bad data identification `threshold` is set to ``\epsilon = 4``. Users can verify the satisfaction of this inequality by inspecting:
```@repl BadData
outlier.detect
```

This indicates that the measurement labeled as:
```@repl BadData
outlier.label
```
is removed from the measurement set and marked as out-of-service.

Subsequently, we can solve the system again, but this time without the removed measurement:
```@example BadData
analysis = gaussNewton(system, device)
stateEstimation!(system, analysis)
nothing # hide
```

Following that, we check for outliers once more:
```@example BadData
outlier = residualTest!(system, device, analysis; threshold = 4.0)
nothing # hide
```

To examine the value:
```@repl BadData
outlier.maxNormalizedResidual
```

As this value is now less than the `threshold` ``\epsilon = 4``, the measurement is not removed, or there are no outliers. This can also be verified by observing the bad data flag:
```@repl BadData
outlier.detect
```

---

##### Residual Covariance Matrix
In AC state estimation, the residual covariance matrix ``\mathbf C`` is given by:
```math
    \mathbf C = \mathbf S \bm \Sigma = \bm \Sigma - \mathbf J (\hat {\mathbf x}) [\mathbf J (\hat {\mathbf x})^T \bm \Sigma^{-1} \mathbf J (\hat {\mathbf x})]^{-1} \mathbf J (\hat {\mathbf x})^T,
```
while for DC state estimation and state estimation using only PMUs, it is computed as:
```math
    \mathbf C = \mathbf S \bm \Sigma = \bm \Sigma - \mathbf H [\mathbf H^T \bm \Sigma^{-1} \mathbf H]^{-1} \mathbf H^T.
```

It is important to note that only the diagonal entries of ``\mathbf C`` are required. The main computational challenge lies in computing the inverse on the right-hand side of the equations. The JuliaGrid package employs a computationally efficient sparse inverse method, obtaining only the necessary elements.