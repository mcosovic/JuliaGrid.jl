# [Power System Model](@id powerSystemModel)

The JuliaGrid supports the composite type `PowerSystem` to preserve power system data, with fields:
* `bus`
* `branch`
* `generator`
* `acModel`
* `dcModel`
* `basePower`.

The function [`powerSystem()`](@ref powerSystem) returns the composite type `PowerSystem` with all fields. The fields `bus`, `branch`, and `generator` hold the data related to buses, branches and generators, respectively. Fields `acModel` and `dcModel` store vectors and matrices obtained based on the power system topology and parameters. The base power of the system is kept in the field `basePower`, given in the volt-ampere unit. JuliaGrid supports three modes to build the composite type `PowerSystem`:
* using built-in functions,
* using HDF5 file format,
* using [Matpower](https://matpower.org) case files.

Note that, in the case of large-scale systems, we strongly recommend to use the HDF5 file format for the input. Therefore, JuliaGrid has the function [`savePowerSystem()`](@ref savePowerSystem) that any system loaded from Matpower case files or a system formed using built-in functions can be saved in the HDF5 format.

The HDF5 file format contains three groups: `bus`, `branch` and `generator`. In addition, the file contains `basePower` variable, given in volt-ampere. Each group is divided into subgroups that gather the same type of physical quantities, with the corresponding datasets. Note that, dataset names are identical to the keywords, which are used when the power system model is formed using built-in functions.

---

## [Bus Group](@id busGroup)

The `bus` group is divided into four subgroups: `layout`, `demand`, `shunt`, and `voltage`. Each of the subgroups contains datasets that define the features of the buses.

| Subgroup | Dataset      | Description                                                                           | Type             | Unit     |
|:---------|:-------------|:--------------------------------------------------------------------------------------|:-----------------|:---------|
| layout   | label        | unique bus label                                                                      | positive integer | -        |
| layout   | slackLabel   | bus label of the slack bus                                                            | positive integer | -        |
| layout   | lossZone     | loss zone                                                                             | positive integer | -        |
| layout   | area         | area number                                                                           | positive integer | -        |
| demand   | active       | active power demand                                                                   | float            | per-unit |
| demand   | reactive     | reactive power demand                                                                 | float            | per-unit |
| shunt    | conductance  | active power demanded of the shunt element at voltage magnitude equal to 1 per-unit   | float            | per-unit |
| shunt    | susceptance  | reactive power injected of the shunt element at voltage magnitude equal to 1 per-unit | float            | per-unit |
| voltage  | magnitude    | initial value of the voltage magnitude                                                | float            | per-unit |
| voltage  | angle        | initial value of the voltage angle                                                    | float            | radian   |
| voltage  | minMagnitude | minimum allowed voltage magnitude value                                               | float            | per-unit |
| voltage  | maxMagnitude | maximum allowed voltage magnitude value                                               | float            | per-unit |
| voltage  | base         | base value of the voltage magnitude                                                   | float            | volt     |


---

## [Branch Group](@id branchGroup)

The `branch` group is divided into four subgroups: `layout`, `parameter`, `voltage`, and `rating`. Each of the subgroups contains datasets that define the features of the branches.

| Subgroup  | Dataset            | Description                                                            | Type             | Unit     |
|:----------|:-------------------|:-----------------------------------------------------------------------|:-----------------|:---------|
| layout    | label              | unique branch label                                                    | positive integer | -        |
| layout    | from               | from bus label (corresponds to the bus label)                          | positive integer | -        |
| layout    | to                 | to bus label (corresponds to the bus label)                            | positive integer | -        |
| layout    | status             | operating status of the branch, in-service = 1, out-of-service = 0     | zero-one integer | -        |
| parameter | resistance         | branch resistance                                                      | float            | per-unit |
| parameter | reactance          | branch reactance                                                       | float            | per-unit |
| parameter | susceptance        | total line charging susceptance                                        | float            | per-unit |
| parameter | turnsRatio         | transformer off-nominal turns ratio, equal to zero for a line          | float            | -        |
| parameter | shiftAngle         | transformer phase shift angle where positive value defines delay       | float            | radian   |
| voltage   | minAngleDifference | minimum allowed voltage angle difference value between from and to bus | float            | radian   |
| voltage   | maxAngleDifference | maximum allowed voltage angle difference value between from and to bus | float            | radian   |
| rating    | shortTerm          | short-term rating (equal to zero for unlimited)                        | float            | per-unit |
| rating    | longTerm           | long-term rating (equal to zero for unlimited)                         | float            | per-unit |
| rating    | emergency          | emergency rating (equal to zero for unlimited)                         | positive integer | per-unit |

---

## [Generator Group](@id generatorGroup)

The `generator` group is divided into six subgroups: `layout`, `output`, `voltage`, `capability`, `ramRate`, and `cost`. Each of the subgroups contains datasets that define the features of the generators.

| Subgroup   | Dataset             | Description                                                           | Type             | Unit            |
|:-----------|:--------------------|:----------------------------------------------------------------------|:-----------------|:----------------|
| layout     | label               | unique generator label                                                | positive integer | -               |
| layout     | bus                 | bus label to which the generator is connected                         | positive integer | -               |
| layout     | status              | operating status of the generator, in-service = 1, out-of-service = 0 | zero-one integer | -               |
| layout     | area                | area participation factor                                             | float            | -               |
| output     | active              | output active power of the generator                                  | float            | per-unit        |
| output     | reactive            | output reactive power of the generator                                | float            | per-unit        |
| voltage    | magnitude           | voltage magnitude setpoint                                            | float            | per-unit        |
| capability | minActive           | minimum allowed output active power value of the generator            | float            | per-unit        |
| capability | maxActive           | maximum allowed output active power value of the generator            | float            | per-unit        |
| capability | minReactive         | minimum allowed output reactive power value of the generator          | float            | per-unit        |
| capability | maxReactive         | maximum allowed output reactive power value of the generator          | float            | per-unit        |
| capability | lowerActive         | lower allowed active power output value of PQ capability curve        | float            | per-unit        |
| capability | minReactiveLower    | minimum allowed reactive power output value at lowerActive value      | float            | per-unit        |
| capability | maxReactiveLower    | maximum allowed reactive power output value at lowerActive value      | float            | per-unit        |
| capability | upperActive         | upper allowed active power output value of PQ capability curve        | float            | per-unit        |
| capability | minReactiveUpper    | minimum allowed reactive power output value at upperActive value      | float            | per-unit        |
| capability | maxReactiveUpper    | maximum allowed reactive power output value at upperActive value      | float            | per-unit        |
| rampRate   | loadFollowing       | ramp rate for load following/AGC                                      | float            | per-unit/minute |
| rampRate   | reserve10minute     | ramp rate for 10-minute reserves                                      | float            | per-unit        |
| rampRate   | reserve30minute     | ramp rate for 30-minute reserves                                      | float            | per-unit        |
| rampRate   | reactiveTimescale   | ramp rate for reactive power (two seconds timescale)                  | float            | per-unit/minute |
| cost       | activeModel         | active power cost model, piecewise linear = 1, polynomial = 2         | one-two integer  | -               |
| cost       | activeStartup       | active power startup cost                                             | float            | currency        |
| cost       | activeShutdown      | active power shutdown cost                                            | float            | currency        |
| cost       | activeDataPoint     | number of data points for active power cost model                     | positive integer | -               |
| cost       | activeCoefficient   | coefficients for forming the active power cost function               | float array      | (*)             |
| cost       | reactiveModel       | reactive power cost model, piecewise linear = 1, polynomial = 2       | one-two integer  | -               |
| cost       | reactiveStartup     | reactive power startup cost                                           | float            | currency        |
| cost       | reactiveShutdown    | reactive power shutdown cost                                          | float            | currency        |
| cost       | reactiveDataPoint   | number of data points for reactive power cost model                   | positive integer | -               |
| cost       | reactiveCoefficient | coefficients for forming the reactive power cost function             | float array      | (*)             |

```@raw html
&nbsp;
```

The interpretation of the datasets activeCoefficient and reactiveCoefficient, given as matrices, depends on the activeModel and reactiveModel that is selected:
* piecewise linear cost model is defined according to input-output points, where the ``i``-th row of the matrix is given as:
  * activeCoefficient: ``[p_1, f(p_1), p_2, f(p_2), \dots, p_n, f(p_n)]``,
  * reactiveCoefficient: ``[q_1, f(q_1), q_2, f(q_2), \dots, q_n, f(q_n)]``.
* polynomial cost model is defined using the ``n``-th degree polynomial, where the ``i``-th row of the matrix is given as:
  * activeCoefficient: ``[a_n, \dots, a_1, a_0]`` to define ``f(p) = a_n p^n + \dots + a_1 p + a_0``,
  * reactiveCoefficient: ``[b_n, \dots, b_1, b_0]`` to define ``f(q) = b_n q^n + \dots + b_1 q + b_0``.
(*) Thus, for the piecewise linear model ``p_i`` and ``q_i`` are given in per-unit, while ``f(p_i)`` and ``f(q_i)`` have a dimension of currency/hour. In the polynomial model, coefficients are dimensionless.
