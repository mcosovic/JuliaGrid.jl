# [DC State Estimation](@id DCStateEstimationManual)
Performing DC state estimation first requires the `PowerSystem` type that has been created with the DC model, alongside the `Measurement` type that retains measurement data. Next, formulate either the weighted least-squares (WLS) or the least absolute value (LAV) DC state estimation model encapsulated within the type `DcStateEstimation` using:
* [`dcStateEstimation`](@ref dcStateEstimation),
* [`dcLavStateEstimation`](@ref dcLavStateEstimation).

---

To obtain bus voltage angles and solve the DC state estimation problem, users can use:
* [`solve!`](@ref solve!(::DcStateEstimation{WLS{T}}) where T <: Normal).

After solving the DC state estimation, JuliaGrid provides a function for computing powers:
* [`power!`](@ref power!(::DcPowerFlow)).

Alternatively, users can call the wrapper function to solve the WLS or LAV model and, optionally, compute powers:
* [`stateEstimation!`](@ref stateEstimation!(::DcStateEstimation{<:WLS})).

Users can also access specialized functions for computing specific types of [powers](@ref DCPowerAnalysisAPI) for individual buses, branches, or generators within the power system.

---

## [Weighted Least-Squares Estimator](@id DCWLSStateEstimationSolutionManual)
To solve the DC state estimation and derive WLS estimates using JuliaGrid, the process initiates by defining `PowerSystem` and `Measurement` types. Here is an illustrative example:
```@example WLSDCStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 3")

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.5)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.2)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.3)

@wattmeter(label = "Wattmeter ?")
addWattmeter!(monitoring; bus = "Bus 1", active = 0.6, variance = 1e-3)
addWattmeter!(monitoring; bus = "Bus 3", active = -0.4, variance = 1e-2)
addWattmeter!(monitoring; from = "Branch 1", active = 0.18, variance = 1e-4)
addWattmeter!(monitoring; to = "Branch 2", active = -0.42, variance = 1e-4)
nothing # hide
```

The [`dcStateEstimation`](@ref dcStateEstimation) function serves to establish the DC state estimation problem:
```@example WLSDCStateEstimationSolution
analysis = dcStateEstimation(monitoring)
nothing # hide
```

!!! tip "Tip"
    Here, the user triggers LU factorization as the default method for solving the DC state estimation problem. The available factorization methods are `LL`, `LDLt`, `LU`, `KLU`, and `QR`:
    ```julia WLSDCStateEstimationSolution
    analysis = dcStateEstimation(monitoring, LDLt)
    ```

To obtain the bus voltage angles, use the [`solve!`](@ref solve!(::DcStateEstimation{WLS{T}}) where T <: Normal) function as shown:
```@example WLSDCStateEstimationSolution
solve!(analysis)
nothing # hide
```

Upon obtaining the solution, access the bus voltage angles using:
```@repl WLSDCStateEstimationSolution
print(system.bus.label, analysis.voltage.angle)
nothing # hide
```

!!! note "Info"
    For implementation details, see the tutorial on [DC State Estimation](@ref DCSEModelTutorials).

---

##### Wrapper Function
JuliaGrid provides the [`stateEstimation!`](@ref stateEstimation!(::DcStateEstimation{<:WLS})) wrapper function for DC state estimation. It solves the WLS or LAV model, and it can optionally compute powers:
```@example WLSDCStateEstimationSolution
analysis = dcStateEstimation(monitoring)
stateEstimation!(analysis; verbose = 2)
nothing # hide
```

---

##### Print Results in the REPL
Users can print the results in the REPL using any units that have been configured, such as:
```@example WLSDCStateEstimationSolution
@voltage(pu, deg)
printBusData(analysis)
@default(unit) # hide
```

Next, users can customize the print results for specific buses, for example:
```julia
printBusData(analysis; label = "Bus 1", header = true)
printBusData(analysis; label = "Bus 2")
printBusData(analysis; label = "Bus 3", footer = true)
```

---

##### Save Results to a File
Users can also redirect print output to a file. For example, data can be saved in a text file:
```julia
open("bus.txt", "w") do file
    printBusData(analysis, file)
end
```

!!! tip "Tip"
    JuliaGrid also provides functions to print state estimation results, such as estimated values and residuals. For more details, users can consult the [Power Analysis](@ref DCSEPowerAnalysisManual) section of this manual.

---


## Alternative Formulations
The conventional approach to solving the WLS state estimation problem generally performs well. However, it is well known that, under certain conditions often encountered in real-world systems, this method may suffer from numerical instabilities. These issues can prevent the algorithm from reaching a satisfactory solution. In such scenarios, users may choose to apply an alternative formulation of the WLS estimator.

---

##### Orthogonal Method
One such alternative is the orthogonal method [aburbook; Sec. 3.2](@cite), which offers increased numerical robustness, particularly in cases where measurement variances differ significantly. By specifying the `Orthogonal` argument in the [`dcStateEstimation`](@ref dcStateEstimation) function, users can solve the WLS problem via QR factorization applied to a rectangular matrix formed by multiplying the square root of the precision matrix with the coefficient matrix:
```@example WLSDCStateEstimationSolution
analysis = dcStateEstimation(monitoring, Orthogonal)
stateEstimation!(analysis)
nothing # hide
```

---

##### Peters and Wilkinson Method
Another option is the Peters and Wilkinson method [aburbook; Sec. 3.4](@cite), which applies LU factorization to the same rectangular matrix, constructed using the square root of the precision matrix and the coefficient matrix. This method can be selected by passing the `PetersWilkinson` argument to the [`dcStateEstimation`](@ref dcStateEstimation) function:
```@example WLSDCStateEstimationSolution
analysis = dcStateEstimation(monitoring, PetersWilkinson)
stateEstimation!(analysis)
nothing # hide
```

---

## [Least Absolute Value Estimator](@id DCLAVStateEstimationSolutionManual)
The LAV method presents an alternative estimation technique known for its increased robustness compared to WLS. While the WLS method relies on specific assumptions regarding measurement errors, robust estimators like LAV are designed to maintain unbiasedness even in the presence of various types of measurement errors and outliers. This characteristic often eliminates the need for extensive bad data analysis procedures [aburbook; Ch. 6](@cite). However, it is important to note that achieving robustness typically involves increased computational complexity.

To obtain an LAV estimator, users need to use one of the [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) listed in the JuMP documentation. In many common scenarios, the Ipopt solver proves sufficient to obtain a solution:
```@example WLSDCStateEstimationSolution
using Ipopt
using JuMP  # hide

analysis = dcLavStateEstimation(monitoring, Ipopt.Optimizer)
nothing # hide
```

---

##### Setup Initial Primal Values
In JuliaGrid, the assignment of initial primal values for optimization variables takes place when the [`solve!`](@ref solve!(::DcStateEstimation{WLS{T}}) where T <: Normal) function is executed. These values are derived from the voltage angles stored in the `PowerSystem` type and are assigned to the corresponding `voltage` field within the `DcStateEstimation` type:
```@repl WLSDCStateEstimationSolution
print(system.bus.label, analysis.voltage.angle)
```

Users can customize these values, which will be used as the initial primal values when executing the [`solve!`](@ref solve!(::DcStateEstimation{WLS{T}}) where T <: Normal) function. One practical approach is to obtain the WLS estimator and then apply the resulting solution as the starting point for state estimation:
```@example WLSDCStateEstimationSolution
wls = dcStateEstimation(monitoring)
stateEstimation!(wls)

setInitialPoint!(analysis, wls)
nothing # hide
```

As a result, the initial primal values will now reflect the outcome of the WLS state estimation solution:
```@repl WLSDCStateEstimationSolution
print(system.bus.label, analysis.voltage.angle)
```

---

##### Solution
To solve the formulated LAV state estimation model, call the wrapper function:
```@example WLSDCStateEstimationSolution
stateEstimation!(analysis)
nothing # hide
```

Upon obtaining the solution, access the bus voltage angles using:
```@repl WLSDCStateEstimationSolution
print(system.bus.label, analysis.voltage.angle)
nothing # hide
```

!!! note "Info"
    Readers can refer to the [Least Absolute Value Estimation](@ref DCSELAVTutorials) tutorial for implementation insights.

---

## [Measurement Set Update](@id DCMeasurementsAlterationManual)
Begin by creating the `PowerSystem` and `Measurement` types with the [`ems`](@ref ems) function. The DC model is then configured using the [`dcModel!`](@ref dcModel!) function. After that, initialize the `DcStateEstimation` type through the [`dcStateEstimation`](@ref dcStateEstimation) function and solve the resulting state estimation problem:
```@example WLSDCStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2")

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.5)

dcModel!(system)

@wattmeter(label = "Wattmeter ?")
addWattmeter!(monitoring; bus = "Bus 2", active = -0.11, variance = 1e-3)
addWattmeter!(monitoring; from = "Branch 1", active = 0.09, variance = 1e-4)

analysis = dcStateEstimation(monitoring)
stateEstimation!(analysis)
nothing # hide
```

Next, modify the existing `Measurement` type using add and update functions. Then, create the new `DcStateEstimation` type based on the modified system and solve the state estimation problem:
```@example WLSDCStateEstimationSolution
addWattmeter!(monitoring; to = "Branch 1", active = -0.12, variance = 1e-4)
updateWattmeter!(monitoring; label = "Wattmeter 1", status = 0)
updateWattmeter!(monitoring; label = "Wattmeter 2", active = 0.1, noise = false)

analysis = dcStateEstimation(monitoring)
stateEstimation!(analysis)
nothing # hide
```

!!! note "Info"
    This concept removes the need to restart and recreate the `Measurement` type from the beginning when implementing changes to the existing measurement set.

---

## [State Estimation Update](@id DCStateEstimationUpdateManual)
For advanced workflows, users can create the `DcStateEstimation` type once using [`dcStateEstimation`](@ref dcStateEstimation) or [`dcLavStateEstimation`](@ref dcLavStateEstimation). They can then modify existing measurement devices without recreating the `DcStateEstimation` type.

This approach extends the previous workflow by also avoiding recreation of the `DcStateEstimation` object. This is particularly useful when JuliaGrid can reuse the gain matrix factorization.

!!! tip "Tip"
    The addition of new measurements after the creation of `DcStateEstimation` is not practical in terms of reusing this type. Instead, users should create a final set of measurements and then use update functions to manage devices, either setting them in-service or out-of-service throughout the process.

Now revisit the defined `PowerSystem`, `Measurement` and `DcStateEstimation` types:
```@example WLSDCStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2")

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.5)

dcModel!(system)

@wattmeter(label = "Wattmeter ?")
addWattmeter!(monitoring; bus = "Bus 2", active = -0.11, variance = 1e-3)
addWattmeter!(monitoring; from = "Branch 1", active = 0.09, variance = 1e-4)
addWattmeter!(monitoring; to = "Branch 1", active = -0.12, variance = 1e-4, status = 0)

analysis = dcStateEstimation(monitoring)
stateEstimation!(analysis)
nothing # hide
```

Next, modify the existing `Measurement` type as well as the `DcStateEstimation` type using add and update functions. Then, immediately solve the state estimation problem:
```@example WLSDCStateEstimationSolution
updateWattmeter!(analysis; label = "Wattmeter 1", status = 0)
updateWattmeter!(analysis; label = "Wattmeter 2", active = 0.1)
updateWattmeter!(analysis; label = "Wattmeter 3", status = 1, noise = false)

stateEstimation!(analysis)
nothing # hide
```


!!! note "Info"
    This concept removes the need to rebuild both the `Measurement` and the `DcStateEstimation` from the beginning when implementing changes to the existing measurement set. In the scenario of using the WLS model, JuliaGrid can reuse symbolic factorizations of `LL`, `LDLt`, `LU`, and `KLU`, provided that the nonzero pattern of the gain matrix remains unchanged.

---

##### Reusing Weighted Least-Squares Matrix Factorization
Continuing from the preceding example, consider modifications that adjust the measurement value of the `Wattmeter 2`. These adjustments do not impact the variance or status of the measurement device, which can affect the gain matrix. To resolve this updated system, users can call the [`stateEstimation!`](@ref stateEstimation!(::DcStateEstimation{<:WLS})) wrapper function:
```@example WLSDCStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

updateWattmeter!(analysis; label = "Wattmeter 2", active = 0.091)

stateEstimation!(analysis)
nothing # hide
```

!!! note "Info"
    Here, JuliaGrid recognizes when the user has not modified parameters that impact the gain matrix. Consequently, JuliaGrid reuses the previously computed gain matrix factorization, resulting in a significantly faster solution compared to recomputing the factorization.

---

## [Power Analysis](@id DCSEPowerAnalysisManual)
After obtaining the solution from the DC state estimation, use the [`power!`](@ref power!(::DcPowerFlow)) function to calculate powers related to buses and branches. For instance, consider the model used to obtain the DC state estimation solution:
```@example WLSDCStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1", type = 3, conductance = 1e-3)
addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 3")

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.5)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.2)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.3)

addWattmeter!(monitoring; bus = "Bus 1", active = 0.6, variance = 1e-3)
addWattmeter!(monitoring; bus = "Bus 3", active = -0.4, variance = 1e-2)
addWattmeter!(monitoring; from = "Branch 1", active = 0.18, variance = 1e-4)
addWattmeter!(monitoring; to = "Branch 2", active = -0.42, variance = 1e-4)

analysis = dcStateEstimation(monitoring)
stateEstimation!(analysis)
nothing # hide
```

Compute active powers using the following function:
```@example WLSDCStateEstimationSolution
power!(analysis)
nothing # hide
```

For example, active power injections corresponding to buses are:
```@repl WLSDCStateEstimationSolution
print(system.bus.label, analysis.power.injection.active)
```

!!! note "Info"
    To better understand the powers associated with buses and branches that are calculated by the [`power!`](@ref power!(::DcPowerFlow)) function, see the [DC State Estimation](@ref DCSEModelTutorials) tutorial.

---

##### Print Results in the REPL
Users can use any of the print functions outlined in the [Print API](@ref setupPrintAPI) related to the DC analysis. For example, to print state estimation data related to wattmeters, use:
```@example WLSDCStateEstimationSolution
@power(MW, pu)
printWattmeterData(analysis)
@default(unit) # hide
```

---

##### Save Results to a CSV File
For CSV output, users should first generate a simple table with `style = false`, and then save it to a CSV file:
```julia
using CSV

io = IOBuffer()
printWattmeterData(analysis, io; style = false)
CSV.write("wattmeter.csv", CSV.File(take!(io); delim = "|"))
```

---

##### Active Power Injection
To calculate the active power injection associated with a specific bus, use:
```@repl WLSDCStateEstimationSolution
active = injectionPower(analysis; label = "Bus 1")
```

---

##### Active Power Injection from Generators
To calculate the active power supply associated with a specific bus, use:
```@repl WLSDCStateEstimationSolution
active = supplyPower(analysis; label = "Bus 1")
```

---

##### Active Power Flow
Similarly, to compute the active power flow at both the from-bus and to-bus ends of a specific branch, use:
```@repl WLSDCStateEstimationSolution
active = fromPower(analysis; label = "Branch 1")
active = toPower(analysis; label = "Branch 1")
```