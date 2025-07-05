# [AC State Estimation](@id ACStateEstimationManual)
To perform nonlinear or AC state estimation, the initial requirement is to have the `PowerSystem` type configured with the AC model, along with the `Measurement` type storing measurement data. Next, we can develop either the weighted least-squares (WLS) model, utilizing the Gauss-Newton method, or the least absolute value (LAV) model. These models are encapsulated within the `AcStateEstimation` type:
* [`gaussNewton`](@ref gaussNewton),
* [`acLavStateEstimation`](@ref acLavStateEstimation).

---

To obtain bus voltages and solve the state estimation problem, users need to implement the Gauss-Newton iterative process for the WLS model using:
* [`increment!`](@ref increment!),
* [`solve!`](@ref solve!(::AcStateEstimation{GaussNewton{T}}) where T <: WlsMethod).

Alternatively, to obtain the LAV estimator, simply execute the second function.

After solving the AC state estimation, JuliaGrid provides functions for computing powers and currents:
* [`power!`](@ref power!(::AcPowerFlow)),
* [`current!`](@ref current!(::AC)).

Alternatively, instead of designing their own iteration process for the Gauss-Newton method or using the function responsible for solving the LAV model, and computing powers and currents, users can use the wrapper function:
* [`stateEstimation!`](@ref stateEstimation!(::AcStateEstimation{GaussNewton{T}}) where T <: WlsMethod).

Users can also access specialized functions for computing specific types of [powers](@ref ACPowerAnalysisAPI) or [currents](@ref ACCurrentAnalysisAPI) for individual buses, branches, or generators within the power system.

---

## Setup Initial Voltages
Let us create the `PowerSystem` and `Measurement` type:
```@example ACSEWLS
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1", type = 3, magnitude = 1.1, angle = 0.0)
addBus!(system; label = "Bus 2", type = 1, magnitude = 1.2, angle = -0.1, active = 0.6)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 1.2)

addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 1.0)
addVoltmeter!(monitoring; bus = "Bus 2", magnitude = 0.9)

addWattmeter!(monitoring; from = "Branch 1", active = 0.6)
nothing # hide
```

Next, we can instantiate the weighted least-squares or least absolute value state estimation models. Let us choose the weighted least-squares model for this example:
```@example ACSEWLS
analysis = gaussNewton(monitoring)
nothing # hide
```

The initial voltage values for each model are derived from the voltage magnitudes and angles defined in the `PowerSystem` type:
```@repl ACSEWLS
print(system.bus.label, system.bus.voltage.magnitude, system.bus.voltage.angle)
nothing # hide
```

These values are passed to the `AcStateEstimation` object during the execution of the [`gaussNewton`](@ref gaussNewton) or [`acLavStateEstimation`](@ref acLavStateEstimation) function. Thus, the initial voltages are:
```@repl ACSEWLS
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

---

##### Custom Initial Voltages
Users may adjust the initial voltages according to their needs. One practical approach is to perform an AC power flow analysis and then apply the resulting solution as the starting point for state estimation:
```@example ACSEWLS
pf = newtonRaphson(system)
powerFlow!(pf)

setInitialPoint!(analysis, pf)
nothing # hide
```

This approach enables the state estimation process to start from a realistic operating condition, based on the power flow solution.

---

## [Weighted Least-Squares Estimator](@id ACLSStateEstimationSolutionManual)
To begin, we will define the `PowerSystem` and `Measurement` types:
```@example ACSEWLS
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 3")

@branch(resistance = 0.14, conductance = 1e-4, susceptance = 0.04)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.25)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.35)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.16)

@voltmeter(label = "Voltmeter ? (!)")
addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 1.0, variance = 1e-5)

@ammeter(label = "Ammeter ? (!)")
addAmmeter!(monitoring; from = "Branch 3", magnitude = 0.0356, variance = 1e-3)
addAmmeter!(monitoring; to = "Branch 2", magnitude = 0.5892, variance = 1e-3)

@wattmeter(label = "Wattmeter ? (!)")
addWattmeter!(monitoring; from = "Branch 1", active = 0.7067, variance = 1e-4)
addWattmeter!(monitoring; bus = "Bus 2", active = -0.6, variance = 2e-4)

@varmeter(label = "Varmeter ? (!)")
addVarmeter!(monitoring; from = "Branch 1", reactive = 0.2125, variance = 1e-4)
addVarmeter!(monitoring; bus = "Bus 2", reactive = -0.1, variance = 1e-5)
nothing # hide
```

Next, to establish the AC state estimation model, we will utilize the [`gaussNewton`](@ref gaussNewton) function:
```@example ACSEWLS
analysis = gaussNewton(monitoring)
nothing # hide
```

!!! tip "Tip"
    Here, the user triggers LU factorization as the default method for solving the system of linear equations within each iteration of the Gauss-Newton method. However, the user also has the option to select alternative factorization methods such as `KLU`, `LDLt` or `QR`:
    ```julia ACSEObservabilityAnalysis
    analysis = gaussNewton(monitoring, LDLt)
    ```

To conduct an iterative process using the Gauss-Newton method, it is essential to include the [`increment!`](@ref increment!) and [`solve!`](@ref solve!(::AcStateEstimation{GaussNewton{T}}) where T <: WlsMethod) functions inside the iteration loop. For example:
```@example ACSEWLS
for iteration = 1:20
    increment!(analysis)
    solve!(analysis)
end
nothing # hide
```

Once the state estimator is obtained, users can access the bus voltage magnitudes and angles using:
```@repl ACSEWLS
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

---

##### Breaking the Iterative Process
The iterative process can be terminated using the [`increment!`](@ref increment!) function. The following code demonstrates how to utilize this function to break out of the iteration loop:
```@example ACSEWLS
analysis = gaussNewton(monitoring)
for iteration = 1:20
    stopping = increment!(analysis)
    if stopping < 1e-8
        println("Solution found in $(analysis.method.iteration) iterations.")
        break
    end
    solve!(analysis)
end
nothing # hide
```
The [`increment!`](@ref increment!) function returns the maximum absolute values of the state variable increment, which are commonly used as a convergence criterion in the iterative Gauss-Newton algorithm.

!!! note "Info"
    Readers can refer to the [AC State Estimation](@ref ACStateEstimationTutorials) tutorial for implementation insights.

---

##### Wrapper Function
JuliaGrid provides a wrapper function for AC state estimation analysis that manages the iterative solution process and also supports the computation of powers and currents using the [`stateEstimation!`](@ref stateEstimation!) function. Hence, it offers a way to solve AC state estimation with reduced implementation effort:
```@example ACSEWLS
setInitialPoint!(analysis) # hide
analysis = gaussNewton(monitoring)
stateEstimation!(analysis; verbose = 3)
nothing # hide
```

!!! note "Info"
    Users can choose any approach in this section to obtain the WLS estimator based on their needs. Additionally, users can review the [Gauss-Newton Algorithm](@ref GaussNewtonAlgorithmTutorials) used in the wrapper function within the tutorial section.

---

##### Inclusion of PMUs in Rectangular Coordinates
In the example above, our focus is solely on solving the AC state estimation using SCADA measurements. However, users have the option to also integrate PMUs into the AC state estimation, either in the rectangular or polar coordinate system.

The default approach is to include PMUs in the rectangular coordinate system:
```@example ACSEWLS
@pmu(label = "PMU ? (!)")
addPmu!(monitoring; to = "Branch 1", magnitude = 0.7466, angle = 2.8011)
nothing # hide
```

In the case of the rectangular system, inclusion resolves ill-conditioned problems arising in polar coordinates due to small values of current magnitudes. However, this approach's main disadvantage is related to measurement errors, as measurement errors correspond to polar coordinates. Therefore, the covariance matrix must be transformed from polar to rectangular coordinates [zhou2006alternative](@cite). As a result, measurement errors of a single PMU are correlated, and the covariance matrix does not have a diagonal form. Despite that, the measurement error covariance matrix is usually considered as a diagonal matrix, affecting the accuracy of the state estimation.

In the example above, we specifically include PMUs where measurement error correlations are disregarded. This is evident through the precision matrix, which maintains a diagonal form:
```@repl ACSEWLS
analysis = gaussNewton(monitoring);
analysis.method.precision
```

Lastly, we incorporate correlation into our model by adding a new PMU with the desired error correlation:
```@example ACSEWLS
addPmu!(monitoring; bus = "Bus 3", magnitude = 0.846, angle = -0.1712, correlated = true)
nothing # hide
```

Now, we can observe the precision matrix that does not hold a diagonal form:
```@repl ACSEWLS
analysis = gaussNewton(monitoring);
analysis.method.precision
```

---

##### Inclusion of PMUs in Polar Coordinates
The second approach involves incorporating these measurements into the polar coordinate system. For instance:
```@example ACSEWLS
addPmu!(monitoring; from = "Branch 1", magnitude = 0.7379, angle = -0.2921, polar = true)
nothing # hide
```

This inclusion of PMUs provides more accurate state estimates compared to rectangular inclusion, but demands longer computing time. PMUs are handled in the same manner as SCADA measurements. However, this approach is susceptible to ill-conditioned problems arising in polar coordinates due to small values of current magnitudes [korres2012state, zhou2006alternative](@cite).

!!! tip "Tip"
    It is important to note that with each individual phasor measurement, we can set the coordinate system, providing flexibility to include some in polar and some in rectangular systems. This flexibility is particularly valuable because bus voltage phasor measurements are preferably included in a polar coordinate system, while current phasor measurements are best suited to a rectangular coordinate system.

---

##### Print Results in the REPL
Users have the option to print the results in the REPL using any units that have been configured, such as:
```@example ACSEWLS
@voltage(pu, deg)
printBusData(analysis)
@default(unit) # hide
```

Next, users can easily customize the print results for specific buses, for example:
```julia
printBusData(analysis; label = "Bus 1", header = true)
printBusData(analysis; label = "Bus 2")
printBusData(analysis; label = "Bus 3", footer = true)
```

---

##### Save Results to a File
Users can also redirect print output to a file. For example, data can be saved in a text file as follows:
```julia
open("bus.txt", "w") do file
    printBusData(analysis, file)
end
```

!!! tip "Tip"
    We also provide functions to print or save state estimation results, such as estimated values and residuals. For more details, users can consult the [Power and Current Analysis](@ref ACSEPowerCurrentAnalysisManual) section of this manual.

---

## Alternative Formulations
The resolution of the WLS state estimation problem using the conventional method typically progresses smoothly. However, it is widely acknowledged that in certain situations common to real-world systems, this method can be vulnerable to numerical instabilities. Such conditions might impede the algorithm from finding a satisfactory solution. In such scenarios, users may choose to apply an alternative formulation of the WLS estimator.

These alternative methods are applicable when measurement errors are uncorrelated and the precision matrix is diagonal. Therefore, as a preliminary step, we need to eliminate the correlation, as we did previously:
```@example ACSEWLS
updatePmu!(monitoring; label = "PMU 2 (Bus 3)", correlated = false)
nothing # hide
```

!!! note "Info"
    Readers can refer to the [Alternative Formulation](@ref ACAlternativeFormulationTutorials) tutorial for implementation insights.

---

##### Orthogonal Method
One alternative is the orthogonal method [aburbook; Sec. 3.2](@cite), which provides increased numerical robustness, especially with widely varying measurement variances. It solves the WLS problem using QR factorisation on a rectangular matrix formed by multiplying the square root of the precision matrix with the Jacobian in each Gauss-Newton iteration. Enable it by passing the `Orthogonal` argument to the [`gaussNewton`](@ref gaussNewton) function:
```@example ACSEWLS
analysis = gaussNewton(monitoring, Orthogonal)
stateEstimation!(analysis)
nothing # hide
```

---

##### Peters and Wilkinson Method
Another option is the Peters and Wilkinson method [aburbook; Sec. 3.4](@cite), which uses LU factorisation on the same rectangular matrix built from the square root of the precision matrix and the Jacobian in each Gauss-Newton iteration. It can be selected by passing the `PetersWilkinson` argument to the [`gaussNewton`](@ref gaussNewton) function:
```@example ACSEWLS
analysis = gaussNewton(monitoring, PetersWilkinson)
stateEstimation!(analysis)
nothing # hide
```

---

## [Least Absolute Value Estimator](@id PMULAVtateEstimationSolutionManual)
The LAV method presents an alternative estimation technique known for its increased robustness compared to WLS. While the WLS method relies on specific assumptions regarding measurement errors, robust estimators like LAV are designed to maintain unbiasedness even in the presence of various types of measurement errors and outliers. This characteristic often eliminates the need for extensive bad data analysis procedures [aburbook; Ch. 6](@cite). However, it is important to note that achieving robustness typically involves increased computational complexity.

To obtain an LAV estimator, users need to employ one of the [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) listed in the JuMP documentation. In many common scenarios, the `Ipopt` solver proves sufficient to obtain a solution:
```@example ACSEWLS
using Ipopt
using JuMP  # hide

analysis = acLavStateEstimation(monitoring, Ipopt.Optimizer)
nothing # hide
```

To solve the formulated LAV state estimation model, simply execute the following function:
```@example ACSEWLS
stateEstimation!(analysis)
nothing # hide
```

Upon obtaining the solution, access the bus voltage magnitudes and angles using:
```@repl ACSEWLS
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
nothing # hide
```

!!! note "Info"
    Readers can refer to the [Least Absolute Value Estimation](@ref ACLAVTutorials) tutorial for implementation insights.

---

## [Measurement Set Update](@id ACMeasurementsAlterationManual)
We begin by creating the `PowerSystem` and `Measurement` types with the [`ems`](@ref ems) function. The AC model is then configured using [`acModel!`](@ref acModel!) function. After that, we initialize the `AcStateEstimation` type through the [`gaussNewton`](@ref gaussNewton) function and solve the resulting state estimation problem:
```@example WLSACStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2")

@branch(resistance = 0.1, susceptance = 0.02)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.25)

acModel!(system)

addWattmeter!(monitoring; label = "Wattmeter 1", from = "Branch 1", active = 0.6)
addWattmeter!(monitoring; label = "Wattmeter 2", bus = "Bus 2", active = -0.6)

addVarmeter!(monitoring; label = "Varmeter 1", from = "Branch 1", reactive = 0.2)
addVarmeter!(monitoring; label = "Varmeter 2", bus = "Bus 2", reactive = -0.1)

analysis = gaussNewton(monitoring)
stateEstimation!(analysis)
nothing # hide
```

Next, we modify the existing `Measurement` type using add and update functions. Then, we create the new `AcStateEstimation` type based on the modified system and solve the state estimation problem:
```@example WLSACStateEstimationSolution
addWattmeter!(monitoring; label = "Wattmeter 3", to = "Branch 1", active = -0.7)
updateWattmeter!(monitoring; label = "Wattmeter 2", status = 0)

addVarmeter!(monitoring; label = "Varmeter 3", to = "Branch 1", reactive = -0.1)
updateVarmeter!(monitoring; label = "Varmeter 2", variance = 1e-2)

analysis = gaussNewton(monitoring)
stateEstimation!(analysis)
nothing # hide
```

!!! note "Info"
    This concept removes the need to restart and recreate the `Measurement` type from the beginning when implementing changes to the existing measurement set.

---

## [State Estimation Update](@id ACStateEstimationUpdateManual)
An advanced methodology involves users establishing the `AcStateEstimation` type using [`gaussNewton`](@ref gaussNewton) or [`acLavStateEstimation`](@ref acLavStateEstimation) just once. After this initial setup, users can seamlessly modify existing measurement devices without the need to recreate the `AcStateEstimation` type.

This advancement extends beyond the previous scenario where recreating the `Measurement` type was unnecessary, to now include the scenario where `AcStateEstimation` also does not need to be recreated.

!!! tip "Tip"
    The addition of new measurements after the creation of `AcStateEstimation` is not practical in terms of reusing this type. Instead, we recommend that users create a final set of measurements and then utilize update functions to manage devices, either putting them in-service or out-of-service throughout the process.

Let us now revisit our defined `PowerSystem`, `Measurement` and `AcStateEstimation` types:
```@example WLSACStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2")

@branch(resistance = 0.1, susceptance = 0.02)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.25)

acModel!(system)

addWattmeter!(monitoring; label = "Wattmeter 1", from = "Branch 1", active = 0.6)
addWattmeter!(monitoring; label = "Wattmeter 2", bus = "Bus 2", active = -0.6)
addWattmeter!(monitoring; label = "Wattmeter 3", to = "Branch 1", active = -0.7, status = 0)

addVarmeter!(monitoring; label = "Varmeter 1", from = "Branch 1", reactive = 0.2)
addVarmeter!(monitoring; label = "Varmeter 2", bus = "Bus 2", reactive = -0.1)
addVarmeter!(monitoring; label = "Varmeter 3", to = "Branch 1", reactive = -0.1, status = 0)

analysis = gaussNewton(monitoring)
stateEstimation!(analysis)
nothing # hide
```

Next, we modify the existing `Measurement` type as well as the `AcStateEstimation` type using add and update functions. We then immediately proceed to solve the state estimation problem:
```@example WLSACStateEstimationSolution
updateWattmeter!(analysis; label = "Wattmeter 3", status = 1)
updateWattmeter!(analysis; label = "Wattmeter 2", status = 0)

updateVarmeter!(analysis; label = "Varmeter 3", status = 0)
updateVarmeter!(analysis; label = "Varmeter 2", variance = 1e-2)

stateEstimation!(analysis)
nothing # hide
```

!!! note "Info"
    This concept removes the need to rebuild both the `Measurement` and the `AcStateEstimation` from the beginning when implementing changes to the existing measurement set. In the scenario of employing the WLS model, JuliaGrid can reuse the symbolic factorizations of LU or LDLt, provided that the nonzero pattern of the gain matrix remains unchanged.

---

## [Power and Current Analysis](@id ACSEPowerCurrentAnalysisManual)
After obtaining the solution from the AC state estimation, we can calculate various electrical quantities related to buses and branches using the [`power!`](@ref power!(::AcPowerFlow)) and [`current!`](@ref current!(::AC)) functions. For instance, let us consider the model for which we obtained the AC state estimation solution:
```@example WLSACStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1", type = 3, susceptance = 0.002)
addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 3")

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.05)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.03)

addWattmeter!(monitoring; from = "Branch 1", active = 1.046, variance = 1e-2)
addWattmeter!(monitoring; bus = "Bus 2", active = -0.1, variance = 1e-3)
addWattmeter!(monitoring; from = "Branch 3", active = 0.924, variance = 1e-3)

addVarmeter!(monitoring; from = "Branch 1", reactive = 0.059, variance = 1e-3)
addVarmeter!(monitoring; bus = "Bus 2", reactive = -0.01, variance = 1e-2)
addVarmeter!(monitoring; to = "Branch 3", reactive = -0.044, variance = 1e-3)

analysis = gaussNewton(monitoring)
stateEstimation!(analysis)
```

We can now utilize the provided functions to compute powers and currents:
```@example WLSACStateEstimationSolution
power!(analysis)
current!(analysis)
nothing # hide
```

For instance, if we want to show the active power injections and the from-bus current angles, we can employ the following code:
```@repl WLSACStateEstimationSolution
print(system.bus.label, analysis.power.injection.active)
print(system.branch.label, analysis.current.from.angle)
```

!!! note "Info"
    To better understand the powers and currents associated with buses and branches that are calculated by the [`power!`](@ref power!(::AcPowerFlow)) and [`current!`](@ref current!(::AC)) functions, we suggest referring to the tutorials on [AC State Estimation](@ref ACStateEstimationTutorials).

---

##### Print Results in the REPL
Users can utilize any of the print functions outlined in the [Print API](@ref setupPrintAPI). For example, to print state estimation data related to wattmeters, we can use:
```@example WLSACStateEstimationSolution
@power(MW, pu)
printWattmeterData(analysis)
@default(unit) # hide
nothing # hide
```

---

##### Save Results to a CSV File
For CSV output, users should first generate a simple table with `style = false`, and then save it to a CSV file:
```julia
using CSV

io = IOBuffer()
printWattmeterData(analysis, io; style = false)
CSV.write("bus.csv", CSV.File(take!(io); delim = "|"))
```

---

##### Active and Reactive Power Injection
To calculate the active and reactive power injection associated with a specific bus, the function can be used:
```@repl WLSACStateEstimationSolution
active, reactive = injectionPower(analysis; label = "Bus 1")
```

---

##### Active and Reactive Power Injection from Generators
To calculate the active and reactive power injection from the generators at a specific bus, the function can be used:
```@repl WLSACStateEstimationSolution
active, reactive = supplyPower(analysis; label = "Bus 1")
```

---

##### Active and Reactive Power at Shunt Element
To calculate the active and reactive power associated with shunt element at a specific bus, the function can be used:
```@repl WLSACStateEstimationSolution
active, reactive = shuntPower(analysis; label = "Bus 1")
```

---

##### Active and Reactive Power Flow
Similarly, we can compute the active and reactive power flow at both the from-bus and to-bus ends of the specific branch by utilizing the provided functions below:
```@repl WLSACStateEstimationSolution
active, reactive = fromPower(analysis; label = "Branch 2")
active, reactive = toPower(analysis; label = "Branch 2")
```

---

##### Active and Reactive Power at Charging Admittances
To calculate the active and reactive power linked with branch charging admittances of the particular branch, the function can be used:
```@repl WLSACStateEstimationSolution
active, reactive = chargingPower(analysis; label = "Branch 1")
```

Active powers indicate active losses within the branch's charging admittances. Moreover, charging admittances injected reactive powers into the power system due to their capacitive nature, as denoted by a negative sign.

---

##### Active and Reactive Power at Series Impedance
To calculate the active and reactive power across the series impedance of the branch, the function can be used:
```@repl WLSACStateEstimationSolution
active, reactive = seriesPower(analysis; label = "Branch 2")
```

The active power also considers active losses originating from the series resistance of the branch, while the reactive power represents reactive losses resulting from the impedance's inductive characteristics.

---

##### Current Injection
To calculate the current injection associated with a specific bus, the function can be used:
```@repl WLSACStateEstimationSolution
magnitude, angle = injectionCurrent(analysis; label = "Bus 1")
```

---

##### Current Flow
We can compute the current flow at both the from-bus and to-bus ends of the specific branch by utilizing the provided functions below:
```@repl WLSACStateEstimationSolution
magnitude, angle = fromCurrent(analysis; label = "Branch 2")
magnitude, angle = toCurrent(analysis; label = "Branch 2")
```

---

##### Current Through Series Impedance
To calculate the current passing through the series impedance of the branch in the direction from the from-bus end to the to-bus end, we can use the following function:
```@repl WLSACStateEstimationSolution
magnitude, angle = seriesCurrent(analysis; label = "Branch 2")
```