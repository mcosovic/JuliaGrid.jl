#  [State Estimation](@id runse)
To solve the state estimation problem three different modules are available:
* [non-linear state estimation](@ref nonlinearse),
* [linear DC state estimation](@ref lineardcse),
* [linear state estimation with PMUs only](@ref linearpmuse).
By default settings, the state estimation algorithms use the weighted least-squares estimation, but it is also possible to use the least absolute value estimation [1, Sec. 6.5].  

The non-linear state estimation is implemented using the following features:
 - the state vector is given in the polar coordinate system,
 - phasor measurements are given in the polar coordinate system,
 - measurement errors are uncorrelated,
 - the slack bus is included in the state estimation formulation.

The linear state estimation with PMUs] is implemented using the following features:
 - the state vector is given in the rectangular coordinate system,
 - phasor measurements are transformed from polar to rectangular coordinates,
 - the covariance matrix is transformed from polar to rectangular coordinates,
 - the slack bus is not included in the state estimation formulation.

Besides state estimation algorithms, we have implemented the bad data processing using the largest normalized
residual test [1, Sec. 5.7]. The routine proceeds with bad data analysis after the estimation process is finished, in the repetitive process of identifying and eliminating bad data measurements one after another.

The observability analysis with restore routine is based on the flow islands [2], [3], where pseudo-measurements are chosen between measurements that are marked as out-of-service in the input DATA.

---

## Run Settings
Input arguments of the function `runse()` describe the state estimation settings. The order of inputs and their appearance is arbitrary, with only DATA input required. Still, for the methodological reasons, the syntax examples follow a certain order.

#### Syntax
```julia-repl
runse(DATA, METHOD)
runse(DATA, METHOD, ROUTINE)
runse(DATA, METHOD, ROUTINE, DISPLAY)
runse(DATA, METHOD, ROUTINE, DISPLAY; ATTACH)
runse(DATA, METHOD, ROUTINE, DISPLAY; ATTACH, SAVE)
```
```@raw html
&nbsp;
```
#### Description
```julia-repl
runse(DATA, METHOD) solves the state estimation problem
runse(DATA, METHOD, ROUTINE) sets the least absolute values estimation, bad data and observability analysis
runse(DATA, METHOD, LAVBAD, DISPLAY) shows results in the terminal
runse(DATA, METHOD, LAVBAD, DISPLAY; ATTACH) sets various options mostly related with ROUTINE
runse(DATA, METHOD, LAVBAD, DISPLAY; ATTACH, SAVE) exports results data
```
```@raw html
&nbsp;
```
#### Output
```julia-repl
results, measurements, system, info = runse() returns results, measurements, power system and summary data
```
```@raw html
&nbsp;
```
####  Examples
```julia-repl
julia> results, = runse("case14se.xlsx", "dc", "main", "estimate", "error", "flow")
```
```julia-repl
julia> results, = runse("case30se.h5", "dc", "estimate"; bad = ["pass" 2])
```
```julia-repl
julia> results, = runse("case14se.xlsx", "pmu", "estimate", "lav")
```
```julia-repl
julia> data = runmg("case14.h5"; runflow = 1, pmuset = "complete", pmuvariance = ["complete" 1e-4])
julia> results, = runse(data, "pmu", "estimate")
```
---

## Input Arguments
The state estimation function `runse()` receives a group of variable number of arguments: DATA, METHOD, ROUTINE and DISPLAY, and group of arguments by keyword: ATTACH and SAVE.
```@raw html
&nbsp;
```
##### DATA - Variable Argument

| Example              | Description                                                              |
|:---------------------|:-------------------------------------------------------------------------|
|`"case30se.h5"`       | loads the state estimation data from the package                         |
|`"case14se.xlsx"`     | loads the state estimation data from the package                         |
|`"C:/case14.xlsx"`    | loads the state estimation data from a custom path                       |
|`output from runmg()` | loads the state estimation data from the measurement generator function  |

```@raw html
&nbsp;
```
##### METHOD - Variable Argument

| Command     | Description                                                                                 |
|:------------|:--------------------------------------------------------------------------------------------|
|`"nonlinear"`| runs the non-linear state estimation based on the weighted least-squares, `default setting` |
|`"pmu"`      | runs the linear weighted least-squares state estimation only with PMUs                      |
|`"dc"`       | runs the linear weighted least-squares DC state estimation                                  |

```@raw html
&nbsp;
```
##### ROUTINE - Variable Argument

| Command      | Description                                                                              |
|:-------------|:-----------------------------------------------------------------------------------------|
|`"lav"`       | runs the non-linear or linear state estimation using the least absolute value estimation with `"GLPK"` solver and `"equality"` constraints as `default settings` (see ATTACH to change `default settings`) |
|`"bad"` | when using the weighted least-squares estimation method runs the bad data processing, where the identification is equal to `"threshold" = 3`, with the maximum number of `"passes" = 1`, where critical measurement are marked according to `"critical" = 1e-10` (see ATTACH to change `default settings`) |
|`"observe"` | runs the observability analysis using the `"pivot" = 1e-5` threshold, where to restore observability routine takes only power injection measurements with variances in per-unit `"Pi" = 1e5` (see ATTACH to change `default settings`) |

```@raw html
&nbsp;
```
##### DISPLAY - Variable Argument

| Command     | Description                    |
|:------------|:-------------------------------|
|`"main"`     | shows main bus data display    |
|`"flow"`     | shows power flow data display  |
|`"estimate"` | shows estimation data display  |
|`"error"`    | shows evaluation data display  |

```@raw html
&nbsp;
```
##### ATTACH - Keyword Argument

| ATTACH:         |  Least Absolute Value Estimation Method                                                  |
|:----------------|:-----------------------------------------------------------------------------------------|
| **Command**     | `lav = [solver constraint]`                                                              |
| **Description** | the least absolute value estimation can be run using `"GLPK"` or `"Ipopt"` optimization `solver` with `constraint` equal to `"equality"` or `"inequality"`, `default setting: lav = ["GLPK" "equality"]` |

| ATTACH:         | Bad Data Processing                                                                      |
|:----------------|:-----------------------------------------------------------------------------------------|
| **Command**     | `bad = ["pass" value "threshold" value "critical" value]`                                |
| **Description** | when using the weighted least-squares estimation method bad data processing can be run using the bad data identification `threshold`, with the maximum number of `passes`, where `critical` measurement are marked according defined `value`, `default setting: bad = ["pass" 1 "threshold" 3 "critical" 1e-10]` |

| ATTACH:         | Observability Analysis                                                                   |
|:----------------|:-----------------------------------------------------------------------------------------|
| **Command**     | `observe = ["pivot" value "Pij" value "Pi" value "Ti" value]` |
| **Description** | observability analysis can be run using the `pivot` identification `threshold`, where active power flow `"Pij" value`, active power injection `"Pi" value` and/or bus voltage angle `"Ti" value` can be forced to restore observability, with measurement variances equal to `values`, `default setting: observe = ["pivot" 1e-5 "Pi" 1e5]` |

| ATTACH:         | Linear System Solver                                                                                                               |
|:----------------|:-----------------------------------------------------------------------------------------------------------------------------------|
| **Command**     | `solve = solver`                                                                                                                   |
| **Description** |  runs the linear system `solver` using built-in `solve = "builtin"` as `default setting` or LU linear system solver `solve = "lu"` |

```@raw html
&nbsp;
```
##### SAVE - Keyword Argument

| Command                 | Description                    |
|:------------------------|:-------------------------------|
|`save = "path/name.h5"`  | saves results in the h5-file   |
|`save = "path/name.xlsx"`| saves results in the xlsx-file |

---

## Input Data Structure
The function supports two input types: `.h5` or `.xlsx` file extensions. The measurement input data structure consists of variables `pmuVoltage` and `pmuCurrent` associated with phasor measurements, and `legacyFlow`, `legacyCurrent`, `legacyInjection` and `legacyVoltage` associated with legacy measurements. Further, the function requires knowledge about a power system using variables `bus`, `branch`, `generator` and `basePower`.

The minimum amount of information within an instance of the data structure required to run the module requires one variable associated with measurements, `bus` and `branch` variables.

We advise the reader to read the sections [Power System Data Structure](@ref powersysteminputdata) and [Measurement Data Structure](@ref measurementinputdata) which provides the structure of the input DATA, with numerous examples given in the section [Use Cases](@ref usecases).

---

## Output Data Structure
The state estimation function `runse()` returns a struct variable `results` with fields `main`, `flow`, `estimate`, `error`, `baddata` and `observability` containing state estimation analysis results. Further, the variables `measurements` and `system` contain the measurement and power system data, while the variable `info` contains a basic summary.
```@raw html
&nbsp;
```
#### DC State Estimation
We define the main electrical quantities generated by the JuliaGrid in the section [DC Power Flow Analysis](@ref dcpfanalysis).

The `main` data structure contains results related to the bus.

| Column   | Description                                    | Unit |
|:--------:|:-----------------------------------------------|:-----| 	 
| 1        | bus number defined as positive integer         |      |
| 2        | voltage angle                                  | deg  |
| 3        | active power injection                         | MW   |

```@raw html
&nbsp;
```
The `flow` data structure contains results related to the branch.

| Column  | Description                                 | Unit |
|:-------:|:--------------------------------------------|:-----|
| 1       | branch number defined as positive integer   |      |
| 2       | from bus number defined as positive integer |      |
| 3       | to bus number defined as positive integer   |      |
| 4       | from bus active power flow                  | MW   |
| 5       | to bus active power flow                    | MW   |

```@raw html
&nbsp;
```
#### Non-linear and Linear State Estimation with PMUs
We define main electrical quantities generated by the JuliaGrid in the section [AC Power Flow Analysis](@ref acpfanalysis).

The `main` data structure contains results related to the bus.

| Column   | Description                                      | Unit     |
|:--------:|:-------------------------------------------------|:---------| 	 
| 1        | bus number defined as positive integer           |          |
| 2        | voltage magnitude                                | per-unit |
| 3        | voltage angle                                    | deg      |
| 4        | active power injection                           | MW       |
| 5        | reactive power injection                         | MVAr     |
| 6        | active power consumed by the shunt conductance   | MW       |
| 7        | reactive power consumed by the shunt susceptance | MVAr     |

```@raw html
&nbsp;
```
The `flow` data structure contains results related to the branch.

| Column  | Description                                 | Unit     |
|:-------:|:--------------------------------------------|:---------|
| 1       | branch number defined as positive integer   |          |
| 2       | from bus number defined as positive integer |          |
| 3       | to bus number defined as positive integer   |          |
| 4       | from bus active power flow                  | MW       |
| 5       | from bus reactive power flow                | MVAr     |
| 6       | to bus active power flow                    | MW       |
| 7       | to bus reactive power flow                  | MVAr     |
| 8       | total branch reactive power injection       | MVAr     |
| 9       | active power loss at the series impedance   | MW       |
| 10      | reactive power loss at the series impedance | MVAr     |
| 11      | from bus current magnitude                  | per-unit |
| 12      | from bus current angle                      | deg      |
| 13      | to bus current magnitude                    | per-unit |
| 14      | to bus current angle                        | deg      |

```@raw html
&nbsp;
```
#### State Estimation
The `estimate` data structure contains summary of the state estimation analysis. The data is printed descriptively when displayed using a terminal, while the exported results are encoded with numeric values. Measurements that are marked as bad-measurement can only appear if the bad data analysis has been run, similarly pseudo-measurements occur if observability analysis is running.

| Column  | Description                                                                          |
|:-------:|:-------------------------------------------------------------------------------------|
| 1       | row number defined as positive integer                                               |
| 2       | measurement status where in-service = 1, bad-measurement = 2, pseudo-measurement = 3 |
| 3       | measurement class where legacy = 1, PMU = 2                                          |
| 4       | measurement type where flow = 1, injection = 4, angle = 8                            |
| 5       | local index of the measurement given in the input DATA                               |
| 6       | measurement value                                                                    |
| 7       | measurement variance value                                                           |
| 8       | estimate value                                                                       |
| 9       | residual estimate to measurement values                                              |
| 10      | exact value (if exists in the input DATA)                                            |
| 11      | residual estimate to exact values (if exact values exist)                            |

```@raw html
&nbsp;
```
The `error` data structure contains different error metrics which are calculated in the per-unit system. Note that only in-service measurement values are included, respectively bad data and pseudo-measurement are not included.

| Column  | Description                                                                                                   |
|:-------:|:--------------------------------------------------------------------------------------------------------------|
| 1       | mean absolute error of the estimate and corresponding measurement values                                      |
| 2       | root mean square error of the estimate and corresponding measurement values                                   |
| 3       | weighted residual sum of squares error of the estimate and corresponding measurement values                   |
| 4       | mean absolute error  of the estimate and corresponding exact values (if exact values exist)                   |
| 5       | root mean square error of the estimate and corresponding exact values (if exact values exist)                 |  
| 6       | weighted residual sum of squares error of the estimate and corresponding exact values (if exact values exist) |

```@raw html
&nbsp;
```
The `baddata` data structure contains information about bad data analysis. Note that if the bad data measurement corresponds with critical measurement, this measurement is skipped, and one of the next, with the highest normalized residual, is marked as the bad data in the same pass.

| Column  | Description                                                                                |
|:-------:|:-------------------------------------------------------------------------------------------|
| 1       | pass of weighted least-squares method, where in each pass suspected bad data is eliminated |
| 2       | bad measurement class where legacy = 1, PMU = 2                                            |
| 3       | bad measurement type where flow = 1, injection = 4, angle = 8                              |
| 4       | local index of the bad measurement given in the input DATA                                 |
| 5       | normalized residual value of the bad data measurement                                      |
| 6       | measurement status where bad-measurement = 2                                               |

```@raw html
&nbsp;
```
The `observability` data structure contains information about flow islands and pseudo-measurements, where each flow island is formed by buses. Pseudo-measurements are also marked in the `estimate` variable.  

| Column  | Description                                                      |
|:-------:|:-----------------------------------------------------------------|
| 1       | flow island as positive integer                                  |
| 2       | bus number in the corresponding island                           |
| 3       | pseudo-measurement class where legacy = 1, PMU = 2               |
| 4       | pseudo-measurement type where flow = 1, injection = 4, angle = 8 |
| 5       | local index of the pseudo-measurement given in the input DATA    |
| 6       | pseudo-measurement value                                         |
| 7       | pseudo-measurement variance                                      |

---
### References

[1] A. Abur and A. Exposito, “Power System State Estimation: Theory and Implementation,” ser. Power Engineering. Taylor & Francis, 2004.

[2] G. C. Contaxis and G. N. Korres, “A Reduced Model for Power System Observability Analysis and Restoration,” IEEE Trans. Power Syst., vol.
3, no. 4, pp. 1411-1417, Nov. 1988.

[3] N. M. Manousakis and G. N. Korres, "Observability analysis for power systems including conventional and phasor measurements," 7th Mediterranean Conference and Exhibition on Power Generation, Transmission, Distribution and Energy Conversion (MedPower 2010), Agia Napa, 2010.
