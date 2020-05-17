##  State Estimation (only DC)

The module runs the non-linear and DC state estimation, as well as the linear state estimation with PMUs only. By default settings, the state estimation algorithms use the weighted least-squares estimation, but it is also possible to use the least absolute value estimation [1, Sec. 6.5].  

The non-linear state estimation is implemented using the following features:
 - solved by the Gauss-Newton method,
 - the state vector is given in the polar coordinate system,
 - phasor measurements are given in the polar coordinate system,
 - measurement errors are uncorrelated.

The linear state estimation with PMUs only is implemented using the following features:
 - the state vector is given in the rectangular coordinate system,
 - phasor measurements are transformed from polar to rectangular coordinates,
 - the covariance matrix is transformed from polar to rectangular coordinates.

Besides state estimation algorithms, we have implemented the bad data processing using the largest normalized
residual test [1, Sec. 5.7]. The routine proceeds with bad data analysis after the estimation process is finished, in the repetitive process of identifying and eliminating bad data measurements one after another.

The observability analysis with restore routine is based on the flow islands [2], [3], where pseudo-measurements are chosen between measurements that are marked as out-service in the input DATA.

Finally, to achieve global observability of the power system only with PMUs, we implemented the optimal placement algorithm given in [4].

---

## Run Settings

Input arguments of the function `runse(...)` describe the state estimation settings. The order of inputs and their appearance is arbitrary, with only DATA input required. Still, for the methodological reasons, the syntax examples follow a certain order.

#### Syntax
```julia-repl
runse(DATA, METHOD)
runse(DATA, METHOD, ROUTINE)
runse(DATA, METHOD, ROUTINE, DISPLAY)
runse(DATA, METHOD, ROUTINE, DISPLAY; ATTACH)
runse(DATA, METHOD, ROUTINE, DISPLAY; ATTACH, SAVE)
```

#### Description
```julia-repl
runse(DATA, METHOD) solves state estimation problem
runse(DATA, METHOD, ROUTINE) sets least absolute values estimation, bad data processing and observability analysis
runse(DATA, METHOD, LAVBAD, DISPLAY) shows results in the terminal
runse(DATA, METHOD, LAVBAD, DISPLAY; ATTACH) sets various options mostly related with ROUTINE
runse(DATA, METHOD, LAVBAD, DISPLAY; ATTACH, SAVE) exports results data
```

#### Output
```julia-repl
results, measurements, system, info = runse(...) returns results of the state estimation, measurements and power system data with a summary
```

####  Examples
```julia-repl
julia> results, = runse("case14se.xlsx", "dc", "main", "estimate", "error", "flow")
```
```julia-repl
julia> data = runmg("case14.h5"; runflow = 1, legacyset = "complete", legacyvariance = ["complete" 1e-4])
julia> results, = runse(data, "dc", "estimate"; bad = ["pass" 3 "threshold" 2])
```
---

## Input Arguments

The state estimation function `runse(...)` receives a group of variable number of arguments: DATA, METHOD, ROUTINE and DISPLAY, and group of arguments by keyword: ATTACH and SAVE.

#### Variable Arguments

DATA

| Example                 | Description                                                 |
|:------------------------|:------------------------------------------------------------|
|`"case14.h5"`            | loads the state estimation data from the package            |
|`"case14.xlsx"`          | loads the state estimation data from the package            |
|`"C:/case14.xlsx"`       | loads the state estimation data from a custom path          |
|`output from runmg(...)` | loads the state estimation data from measurement generator  |

METHOD

| Command     | Description                                                                                 |
|:------------|:--------------------------------------------------------------------------------------------|
|`"nonlinear"`| runs the non-linear state estimation based on the weighted least-squares, `default setting` |
|`"pmu"`      | runs the linear weighted least-squares state estimation only with PMUs                      |
|`"dc"`       | runs the linear weighted least-squares DC state estimation                                  |

ROUTINE

| Command      | Description                                                                              |
|:-------------|:-----------------------------------------------------------------------------------------|
|`"lav"`       | runs the non-linear or linear state estimation using the least absolute value estimation (replacing  weighted least-squares everywhere) with `"GLPK"` solver and `"equality"` constraints as `default settings` (see ATTACH to change `default settings`) |
|`"bad"` | runs the bad data processing using the identification `"threshold" = 3`, with the maximum number of `"passes" = 1`, where critical measurement are marked according to `"critical" = 1e-10` (see ATTACH to change `default settings`) |
|`"observe"` | runs the observability analysis using the `"pivot" = 1e-5` threshold, where to restore observability routine takes only power injection measurements with variances in per-unit `"Pi" = 1e5` (see ATTACH to change `default settings`) |

DISPLAY

| Command     | Description                    |
|:------------|:-------------------------------|
|`"main"`     | shows main bus data display    |
|`"flow"`     | shows power flow data display  |
|`"estimate"` | shows estimation data display  |
|`"error"`    | shows evaluation data display  |

----

#### Keyword Arguments

ATTACH

| Command      | Description                                                                              |
|:-------------|:-----------------------------------------------------------------------------------------|
|`lav = [solver constraint]` | the least absolute value estimation can be run using `"GLPK"` or `"Ipopt"` optimization `solver` with `constraint` equal to `"equality"` or `"inequality"`, `default setting: lav = ["GLPK" "equality"]` |
|`bad = ["pass" value "threshold" value "critical" value]`| bad data processing can be run using the bad data identification `threshold`, with the maximum number of `passes`, where `critical` measurement are marked according defined `value`, `default setting: bad = ["pass" 1 "threshold" 3 "critical" 1e-10]` |
|`observe = ["pivot" value "Pij" value "Pi" value "Ti" value]`| observability analysis can be run using the `pivot` identification `threshold`, where active power flow `"Pij" value`, active power injection `"Pi" value` and/or bus voltage angle `"Ti" value` can be forced to restore observability, with measurement variances equal to `values`, `default setting: bad = ["pivot" 1e-5 "Pi" 1e5]` |
|`solve = solver` | runs the linear system `solver` using built-in `solve = "builtin"` as `default setting` or LU linear system solver `solve = "lu"` |   

SAVE

| Command                 | Description                    |
|:------------------------|:-------------------------------|
|`save = "path/name.h5"`  | saves results in the h5-file   |
|`save = "path/name.xlsx"`| saves results in the xlsx-file |
---

## Input Data Structure
The function supports the `.h5` or `.xlsx` file extensions, with variables `pmuVoltage` and `pmuCurrent` associated with phasor measurements, and `legacyFlow`, `"legacyCurrent"`, `"legacyInjection"` and `"legacyVoltage"` associated with legacy measurements. Further, the function requires knowledge about a power system using variables `bus`, `branch`, `generator` and `"basePower"` variables.

The minimum amount of information within an instance of the data structure required to run the module requires one variable associated with measurements, `bus` and `branch` variables.

Next, we describe the structure of measurement variables involved in the input file, while variables associated with a power system are described in [Power Flow](@ref) section.

The `pmuVoltage` data structure

| Column   | Description        | Description                             | Unit     |
|:--------:|:-------------------|:----------------------------------------|:---------|	 
| 1        | bus number         | positive integer                        |          |
| 2        | measurement        | bus voltage magnitude                   | per-unit |
| 3        | variance           | bus voltage magnitude                   | per-unit |
| 4        | status             | bus voltage magnitude in/out-service    |          |
| 5        | measurement        | bus voltage angle                       | radian   |
| 6        | variance           | bus voltage angle                       | radian   |
| 7        | status             | bus voltage angle in/out-service        |          |
| 8        | exact              | optional column, bus voltage magnitude  | per-unit |
| 9        | exact              | optional column, bus voltage angle      | radian   |

The `pmuCurrent` data structure

| Column  | Description        | Description                                | Unit     |
|:-------:|:-------------------|:-------------------------------------------|:---------|
| 1       | branch number      | positive integer                           |          |
| 2       | from bus number    | positive integer                           |          |
| 3       | to bus number      | positive integer                           |          |
| 4       | measurement        | branch current magnitude                   | per-unit |
| 5       | variance           | branch current magnitude                   | per-unit |
| 6       | status             | branch current magnitude in/out-service    |          |
| 7       | measurement        | branch current angle                       | radian   |
| 8       | variance           | branch current angle                       | radian   |
| 9       | status             | branch current in/out-service              |          |
| 10      | exact              | optional column, branch current magnitude  | per-unit |
| 11      | exact              | optional column, branch current angle      | radian   |

---

The `legacyFlow` data structure

| Column  | Type               | Description                          | Unit     |
|:-------:|:-------------------|:-------------------------------------|:---------|
| 1       | branch number      | positive integer                     |          |
| 2       | from bus number    | positive integer                     |          |
| 3       | to bus number      | positive integer                     |          |
| 4       | measurement        | active power flow                    | per-unit |
| 5       | variance           | active power flow                    | per-unit |
| 6       | status             | active power flow in/out-service     |          |
| 7       | measurement        | reactive power flow                  | per-unit |
| 8       | variance           | reactive power flow                  | per-unit |
| 9       | status             | reactive power flow in/out-service   |          |
| 10      | exact              | optional column, active power flow   | per-unit |
| 11      | exact              | optional column, reactive power flow | per-unit |

The `legacyCurrent` data structure

| Column  | Type               | Description                               | Unit     |
|:-------:|:-------------------|:------------------------------------------|:---------|
| 1       | branch number      | positive integer                          |          |
| 2       | from bus number    | positive integer                          |          |
| 3       | to bus number      | positive integer                          |          |
| 4       | measurement        | branch current magnitude                  | per-unit |
| 5       | variance           | branch current magnitude                  | per-unit |
| 6       | status             | branch current magnitude in/out-service   |          |
| 7       | exact              | optional column, branch current magnitude | per-unit |

The `legacyInjection` data structure

| Column   | Type               | Description                               | Unit     |
|:--------:|:-------------------|:------------------------------------------|:---------|	 
| 1        | bus number         | positive integer                          |          |
| 2        | measurement        | active power injection                    | per-unit |
| 3        | variance           | active power injection                    | per-unit |
| 4        | status             | active power injection in/out-service     |          |
| 5        | measurement        | reactive power injection                  | per-unit |
| 6        | variance           | reactive power injection                  | per-unit |
| 7        | status             | reactive power injection  in/out-service  |          |
| 8        | exact              | optional column, active power injection   | per-unit |
| 9        | exact              | optional column, reactive power injection | per-unit |

The `pmuVoltage` data structure

| Column   | Type               | Description                            | Unit     |
|:--------:|:-------------------|:---------------------------------------|:---------|	 
| 1        | bus number         | positive integer                       |          |
| 2        | measurement        | bus voltage magnitude                  | per-unit |
| 3        | variance           | bus voltage magnitude                  | per-unit |
| 4        | status             | bus voltage magnitude in/out-service   |          |
| 5        | exact              | optional column, bus voltage magnitude | per-unit |
---

!!! tip "How many"
    The input data needs not to contain a complete structure of measurement variables, and measurement data needs not to be consistent with the total number of buses and branches. Also, the function supports more than one same measurement per the same bus or branch.
---

## Output Data Structure
The state estimation function `runpf(...)` returns a struct variable `results` with fields `main`, `flow`, `estimate`, `error`, `baddata` and `observability` containing state estimation analysis results. Further, the variables `measurements` and `system` contain the measurement and power system data, while the variable `info` contains a basic summary.

#### DC State estimation

The `main` data structure contains estimates of voltage angles and the calculated power injection based on them.

| Column   | Type               | Description             | Unit      |
|:--------:|:-------------------|:------------------------|:----------|	 
| 1        | bus number         | positive integer        |           |
| 2        | voltage            | angle                   | deg       |
| 3        | injection          | active power            | MW        |


The `flow` data structure contains power flow values obtained according to estimates of voltage angles.

| Column  | Type                       | Description      | Unit     |
|:-------:|:---------------------------|:-----------------|:---------|
| 1       | branch number              | positive integer |          |
| 2       | from bus number            | positive integer |          |
| 3       | to bus number              | positive integer |          |
| 4       | from bus flow              | active power     | MW       |
| 5       | to bus flow                | active power     | MW       |

The `estimate` data structure contains summary of the state estimation analysis. The data is printed descriptively when displayed using a terminal, while the exported results are encoded with numeric values. Measurements that are marked as bad-measurement can only appear if the bad data analysis has been run, similarly pseudo-measurements occur if observability analysis is running.

| Column  | Type                       | Description                                                                 |
|:-------:|:---------------------------|:----------------------------------------------------------------------------|
| 1       | row number                 | positive integer                                                            |
| 2       | device                     | status, in-service(1), bad-measurement(2) and pseudo-measurement(3)         |
| 3       | device                     | class, legacy(1) and PMU(2)                                                 |
| 4       | device                     | type, flow(1), injection(4) and angle(8)                                    |
| 5       | device                     | local index of the measurement given in the input DATA                      |
| 6       | device                     | measure value                                                               |
| 7       | device                     | variance value                                                              |
| 8       | algorithm                  | estimate value                                                              |
| 9       | residual                   | estimate to measure values                                                  |
| 10      | user                       | exact value (if exists in the input DATA)                                   |
| 11      | residual                   | estimate to exact values (if exact values exist)                            |

The `error` data structure contains different error metrics which are calculated in the per-unit system. Note that only in-service measurement values are included, respectively bad data and pseudo-measurement are not included.

| Row     | Type                                   | Description                                                             | Unit     |
|:-------:|:---------------------------------------|:------------------------------------------------------------------------|:---------|
| 1       | mean absolute error                    | between estimate and corresponding measurement values                   | per-unit |
| 2       | root mean square error                 | between estimate and corresponding measurement values                   | per-unit |
| 3       | weighted residual sum of squares error | between estimate and corresponding measurement values                   | per-unit |
| 4       | mean absolute error                    | between estimate and corresponding exact values (if exact values exist) | per-unit |
| 5       | root mean square error                 | between estimate and corresponding exact values (if exact values exist) | per-unit |
| 6       | weighted residual sum of squares error | between estimate and corresponding exact values (if exact values exist) | per-unit |

The `baddata` data structure contains information about bad data analysis. Note that if the bad data measurement corresponds with critical measurement,
this measurement is skipped, and one of the next, with the highest normalized residual, is marked as the bad data in the same pass.

| Column  | Type                       | Description                                             |
|:-------:|:---------------------------|:--------------------------------------------------------|
| 1       | algorithm                  | in each pass suspected bad data is eliminated           |
| 2       | device                     | type, legacy(1), pmu(2)                                 |
| 3       | device                     | bad data, flow(1), injection(4) and angle(8)            |
| 4       | device                     | local index of the measurement given in the input DATA  |
| 5       | algorithm                  | normalized residual of the bad data measurement         |
| 6       | device                     | status, bad-measurement(2)                              |

The `observability` data structure contains information about flow islands, where each flow island is formed by buses. Pseudo-measurements are marked in the `estimate` variable.  

## References
[1] A. Abur and A. Exposito, “Power System State Estimation: Theory and Implementation,” ser. Power Engineering. Taylor & Francis, 2004.

[2] G. C. Contaxis and G. N. Korres, “A Reduced Model for Power System Observability Analysis and Restoration,” IEEE Trans. Power Syst., vol.
3, no. 4, pp. 1411-1417, Nov. 1988.

[3] N. M. Manousakis and G. N. Korres, "Observability analysis for power systems including conventional and phasor measurements," 7th Mediterranean Conference and Exhibition on Power Generation, Transmission, Distribution and Energy Conversion (MedPower 2010), Agia Napa, 2010.

[4] B. Gou, “Optimal placement of PMUs by integer linear programming,” IEEE Trans. Power Syst., vol. 23, no. 3, pp. 1525–1526, Aug. 2008.
