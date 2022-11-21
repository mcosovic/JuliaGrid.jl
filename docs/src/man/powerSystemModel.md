# [Power System Model](@id powerSystemModel)

The JuliaGrid supports the main composite type `PowerSystem` to preserve power system data, with fields:
* `bus`
* `branch`
* `generator`
* `acModel`
* `dcModel`
* `basePower`.

The fields `bus`, `branch`, `generator` hold the data related with buses, branches and generators, respectively. Subtypes `acModel` and `dcModel` store vectors and matrices obtained based on the power system topology and parameters. The base power of the system is kept in the field `basePower`, given in volt-ampere unit.

The function `powerSystem()` returns the main composite type `PowerSystem` with all subtypes.

JuliaGrid supports three modes of forming the power system model:
* using built-in functions,
* using HDF5 file format,
* using [Matpower](https://matpower.org) case files.

Note that, in the case of large-scale systems, we strongly recommend to use the HDF5 file format for the input. Therefore, JuliaGrid has the function that any system loaded from Matpower case files or a system formed using built-in functions can be saved in the HDF5 format.

The HDF5 file format contains three groups: `bus`, `branch` and `generator`. In addition, the file contains `basePower` variable, given in volt-ampere. Each group is divided into subgroups that gather the same type of physical quantities, with the corresponding datasets. Note that, dataset names are identical to the keywords, which are used when the power system model is formed using built-in functions.

```@raw html
<hr style="border:1px solid #CBCDCD; opacity: 0.5">
```

## [Bus Group](@id busGroup)

The `bus` group is divided into four subgroups: `layout`, `demand`, `shunt`, and `voltage`. Each of the subgroups contains datasets that define features of the buses.

| Subgroup | Dataset      | Description                                                                           | Unit     | Type             |
|:---------|:-------------|:--------------------------------------------------------------------------------------|:---------|:-----------------|
| layout   | label        | unique bus label                                                                      | -        | positive integer |
| layout   | slackLabel   | bus label of the slack bus                                                            | -        | positive integer |
| layout   | lossZone     | loss zone                                                                             | -        | positive integer |
| layout   | area         | area number                                                                           | -        | positive integer |
| demand   | active       | active power demand                                                                   | per-unit | float            |
| demand   | reactive     | reactive power demand                                                                 | per-unit | float            |
| shunt    | conductance  | active power demanded of the shunt element at voltage magnitude equal to 1 per-unit   | per-unit | float            |
| shunt    | susceptance  | reactive power injected of the shunt element at voltage magnitude equal to 1 per-unit | per-unit | float            |
| voltage  | magnitude    | initial value of the voltage magnitude                                                | per-unit | float            |
| voltage  | angle        | initial value of the voltage angle                                                    | radian   | float            |
| voltage  | minMagnitude | minimum allowed voltage magnitude value                                               | per-unit | float            |
| voltage  | maxMagnitude | maximum allowed voltage magnitude value                                               | per-unit | float            |
| voltage  | base         | base value of the voltage magnitude                                                   | volt     | float            |


```@raw html
<hr style="border:1px solid #CBCDCD; opacity: 0.5">
```

## [Branch Group](@id branchGroup)

The `branch` group is divided into four subgroups: `layout`, `parameter`, `voltage`, and `rating`. Each of the subgroups contains datasets that define features of the branches.

| Subgroup  | Dataset            | Description                                                            | Unit      | Type            |
|:----------|:-------------------|:-----------------------------------------------------------------------|:----------|:----------------|
| layout    | label              | unique branch label                                                    | -        | positive integer |
| layout    | from               | from bus label (corresponds to the bus label)                          | -        | positive integer |
| layout    | to                 | to bus label (corresponds to the bus label)                            | -        | positive integer |
| layout    | status             | operating status of the branch, in-service = 1, out-of-service = 0     | -        | zero-one integer |
| parameter | resistance         | branch resistance                                                      | per-unit | float            |
| parameter | reactance          | branch reactance                                                       | per-unit | float            |
| parameter | susceptance        | total line charging susceptance                                        | per-unit | float            |
| parameter | turnsRatio         | transformer off-nominal turns ratio, equal to zero for a line          | -        | float            |
| parameter | shiftAngle         | transformer phase shift angle where positive value defines delay       | radian   | float            |
| voltage   | minAngleDifference | minimum allowed voltage angle difference value between from and to bus | radian   | float            |
| voltage   | maxAngleDifference | maximum allowed voltage angle difference value between from and to bus | radian   | float            |
| rating    | shortTerm          | short term rating (equal to zero for unlimited)                        | per-unit | float            |
| rating    | longTerm           | long term rating (equal to zero for unlimited)                         | per-unit | float            |
| rating    | emergency          | emergency rating (equal to zero for unlimited)                         | per-unit | positive integer |

```@raw html
<hr style="border:1px solid #CBCDCD; opacity: 0.5">
```

## [Generator Group](@id generatorGroup)

The `generator` group is divided into six subgroups: `layout`, `output`, `voltage`, `capability`, `ramRate`, and `cost`. Each of the subgroups contains datasets that define features of the generators.

| Subgroup   | Dataset             | Description                                                           | Unit            | Type             |
|:-----------|:--------------------|:----------------------------------------------------------------------|:----------------|:-----------------|
| layout     | label               | unique generator label                                                | -               | positive integer |
| layout     | bus                 | bus label to which the generator is connected                         | -               | positive integer |
| layout     | status              | operating status of the generator, in-service = 1, out-of-service = 0 | -               | zero-one integer |
| layout     | area                | area participation factor                                             | -               | float            |
| output     | active              | output active power of the generator                                  | per-unit        | float            |
| output     | reactive            | output reactive power of the generator                                | per-unit        | float            |
| voltage    | magnitude           | voltage magnitude setpoint                                            | per-unit        | float            |
| capability | minActive           | minimum allowed output active power value of the generator            | per-unit        | float            |
| capability | maxActive           | maximum allowed output active power value of the generator            | per-unit        | float            |
| capability | minReactive         | minimum allowed output reactive power value of the generator          | per-unit        | float            |
| capability | maxReactive         | maximum allowed output reactive power value of the generator          | per-unit        | float            |
| capability | lowerActive         | lower allowed active power output value of PQ capability curve        | per-unit        | float            |
| capability | minReactiveLower    | minimum allowed reactive power output value at lowerActive value      | per-unit        | float            |
| capability | maxReactiveLower    | maximum allowed reactive power output value at lowerActive value      | per-unit        | float            |
| capability | upperActive         | upper allowed active power output value of PQ capability curve        | per-unit        | float            |
| capability | minReactiveUpper    | minimum allowed reactive power output value at upperActive value      | per-unit        | float            |
| capability | maxReactiveUpper    | maximum allowed reactive power output value at upperActive value      | per-unit        | float            |
| rampRate   | loadFollowing       | ramp rate for load following/AGC                                      | per-unit/minute | float            |
| rampRate   | reserve10minute     | ramp rate for 10-minute reserves                                      | per-unit        | float            |
| rampRate   | reserve30minute     | ramp rate for 30-minute reserves                                      | per-unit        | float            |
| rampRate   | reactiveTimescale   | ramp rate for reactive power (two seconds timescale)                  | per-unit/minute | float            |
| cost       | activeModel         | active power cost model, piecewise linear = 1, polynomial = 2         |-                | one-two integer  |
| cost       | activeStartup       | active power startup cost                                             | currency        | float            |
| cost       | activeShutdown      | active power shutdown cost                                            | currency        | float            |
| cost       | activeDataPoint     | number of data points for active power cost model                     | -               | positive integer |
| cost       | activeCoefficient   | coefficients for forming the active power cost function               | (*)             | float            |
| cost       | reactiveModel       | reactive power cost model, piecewise linear = 1, polynomial = 2       |-                | one-two integer  |
| cost       | reactiveStartup     | reactive power startup cost                                           | currency        | float            |
| cost       | reactiveShutdown    | reactive power shutdown cost                                          | currency        | float            |
| cost       | reactiveDataPoint   | number of data points for reactive power cost model                   | -               | positive integer |
| cost       | reactiveCoefficient | coefficients for forming the reactive power cost function             | (*)             | float            |

---

The interpretation of the datasets activeCoefficient and reactiveCoefficient, given as matrices, depends on the activeModel and reactiveModel that is selected:
* piecewise linear cost model is defined according to input-output points, where the ``i``-th row of the matrix is given as:
  * activeCoefficient: ``[p_1, f(p_1), p_2, f(p_2), \dots, p_n, f(p_n)]``,
  * reactiveCoefficient: ``[q_1, f(q_1), q_2, f(q_2), \dots, q_n, f(q_n)]``.
* polynomial cost model is defined using the ``n``-th degree polynomial, where the ``i``-th row of the matrix is given as:
  * activeCoefficient: ``[a_n, \dots, a_1, a_0]`` to define ``f(p) = a_n p^n + \dots + a_1 p + a_0``,
  * reactiveCoefficient: ``[b_n, \dots, b_1, b_0]`` to define ``f(q) = b_n q^n + \dots + b_1 q + b_0``.
(*) Thus, for the piecewise linear model ``p_i`` and ``q_i`` are given in per-unit, while ``f(p_i)`` and ``f(q_i)`` have a dimension of currency/hour. In the polynomial model coefficients are dimensionless.