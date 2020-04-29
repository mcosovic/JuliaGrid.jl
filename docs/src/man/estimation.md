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

Finally, to achieve global observability of the power system only with PMUs, we implemented the optimal placement algorithm given in [2].

---

## Run Settings

Input arguments of the function `runse(...)` describe the state estimation settings. The order of inputs and their appearance is arbitrary, with only DATA input required. Still, for the methodological reasons, the syntax examples follow a certain order.

#### Syntax
```julia-repl
runse(DATA, METHOD)
runse(DATA, METHOD, LAVBAD)
runse(DATA, METHOD, LAVBAD, DISPLAY)
runse(DATA, METHOD, LAVBAD, DISPLAY; ATTACH)
runse(DATA, METHOD, LAVBAD, DISPLAY; ATTACH, SET)
runse(DATA, METHOD, LAVBAD, DISPLAY; ATTACH, SET, VARIANCE)
runse(DATA, METHOD, LAVBAD, DISPLAY; ATTACH, SET, VARIANCE, SAVE)
```

#### Description
```julia-repl
runse(DATA, METHOD) solves state estimation problem
runse(DATA, METHOD, LAVBAD) sets least absolute values estimation and bad data processing
runse(DATA, METHOD, LAVBAD, DISPLAY) shows results in the terminal
runse(DATA, METHOD, LAVBAD, DISPLAY; ATTACH) sets various options related with algorithms
runse(DATA, METHOD, LAVBAD, DISPLAY; ATTACH, SET) defines the measurement set (in-service and out-service)
runse(DATA, METHOD, LAVBAD, DISPLAY; ATTACH, SET, VARIANCE) defines measurement values using predefined variances
runse(DATA, METHOD, LAVBAD, DISPLAY; ATTACH, SET, VARIANCE, SAVE) exports results data
```

#### Output
```julia-repl
results = runse(...) returns results of the state estimation
```

####  Examples
```julia-repl
julia> results = runse("case14se.xlsx", "dc", "main", "estimate", "error", "flow")
```
```julia-repl
julia> results = runse("case14se.xlsx", "dc"; bad = ["pass" 3 "threshold" 2])
```
---

## Input Arguments

The state estimation function `runse(...)` receives a group of variable number of arguments: DATA, METHOD, LAVBAD and DISPLAY, and group of arguments by keyword: ATTACH, SET, VARIANCE and SAVE

#### Variable Arguments

DATA

| Example           | Description                                        |
|:------------------|:---------------------------------------------------|
|`"case14.h5"`      | loads the state estimation data from the package   |
|`"case14.xlsx"`    | loads the state estimation data from the package   |
|`"C:/case14.xlsx"` | loads the state estimation data from a custom path |

METHOD

| Command     | Description                                                                                 |
|:------------|:--------------------------------------------------------------------------------------------|
|`"nonlinear"`| runs the non-linear state estimation based on the weighted least-squares, `default setting` |
|`"pmu"`      | runs the linear weighted least-squares state estimation only with PMUs                      |
|`"dc"`       | runs the linear weighted least-squares DC state estimation                                  |

LAVBAD

| Command      | Description                                                                              |
|:-------------|:-----------------------------------------------------------------------------------------|
|`"lav"`       | runs the non-linear or linear state estimation using the least absolute value estimation (replacing  weighted least-squares everywhere) with `"GLPK"` solver and `"equality"` constraints as `default settings` (see ATTACH to change `default settings`) |
|`"bad"` | runs the bad data processing using the identification `"treshold" = 3`, with the maximum number of `"passes" = 1`, where critical measurement are marked according to `"critical" = 1e-10` (see ATTACH to change `default settings`) |


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
|`bad = ["pass" value "treshold" value "critical" value]`| bad data processing can be run using the identification `treshold`, with the maximum number of `passes`, where `critical` measurement are marked according defined value, `default setting: bad = ["pass" 1 "treshold" 3 "critical" 1e-10]` |
|`solve = solver` | runs the linear system `solver` using built-in `solve = "builtin"` as `default setting` or LU linear system solver `solve = "lu"` |   

SET (phasor measurements)

| Command                                                      | Description                                                      |
|:-------------------------------------------------------------|:-----------------------------------------------------------------|
|`pmuset = "all"`                                              | all phasor measurements are in-service                           |
|`pmuset = "optimal"`                                          | deploys phasor measurements according to the optimal PMU location using GLPK solver, where the system is completely observable only by phasor measurements |
|`pmuset = ["redundancy" value]`                              | deploys random angle and magnitude measurements measured by PMUs according to the corresponding redundancy |
|`pmuset = ["device" value]`                                   | deploys voltage and current phasor measurements according to the random selection of PMUs placed on buses, to deploy all devices use `"all"` as value |
|`pmuset = ["Iij" value "Dij" value "Vi" value "Ti" value]` | deploys phasor measurements according to the random selection of measurement types[^1], to deploy all selected measurements use `"all"` as value |

SET (legacy measurements)

| Command                                                                                  | Description                                      |
|:-----------------------------------------------------------------------------------------|:-------------------------------------------------|
|`legacyset = "all"`                                                                       | all legacy measurements are in-service           |
|`legacyset = ["redundancy " value]`                                                       | deploys random selection of legacy measurements according the corresponding redundancy |
|`legacyset = ["Pij" value "Qij" value "Iij" value "Pi" value "Qi" value "Vi" value]`      | deploys legacy measurements according to the random selection of measurement types[^2], to deploy all selected measurements use `"all"` as value |

!!! note "Set"
    The function keeps sets as in the input DATA and changes only the sets that are called using keywords. For example, if the keywords `pmuset` and `legacyset` are omitted, the function will retain the measurement set as in the input data, which allows the same measurement set, while changing the measurement variances.

    Further, the function accept any subset of phasor[^1] or legacy[^2] measurements, and consequently, it is not necessary to define attributes for all measurements.  
    ```julia-repl
    julia> runmg("case14.h5"; pmuset = ["Iij" "all" "Vi" 2])
    ```
    Thus, the measurement set will be changed in the data for the bus voltage magnitude and branch current magnitude measurements, both of them related with PMUs.  

VARIANCE (phasor measurements)

| Command                                                           | Description                                                                               |
|:------------------------------------------------------------------|:------------------------------------------------------------------------------------------|
|`pmuvariance = ["all" value]`                                      | applies fixed-value variance over all phasor measurements                                 |
|`pmuvariance = ["random" min max]`                                 | selects variances uniformly at random within limits, applied over all phasor measurements |
|`pmuvariance = ["Iij" value "Dij" value "Vi" value "Ti" value "all" value]` | predefines variances over a given subset of phasor measurements[^1]; to apply fixed-value variance over all, except for those individually defined use `"all" value`                       |

VARIANCE (legacy measurements)

| Command                                                      | Description                                                                       |
|:-------------------------------------------------------------|:----------------------------------------------------------------------------------|
|`legacyvariance = ["all" value]`                              | applies fixed-value variance over all phasor measurements |
|`legacyvariance = ["random" min max]`                    | selects variances uniformly at random within limits, applied over all phasor measurements |
|`legacyvariance = ["Pij" value "Qij" value "Iij" value "Pi" value "Qi" value "Vi" value "all" value]` | predefines variances over a given subset of phasor measurements[^2], to apply fixed-value variance over all, except for those individually defined use `"all" value`    |

!!! note "Variance"
    The function keeps measurement values and measurement variances as in the input DATA, and changes only measurement values and variances that are called using keywords. For example, if the keywords `pmuvariance` and `legacyvariance` are omitted, the function will retain the measurement values and variances as in the input data, allowing the same measurement values and variances, while changing the measurement sets.

    Further, the function accepts any subset of phasor[^1] or legacy[^2] measurements, consequently, it is not necessary to define attributes for all measurements, where keyword `"all"` generates measurement values according to defined variance for all measurements, except for those individually defined.   
    ```julia-repl
    julia> runmg("case14.h5"; legacyvariance = ["Pij" 1e-4 "all" 1e-5])
    ```
    The function applies variance value of 1e-5 over all legacy measurements, except for active power flow measurements which have variance equal to 1e-4, while measurement values and variances related with PMU remain the same as in the input DATA.

SAVE

| Command                 | Description                    |
|:------------------------|:-------------------------------|
|`save = "path/name.h5"`  | saves results in the h5-file   |
|`save = "path/name.xlsx"`| saves results in the xlsx-file |
---

## Input Data Structure
The function supports the `.h5` or `.xlsx` file extensions, with variables `pmuVoltage` and `pmuCurrents` associated with phasor measurements, and `legacyFlow`, `"legacyCurrent"`, `"legacyInjection"` and `"legacyVoltage"` associated with legacy measurements. Further, the function requires knowledge about a power system using variables `bus`, `branch`, `generator` and `"basePower"` variables.

The minimum amount of information within an instance of the data structure required to run the module requires one variable associated with measurements, `bus` and `branch` variables.

Next, we describe the structure of measurement variables involved in the input file, while variables associated with a power system are described in [Power Flow](@ref) section.

The `pmuVoltage` data structure

| Column   | Description        | Type                                    | Unit     |
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

| Column  | Description        | Type                                       | Unit     |
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

| Column  | Description        | Type                                 | Unit     |
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

| Column  | Description        | Type                                      | Unit     |
|:-------:|:-------------------|:------------------------------------------|:---------|
| 1       | branch number      | positive integer                          |          |
| 2       | from bus number    | positive integer                          |          |
| 3       | to bus number      | positive integer                          |          |
| 4       | measurement        | branch current magnitude                  | per-unit |
| 5       | variance           | branch current magnitude                  | per-unit |
| 6       | status             | branch current magnitude in/out-service   |          |
| 7       | exact              | optional column, branch current magnitude | per-unit |

The `legacyInjection` data structure

| Column   | Description        | Type                                      | Unit     |
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

| Column   | Description        | Type                                   | Unit     |
|:--------:|:-------------------|:---------------------------------------|:---------|	 
| 1        | bus number         | positive integer                       |          |
| 2        | measurement        | bus voltage magnitude                  | per-unit |
| 3        | variance           | bus voltage magnitude                  | per-unit |
| 4        | status             | bus voltage magnitude in/out-service   |          |
| 5        | exact              | optional column, bus voltage magnitude | per-unit |
---


!!! warning "Optional columns"
    The optional columns are mandatory when keywords `pmuvariance` and/or `legacyvariance` are used.  


!!! tip "How many"
    The input data needs not to contain a complete structure of measurement variables, and measurement data needs not to be consistent with the total number of buses and branches. Also, the function supports more than one same measurement per the same bus or branch.
---

## References
[1] A. Abur and A. Exposito, “Power System State Estimation: Theory and Implementation,” ser. Power Engineering. Taylor & Francis, 2004.

[2] B. Gou, “Optimal placement of PMUs by integer linear programming,” IEEE Trans. Power Syst., vol. 23, no. 3, pp. 1525–1526, Aug. 2008.
