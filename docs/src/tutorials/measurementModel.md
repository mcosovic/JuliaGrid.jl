# [Measurement Model](@id MeasurementModelTutorials)
Let us begin by examining a power system. To do that, we will construct one as shown below:
```@example measurementModelTutorials
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 3")

@branch(reactance = 0.03)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2")
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3")
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3")

nothing  # hide
```

Our goal is to monitor the power system, and this process involves collecting measurement data for various electrical quantities distributed throughout the power system.

---

## Power System Monitoring
Measurement data is obtained through two main technologies: SCADA (Supervisory Control and Data Acquisition) and WAMS (Wide Area Measurement System). These technologies enable the collection of a wide range of measurements distributed throughout the power system. This extensive dataset allows us to employ state estimation algorithms to obtain the present state of the power system, in contrast to power flow algorithms, which are typically used for offline analyses. To commence, we will represent the entire set of measurements as ``\mathcal{M}``.

SCADA provides legacy measurements with low sampling rates, making them unsuitable for capturing real-time system dynamics. It provides a snapshot of the power system's state, with delays measured in seconds and minutes. These legacy measurements, which are subsets of the measurement set ``\mathcal{M}``, encompass:
* set of voltmeters ``\mathcal{V}`` measuring bus voltage magnitudes,
* set of ammeters ``\mathcal{I}`` measuring branch current magnitudes,
* set of wattmeters ``\mathcal{P}`` measuring active power of bus injections and branch flows,
* set of varmeters ``\mathcal{Q}`` measuring reactive power of bus injections and branch flows. 

In contrast, WAMS technology employs PMUs (Phasor Measurement Units) to deliver data with high sampling rates, typically ranging between 10 ms and 20 ms. This capability enables real-time monitoring of the system. The inclusion of PMU measurements further extends the measurement set ``\mathcal{M}`` in the following manner:
* set of PMUs ``\bar{\mathcal{P}}`` measuring bus voltage and branch current phasors.
Each phasor measurement is represented by a pair of measurements within the polar coordinate system. To be specific, a PMU's phasor measurement comprises a magnitude, equal to the root mean square value of the signal, and a phase angle [[1, Sec. 5.6]](@ref MeasurementModelReferenceTutorials). Measurement errors are associated with both the magnitude and angle of the phasor. Consequently, PMUs provide phasor measurements in polar coordinates. Additionally, PMU outputs can be observed in rectangular coordinates, encompassing the real and imaginary components of the bus voltage and branch current phasors. However, in this scenario, both measurements may be influenced by correlated measurement errors [[1, Sec. 7.3]](@ref MeasurementModelReferenceTutorials).

The measurement model, as defined by the measurement set ``\mathcal{M}``, can be expressed as a system of equations [[2]](@ref MeasurementModelReferenceTutorials): 
```math
  \mathbf{z}=\mathbf{h}(\mathbf{x})+\mathbf{u},
```
where ``\mathbf {x}=[x_1,\dots,x_{n}]^{T}`` is the vector of the state variables, ``\mathbf{h}(\mathbf{x})=`` ``[h_1(\mathbf{x})``, ``\dots``, ``h_k(\mathbf{x})]^{{T}}`` is the vector of measurement functions, ``\mathbf{z} = [z_1,\dots,z_k]^{\mathrm{T}}`` is the vector of measurement values, and ``\mathbf{u} = [u_1,\dots,u_k]^{\mathrm{T}}`` is the vector of uncorrelated measurement errors. In the context of transmission grids, this model is often an overdetermined system of equations ``(k>s)`` [[3, Sec. 2.1]](@ref MeasurementModelReferenceTutorials). 

Each legacy measurement and each magnitude or angle measurement from PMUs is associated with a measured value ``z_i``, a measurement error ``u_i``, and a measurement function ``h_i(\mathbf{x})``. Assuming that measurement errors ``u_i`` follow a zero-mean Gaussian distribution, the probability density function associated with the ``i``-th measurement is proportional to:
```math
  \mathcal{N}(z_i|\mathbf{x},v_i) \propto \exp\Bigg\{\cfrac{[z_i-h_i(\mathbf{x})]^2}{2v_i}\Bigg\},
```
where ``v_i`` is the measurement variance defined by the measurement error ``u_i``, and the measurement function ``h_i(\mathbf{x})`` connects the vector of state variables ``\mathbf{x}`` to the value of the ``i``-th measurement. 

When defining the system of equations, it is essential to have measurement values represented by ``\mathbf{z}``. In JuliaGrid, users have the option to either directly specify measurement values or artificially generate the vector ``[z_1,\dots,z_k]``. This generation process involves introducing white Gaussian noise with variances ``[v_1, \dots, v_k]`` and adding it to the provided values ``[e_1, \dots, e_k]``, typically representing the exact values of the respective electrical quantities:
```math
  \epsilon_i \sim \mathcal{N}(0,\,v_i) \\[5pt]
  z_i = e_i + \epsilon_i.
```

---

##### Voltmeters
To begin, let us introduce the set of voltmeters ``\mathcal{V} \subset \mathcal{M}`` to measure bus voltage magnitudes:
```@example measurementModelTutorials
addVoltmeter!(system, device; bus = "Bus 1", magnitude = 1.1)
addVoltmeter!(system, device; bus = "Bus 3", magnitude = 1.0)

nothing  # hide
```

The vectors of measurement values ``\mathbf{z}_\mathcal{V}`` and variances ``\mathbf{v}_\mathcal{V}`` are stored in the following variables:
```@repl measurementModelTutorials
𝐳ᵥ = device.voltmeter.magnitude.mean
𝐯ᵥ = device.voltmeter.magnitude.variance
```

---

##### Ammeters
Subsequently, we incorporate the set of ammeters ``\mathcal{I} \subset \mathcal{M}`` to measure branch current magnitudes:
```@example measurementModelTutorials
addAmmeter!(system, device; from = "Branch 1", magnitude = 0.3, noise = false)
addAmmeter!(system, device; to = "Branch 2", magnitude = 0.2, variance = 1e-3)

nothing  # hide
```

The vectors of measurement values ``\mathbf{z}_\mathcal{I}`` and variances ``\mathbf{v}_\mathcal{I}`` are stored in the following variables:
```@repl measurementModelTutorials
𝐳ᵢ = device.ammeter.magnitude.mean
𝐯ᵢ = device.ammeter.magnitude.variance
```

---

##### Wattmeters
Next, should there be a need to measure active power injections at buses and active power flows at branches, users can include the set of wattmeters ``\mathcal{P} \subset \mathcal{M}``:
```@example measurementModelTutorials
addWattmeter!(system, device; bus = "Bus 1", active = 0.1, variance = 1e-4)
addWattmeter!(system, device; to = "Branch 2", active = 0.2, variance = 1e-3)
addWattmeter!(system, device; from = "Branch 3", active = 0.4, variance = 1e-3, noise = false)

nothing  # hide
```

The vectors of measurement values ``\mathbf{z}_\mathcal{P}`` and variances ``\mathbf{v}_\mathcal{P}`` are stored in the following variables:
```@repl measurementModelTutorials
𝐳ₚ = device.wattmeter.active.mean
𝐯ₚ = device.wattmeter.active.variance
```

---

##### Varmeters
In a similar fashion, if there is a need to measure reactive power injections at buses and reactive power flows at branches, users can include the set of varmeters ``\mathcal{Q} \subset \mathcal{M}``:
```@example measurementModelTutorials
addVarmeter!(system, device; bus = "Bus 3", reactive = 0.2, variance = 1e-4)
addVarmeter!(system, device; from = "Branch 2", reactive = 0.03, variance = 1e-3)
addVarmeter!(system, device; to = "Branch 1", reactive = 0.04, variance = 1e-3, noise = false)

nothing  # hide
```

The vectors of measurement values ``\mathbf{z}_\mathcal{Q}`` and variances ``\mathbf{v}_\mathcal{Q}`` are stored in the following variables:
```@repl measurementModelTutorials
𝐳ₒ = device.varmeter.reactive.mean
𝐯ₒ = device.varmeter.reactive.variance
```

---

##### PMUs
The PMUs are responsible for measuring voltage and current phasors in the polar coordinate system, or they can be represented by magnitude and angle with corresponding variances for these two quantities. When PMUs are installed on buses, they measure bus voltage phasors, and when installed on branches, they measure current voltage phasors. This allows us to incorporate a set of PMUs ``\bar{\mathcal{P}} \subset \mathcal{M}``:
```@example measurementModelTutorials
addPmu!(system, device; bus = "Bus 1", magnitude = 1.1, angle = 0.0)
addPmu!(system, device; bus = "Bus 2", magnitude = 1.2, angle = 0.1, varianceMagnitude = 1e-6)
addPmu!(system, device; from = "Branch 2", magnitude = 0.2, angle = 0.2, varianceAngle = 1e-4)
addPmu!(system, device; to = "Branch 3", magnitude = 0.1, angle = -0.3, noise = false)

nothing  # hide
```

The vectors of measurement values ``\mathbf{z}_{\bar{\mathcal{P}}}`` and variances ``\mathbf{v}_{\bar{\mathcal{P}}}`` are stored in the following variables:
```@repl measurementModelTutorials
𝐳ₚ = [device.pmu.magnitude.mean; device.pmu.angle.mean]
𝐯ₚ = [device.pmu.magnitude.variance; device.pmu.angle.variance]
```

---

## State Estimation
After establishing the measurement model, which includes specifying measurement values, variances, the locations of measurement devices, and known power system network parameters, the subsequent step involves the process of state estimation. State estimation is a component of energy management systems and typically encompasses network topology processing, observability analysis, state estimation algorithms, and bad data analysis.

The primary goal of state estimation algorithms is to determine state variables, often associated with bus voltages. Therefore, by representing the vector of state variables as ``\mathbf{x}`` and the vector of noisy measurement values as ``\mathbf{z}``, we can effectively describe the state estimation problem using the following conditional probability equation: 
```math
 		p(\mathbf{x}|\mathbf{z})= \cfrac{p(\mathbf{z}|\mathbf{x})p(\mathbf{x})}{p(\mathbf{z})}.
```

If we assume that the prior probability distribution ``p(\mathbf{x})`` is uniform and that ``p(\mathbf{z})`` does not depend on ``\mathbf{x}``, the maximum a posteriori solution simplifies to the maximum likelihood solution, as shown below [[4]](@ref MeasurementModelReferenceTutorials):
```math
	\hat{\mathbf{x}} = \mathrm{arg}\max_{\mathbf{x}}p(\mathbf{x}|\mathbf{z}) =
	\mathrm{arg}\max_{\mathbf{x}}p(\mathbf{z}|\mathbf{x}) = \mathrm{arg}\max_{\mathbf{x}}\mathcal{L}(\mathbf{z}|\mathbf{x}).
```

We can find this solution by maximizing the likelihood function ``\mathcal{L}(\mathbf{z}|\mathbf{x})``, which is defined based on the likelihoods of ``k`` independent measurements:
```math
	\hat{\mathbf x} = \mathrm{arg} \max_{\mathbf{x}}\mathcal{L}(\mathbf{z}|\mathbf{x})=
	\mathrm{arg} \max_{\mathbf{x}} \prod_{i=1}^k \mathcal{N}(z_i|\mathbf{x},v_i).
```

It can be demonstrated that the solution to the maximum a posteriori problem can be obtained by solving the following optimization problem, commonly referred to as the weighted least-squares problem [[6, Sec. 9.3]](@ref MeasurementModelReferenceTutorials):
```math
	\hat{\mathbf x} = \mathrm{arg}\min_{\mathbf{x}} \sum_{i=1}^k\cfrac{[z_i-h_i(\mathbf x)]^2}{v_i}.
```
The state estimate, denoted as ``\hat{\mathbf x}``, resulting from the solution to the above optimization problem, is known as the weighted least-squares estimator. Both the maximum likelihood and weighted least-squares estimators are equivalent to the maximum a posteriori solution [[4, Sec. 8.6]](@ref MeasurementModelReferenceTutorials).

---

## [References](@id MeasurementModelReferenceTutorials)
[1] A. G. Phadke and J. S. Thorp, *Synchronized phasor measurements and their applications*, Springer, 2008, vol. 1.

[2] F. C. Schweppe and D. B. Rom, "Power system static-state estimation, part II: Approximate model," *IEEE Trans. Power Syst.*, vol. PAS-89, no. 1, pp. 125-130, Jan. 1970.

[3] A. Monticelli, *State Estimation in Electric Power Systems: A Generalized Approach*, ser. Kluwer international series in engineering and computer science. Springer US, 1999.

[4] D. Barber, *Bayesian Reasoning and Machine Learning*, Cambridge University Press, 2012.

[5] A. Wood and B. Wollenberg, *Power Generation, Operation, and Control*, ser. A Wiley-Interscience publication. Wiley, 1996.

[6] A. Wood and B. Wollenberg, *Power Generation, Operation, and Control*, ser. A Wiley-Interscience publication. Wiley, 1996.