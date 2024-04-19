# [Measurement Model](@id MeasurementModelTutorials)
Let us begin by examining a power system. To do that, we will construct one as shown below:
```@example measurementModelTutorials
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
device = measurement()

addBus!(system; label = 1)
addBus!(system; label = 2)
addBus!(system; label = 3)

@branch(reactance = 0.03)
addBranch!(system; label = 1, from = 1, to = 2)
addBranch!(system; label = 2, from = 1, to = 3)
addBranch!(system; label = 3, from = 2, to = 3)

nothing  # hide
```

To review, we can conceptualize the bus/branch model as the graph denoted by ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where we have the set of buses ``\mathcal{N} = \{1, \dots, n\}``, and the set of branches ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` within the power system:
```@repl measurementModelTutorials
𝒩 = collect(keys(system.bus.label))
ℰ = [𝒩[system.branch.layout.from] 𝒩[system.branch.layout.to]]
```

Our goal is to monitor the power system, and this process involves collecting measurement data for various electrical quantities distributed throughout the power system.

---

## Power System Monitoring
Measurement data is obtained through two main technologies: SCADA (Supervisory Control and Data Acquisition) and WAMS (Wide Area Measurement System). These technologies enable the collection of a wide range of measurements distributed throughout the power system. This extensive dataset allows us to employ state estimation algorithms to obtain the present state of the power system, in contrast to power flow algorithms, which are typically used for offline analyses. To commence, we will represent the entire set of measurement devices as ``\mathcal{M}``.

SCADA provides legacy measurements with low sampling rates, making them unsuitable for capturing real-time system dynamics. It provides a snapshot of the power system's state, with delays measured in seconds and minutes. These legacy measurement devices, subsets of the set ``\mathcal{M}``, include:
* a set of voltmeters ``\mathcal{V}`` for measuring bus voltage magnitudes,
* a set of ammeters ``\mathcal{I}`` for measuring branch current magnitudes,
* a set of wattmeters ``\mathcal{P}`` for active power injection and flow measurements,
* a set of varmeters ``\mathcal{Q}`` for reactive power injection and flow measurements.

In contrast, WAMS technology utilizes PMUs (Phasor Measurement Units) to provide data with high sampling rates, typically ranging between 10 ms and 20 ms, facilitating real-time monitoring of the system. Therefore, PMUs expand the set ``\mathcal{M}`` as follows:
* a set of PMUs ``\bar{\mathcal{P}}`` for bus voltage and branch current phasor measurements.

---

!!! ukw "Notation"
    In this section, when referring to a vector ``\mathbf{a}``, we use the notation ``\mathbf{a} = [a_{i}]``, where ``a_i`` represents the element associated measurement ``i \in \mathcal{M}``.


---

##### Measurement Model
The measurement model, as defined by the set ``\mathcal{M}``, can be expressed as a system of equations [[1]](@ref MeasurementModelReferenceTutorials):
```math
    \mathbf{z}=\mathbf{h}(\mathbf {x}) + \mathbf{u},
```
where ``\mathbf {x}=[x_1,\dots,x_{n}]^{T}`` is the vector of the state variables, ``\mathbf{h}(\mathbf{x})=`` ``[h_1(\mathbf{x})``, ``\dots``, ``h_k(\mathbf{x})]^{{T}}`` is the vector of measurement functions, ``\mathbf{z} = [z_1,\dots,z_k]^{\mathrm{T}}`` is the vector of measurement values, and ``\mathbf{u} = [u_1,\dots,u_k]^{\mathrm{T}}`` is the vector of measurement errors. In the context of transmission grids, this model is often an overdetermined system of equations ``(k>s)`` [[2, Sec. 2.1]](@ref MeasurementModelReferenceTutorials).

These errors are assumed to follow a Gaussian distribution with a zero-mean and covariance matrix ``\bm \Sigma``. The diagonal elements of ``\bm \Sigma`` correspond to the measurement variances ``\mathbf{v} = [v_1,\dots,v_k]^T``, while the off-diagonal elements represent the covariances between the measurement errors ``\mathbf{w} = [w_1,\dots,w_k]^{T}``. These covariances exist only if PMUs are observed in rectangular coordinates and correlation is required.

---

##### Gaussian Probability Density Function
Each legacy measurement and each magnitude or angle measurement from PMUs is associated with a measured value ``z_i``, a measurement error ``u_i``, and a measurement function ``h_i(\mathbf{x})``. Assuming that measurement errors ``u_i`` follow a zero-mean Gaussian distribution, the probability density function associated with the ``i``-th measurement is proportional to:
```math
  \mathcal{N}(z_i|\mathbf{x},v_i) \propto \exp\Bigg\{\cfrac{[z_i-h_i(\mathbf{x})]^2}{2v_i}\Bigg\},
```
where ``v_i`` is the measurement variance defined by the measurement error ``u_i``, and the measurement function ``h_i(\mathbf{x})`` connects the vector of state variables ``\mathbf{x}`` to the value of the ``i``-th measurement.

---

##### Artificial Generation of Measurement Values
When defining the system of equations, it is essential to have measurement values represented by ``\mathbf{z}``. In JuliaGrid, users have the option to either directly specify measurement values or artificially generate the vector ``[z_1,\dots,z_k]``. This generation process involves introducing white Gaussian noise with variances ``[v_1, \dots, v_k]`` and adding it to the provided values ``[e_1, \dots, e_k]``, typically representing the exact values of the respective electrical quantities:
```math
  \epsilon_i \sim \mathcal{N}(0,\,v_i) \\[5pt]
  z_i = e_i + \epsilon_i.
```

---

## Voltmeters
A voltmeter ``V_i \in \mathcal{V}`` measures the bus voltage magnitude at bus ``i \in \mathcal{N}``. Let us introduce two voltmeters that measure voltage magnitudes at the first and third bus. For the first voltmeter, we artificially generate the measurement value, while for the second voltmeter, we exactly pass the measurement value:
```@example measurementModelTutorials
addVoltmeter!(system, device; label = "V₁", bus = 1, magnitude = 1.1)
addVoltmeter!(system, device; label = "V₃", bus = 3, magnitude = 1.0, noise = false)

nothing  # hide
```

Consequently, we establish the set of voltmeters ``\mathcal{V} \subset \mathcal{M}``:
```@repl measurementModelTutorials
𝒱 = collect(keys(device.voltmeter.label))
```

This set of voltmeters defines vectors of measurement values denoted as ``\mathbf{z}_\mathcal{V} = [z_i]`` and variances denoted as ``\mathbf{v}_\mathcal{V} = [v_i]``, where ``i \in \mathcal{V}``, and can be accessed through the following variables:
```@repl measurementModelTutorials
𝐳ᵥ = device.voltmeter.magnitude.mean
𝐯ᵥ = device.voltmeter.magnitude.variance
```

---

## Ammeters
An ammeter ``I_{ij} \in \mathcal{I}`` measures the magnitude of branch current at the from-bus end of the branch ``(i,j) \in \mathcal{E}``. Let us add this type of ammeter at the first branch between buses 1 and 2:
```@example measurementModelTutorials
addAmmeter!(system, device; label = "I₁₂", from = 1, magnitude = 0.3, variance = 1e-3)

nothing  # hide
```

Additionally, an ammeter can also measure the branch current magnitude at the to-bus end of the branch ``(i,j) \in \mathcal{E}``, denoted as ``I_{ji} \in \mathcal{I}``. For example, we can include this type of ammeter at the same branch:
```@example measurementModelTutorials
addAmmeter!(system, device; label = "I₂₁", to = 1, magnitude = 0.2, variance = 1e-3)

nothing  # hide
```

Consequently, we establish the set of ammeters ``\mathcal{I} \subset \mathcal{M}``:
```@repl measurementModelTutorials
ℐ = collect(keys(device.ammeter.label))
```

This set of ammeters defines vectors of measurement values denoted as ``\mathbf{z}_\mathcal{I} = [z_i]`` and variances denoted as ``\mathbf{v}_\mathcal{I} = [v_i]``, where ``i \in \mathcal{I}``, and can be accessed through the following variables:
```@repl measurementModelTutorials
𝐳ₒ = device.ammeter.magnitude.mean
𝐯ₒ = device.ammeter.magnitude.variance
```

---

## Wattmeters
A wattmeter ``P_{i} \in \mathcal{P}`` measures the active power injection at bus ``i \in \mathcal{N}``. Hence, let us add it to the second bus:
```@example measurementModelTutorials
addWattmeter!(system, device; label = "P₂", bus = 2, active = 0.1, variance = 1e-4)

nothing  # hide
```

Next, a wattmeter denoted as ``P_{ij} \in \mathcal{P}`` measures the active power flow at the from-bus end of the branch ``(i,j) \in \mathcal{E}``. Let us add this type of wattmeter at the second branch:
```@example measurementModelTutorials
addWattmeter!(system, device; label = "P₁₃", from = 2, active = 0.2, variance = 1e-3)

nothing  # hide
```

Moreover, a wattmeter can also measure the active power flow at the to-bus end of the branch ``(i,j) \in \mathcal{E}``, denoted as ``P_{ji} \in \mathcal{P}``. For example, we can include this type of wattmeter at the same branch:
```@example measurementModelTutorials
addWattmeter!(system, device; label = "P₃₁", to = 2, active = 0.3, variance = 1e-3)

nothing  # hide
```

Consequently, we establish the set of wattmeters ``\mathcal{P} \subset \mathcal{M}``:
```@repl measurementModelTutorials
𝒫 = collect(keys(device.wattmeter.label))
```

This set of wattmeters defines vectors of measurement values denoted as ``\mathbf{z}_\mathcal{P} = [z_i]`` and variances denoted as ``\mathbf{v}_\mathcal{P} = [v_i]``, where ``i \in \mathcal{P}``, and can be accessed through the following variables:
```@repl measurementModelTutorials
𝐳ₚ = device.wattmeter.active.mean
𝐯ₚ = device.wattmeter.active.variance
```

---

## Varmeters
A varmeter ``Q_{i} \in \mathcal{Q}`` measures the reactive power injection at bus ``i \in \mathcal{N}``. Hence, let us add it to the first bus:
```@example measurementModelTutorials
addVarmeter!(system, device; label = "Q₁", bus = 1, reactive = 0.01, variance = 1e-2)

nothing  # hide
```

Next, a varmeter denoted as ``Q_{ij} \in \mathcal{Q}`` measures the reactive power flow at the from-bus end of the branch ``(i,j) \in \mathcal{E}``. Let us add this type of varmeter at the first branch:
```@example measurementModelTutorials
addVarmeter!(system, device; label = "Q₁₂", from = 1, reactive = 0.02, variance = 1e-3)

nothing  # hide
```

Moreover, a varmeter can also measure the reactive power flow at the to-bus end of the branch ``(i,j) \in \mathcal{E}``, denoted as ``Q_{ji} \in \mathcal{Q}``. For example, we can include this type of varmeter at the same branch:
```@example measurementModelTutorials
addVarmeter!(system, device; label = "Q₂₁", to = 1, reactive = 0.03, noise = false)

nothing  # hide
```

Consequently, we establish the set of varmeters ``\mathcal{Q} \subset \mathcal{M}``:
```@repl measurementModelTutorials
𝒬 = collect(keys(device.varmeter.label))
```

This set of varmeters defines vectors of measurement values denoted as ``\mathbf{z}_\mathcal{Q} = [z_i]`` and variances denoted as ``\mathbf{v}_\mathcal{Q} = [v_i]``, where ``i \in \mathcal{Q}``, and can be accessed through the following variables:
```@repl measurementModelTutorials
𝐳ₒ = device.varmeter.reactive.mean
𝐯ₒ = device.varmeter.reactive.variance
```

---

## PMUs
PMUs measure voltage and current phasors in the polar coordinate system, thus each PMU output represented by magnitude and angle along with corresponding variances [[3, Sec. 5.6]](@ref MeasurementModelReferenceTutorials). When installed on buses, they measure bus voltage phasors, while on branches, they measure current phasors.

A PMU ``(V_i, \theta_i) \in \bar{\mathcal{P}}`` measures the voltage phasor at bus ``i \in \mathcal{N}``. Let us integrate this type of PMU at the first bus:
```@example measurementModelTutorials
addPmu!(system, device; label = "V₁, θ₁", bus = 1, magnitude = 1, angle = 0, noise = false)

nothing  # hide
```

Next, a PMU ``(I_{ij}, \psi_{ij}) \in \bar{\mathcal{P}}`` measures the branch current magnitude at the from-bus end of the branch ``(i,j) \in \mathcal{E}``. Let us add this type of PMU at the first branch:
```@example measurementModelTutorials
addPmu!(system, device; label = "I₁₂, ψ₁₂", from = 1, magnitude = 0.2, angle = -0.1)

nothing  # hide
```

Moreover, a PMU can measure the branch current magnitude at the to-bus end of the branch ``(i,j) \in \mathcal{E}``, denoted as ``(I_{ji}, \psi_{ji}) \in \bar{\mathcal{P}}``. For example, let us include this type of PMU at the same branch:
```@example measurementModelTutorials
addPmu!(system, device; label = "I₂₁, ψ₂₁", to = 1, magnitude = 0.3, angle = -0.2)

nothing  # hide
```

Consequently, we establish the set of PMUs ``\bar{\mathcal{P}} \subset \mathcal{M}``:
```@repl measurementModelTutorials
𝒫̄ = collect(keys(device.pmu.label))
```


This set of PMUs establishes vectors representing measurement magnitudes and angles ``\mathbf{z}_{\bar{\mathcal{P}}} = [z_i, z_j]``, along with their corresponding variances ``\mathbf{v}_{\bar{\mathcal{P}}} = [v_i, v_j]``, where ``(i, j) \in \bar{\mathcal{P}}``. These values can be accessed as:
```@repl measurementModelTutorials
pmu = device.pmu;

𝐳ₚ = collect(Iterators.flatten(zip(pmu.magnitude.mean, pmu.angle.mean)))
𝐯ₚ = collect(Iterators.flatten(zip(pmu.magnitude.variance, pmu.angle.variance)))
```

!!! note "Info"
	PMUs can be handled in state estimation algorithms according to our definition in polar coordinate systems. However, they can also be processed in rectangular coordinates, where we observe the real and imaginary parts of the phasor measurements rather than magnitude and angle. Further details can be found in tutorials that describe specific state estimation analyses.

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

It can be demonstrated that the solution to the maximum a posteriori problem can be obtained by solving the following optimization problem, commonly referred to as the weighted least-squares problem [[5, Sec. 9.3]](@ref MeasurementModelReferenceTutorials):
```math
	\hat{\mathbf x} = \mathrm{arg}\min_{\mathbf{x}} \sum_{i=1}^k\cfrac{[z_i-h_i(\mathbf x)]^2}{v_i}.
```
The state estimate, denoted as ``\hat{\mathbf x}``, resulting from the solution to the above optimization problem, is known as the weighted least-squares estimator. Both the maximum likelihood and weighted least-squares estimators are equivalent to the maximum a posteriori solution [[4, Sec. 8.6]](@ref MeasurementModelReferenceTutorials).

---


## [References](@id MeasurementModelReferenceTutorials)
[1] F. C. Schweppe and D. B. Rom, "Power system static-state estimation, part II: Approximate model," *IEEE Trans. Power Syst.*, vol. PAS-89, no. 1, pp. 125-130, Jan. 1970.

[2] A. Monticelli, *State Estimation in Electric Power Systems: A Generalized Approach*, ser. Kluwer international series in engineering and computer science. Springer US, 1999.

[3] A. G. Phadke and J. S. Thorp, *Synchronized phasor measurements and their applications*, Springer, 2008, vol. 1.

[4] D. Barber, *Bayesian Reasoning and Machine Learning*, Cambridge University Press, 2012.

[5] A. Wood and B. Wollenberg, *Power Generation, Operation, and Control*, Wiley, 1996.

