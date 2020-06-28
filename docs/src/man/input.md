# [Input Data](@id inputdata)

JuliaGrid supports two input types: `.h5` or `.xlsx` file extensions, where to describe a power system using the same input data structure as Matpower, except for the first column in the `branch` data. Note that, in the case of large-scale systems, we strongly recommend to use the `.h5` extension for the input as well as the output data.   

To generate the power system input data in the `.h5` format, we provide two scripts:
* convert the Matpower input data file: [MATLAB script](https://github.com/mcosovic/JuliaGrid.jl/tree/master/src/extras/matpower_to_hdf5.m);
* convert a custom user input data: [Julia script](https://github.com/mcosovic/JuliaGrid.jl/tree/master/src/extras/julia_to_hdf5.jl).

---

## [Power System Data Structure](@id powersysteminputdata)
The basic input data structure used to describe a power system consists of variables `bus`, `branch`, `generator`, `generatorcost`, and `basePower`. We define the system base power in MVA using `basePower` variable. Next, we describe the structure of other variables involved in the input data.

**The `bus` input data** is used for all analysis available in the JuliaGrid package. Each row in the `bus` data describes a corresponding bus, where bus numbers can take arbitrary positive integer values. However, for large-scale power systems, we strongly recommend using an ordered set of ascending positive integer values to label buses.

| Column   | Description                                                                           | Unit      |
|:--------:|:--------------------------------------------------------------------------------------|:----------| 	 
| 1        | bus number defined as positive integer                                                |           |
| 2        | bus type where PQ = 1, PV = 2, slack = 3                                              |           |
| 3        | active power demand                                                                   | MW        |
| 4        | reactive power demand                                                                 | MVAr      |
| 5        | shunt conductance as active power demand at voltage magnitude equal to one per-unit   | MW        |
| 6        | shunt susceptance as reactive power demand at voltage magnitude equal to one per-unit | MVAr      |
| 7        | area number defined as positive integer                                               |           |
| 8        | initial voltage magnitude                                                             | per-unit  |
| 9        | initial voltage angle                                                                 | deg       |
| 10       | base voltage magnitude                                                                | kV        |
| 11       | loss zone defined as positive integer                                                 |           |
| 12       | minimum voltage magnitude                                                             | per-unit  |
| 13       | maximum voltage magnitude                                                             | per-unit  |

```@raw html
&nbsp;
```

**The `branch` input data** is also used for all analysis available in the JuliaGrid package, where each row in the `branch` data describes a corresponding branch. The branch number can take arbitrary positive integer values, but we recommend to use an ordered set of ascending positive integer values. Note that, ''from bus'' and ''to bus'' positive integers must be harmonized with the bus numbers defined in the `bus` data.

| Column  | Description                                                      | Unit     |
|:-------:|:-----------------------------------------------------------------|:---------|
| 1       | branch number defined as positive integer                        |          |
| 2       | from bus number defined as positive integer                      |          |
| 3       | to bus number defined as positive integer                        |          |
| 4       | series resistance                                                | per-unit |
| 5       | series reactance                                                 | per-unit |
| 6       | total line charging susceptance                                  | per-unit |
| 7       | long term rating (equal to zero for unlimited)                   | MVA      |
| 8       | short term rating (equal to zero for unlimited)                  | MVA      |
| 9       | emergency rating (equal to zero for unlimited)                   | MVA      |
| 10      | transformer off-nominal turns ratio, equal to zero for a line    |          |
| 11      | transformer phase shift angle where positive value defines delay | deg      |
| 12      | status where in-service = 1, out-of-service = 0                  |          |
| 13      | minimum voltage angle difference between from and to buses       | deg      |
| 14      | maximum voltage angle difference between from and to buses       | deg      |

```@raw html
&nbsp;
```

**The `generator` input data** is mandatory only for the optimal power flow routines, where each row in the `generator` data describes a corresponding generator. Also, bus numbers in the `generator` data must be harmonized with bus numbers in the `bus` data, where each bus can contain any number of generators.

| Column   | Description                                           | Unit     |
|:--------:|:------------------------------------------------------|:---------| 	 
| 1        | bus number defined as positive integer                |          |
| 2        | active power generation                               | MW       |
| 3        | reactive power generation                             | MVAr     |
| 4        | maximum reactive power generation                     | MVAr     |
| 5        | minimum reactive power generation                     | MVAr     |
| 6        | voltage magnitude setpoint                            | per-unit |
| 7        | base power                                            | MVA      |
| 8        | status where in-service = 1, out-of-service = 0       |          |
| 9        | maximum active power generation                       | MW       |
| 10       | minimum active power generation                       | MW       |
| 11       | lower active power output of PQ capability curve      | MW       |
| 12       | upper active power output of PQ capability curve      | MW       |
| 13       | minimum reactive power output at PC1                  | MVAr     |
| 14       | maximum reactive power output at PC1                  | MVAr     |
| 15       | minimum reactive power output at PC2                  | MVAr     |
| 16       | maximum reactive power output at PC2                  | MVAr     |
| 17       | ramp rate for load following/AGC                      | MW/min   |
| 18       | ramp rate for 10-minute reserves                      | MW       |
| 19       | ramp rate for 30-minute reserves                      | MW       |
| 20       | ramp rate for reactive power (two seconds timescale)  | MVAr/min |
| 21       | area participation factor defined as positive integer |          |

```@raw html
&nbsp;
```

**The `generatorcost` input data** is also mandatory only for the optimal power flow routines. The number of `generatorcost` rows ``n_{\text{\text{gc}}}`` must be harmonized with number of `generator` rows ``n_\text{g}``, as follows:
* if ``n_{\text{gc}} = n_\text{g}``, then each row in the `generatorcost` contains active power costs produced by the corresponding generator in the `generator` data;
* if ``n_{\text{gc}} = 2n_\text{g}``, then the first ``n_\text{g}`` rows in the `generatorcost` contain active power costs produced by the corresponding generator in the `generator` data, and next ``n_\text{g}`` rows (i.e., ``n_\text{g} + 1`` through ``2n_\text{g}``) in the `generatorcost` contains reactive power costs produced by the corresponding generator in the `generator` data.  

JuliaGrid supports piecewise linear and polynomial generator cost functions:
* piecewise linear cost function is defined according to input-output points:
  * active power: ``(P_{\text{min}}, f(P_{\text{min}}))``, ``\dots``, ``(P_{\text{max}}, f(P_{\text{max}}))``;
  * reactive power: ``(Q_{\text{min}}, f(Q_{\text{min}}))``, ``\dots``, ``(Q_{\text{max}}, f(Q_{\text{max}}))``;  
* polynomial cost functions is defined using the ``n``-th degree polynomial:
  * active power: ``f(P) = a_nP^n + \dots + a_1P + a_0``;  
  * reactive power: ``f(Q) = b_nQ^n + \dots + b_1Q + b_0``.

| Column   | Description                                                                                                 | Unit     |
|:--------:|:------------------------------------------------------------------------------------------------------------|:---------|
| 1        | active or reactive power cost model defined as piecewise linear = 1, polynomial = 2                         |          |
| 2        | active or reactive power startup cost                                                                       | currency |
| 3        | active or reactive power shutdown cost                                                                      | currency |
| 4        | number of data points for a piecewise linear cost function, or coefficients for a polynomial cost function  |          |

If the piecewise linear cost function is selected, then:

| Column   | Description                                                                                                 | Unit        |
|:--------:|:------------------------------------------------------------------------------------------------------------|:------------|
| 5        | active output power ``P_{\text{min}}`` or reactive output power ``Q_{\text{min}}``                          | MW or MVAr  |
| 6        | active input power  ``f(P_{\text{min}}) `` or reactive input power  ``f(Q_{\text{min}}) ``                  | currency/hr |
| ...      |                                                                                                             |             |
| n-1      | active output power ``P_{\text{max}}`` or reactive output power ``Q_{\text{max}}``                          | MW or MVAr  |
| n        | active input power  ``f(P_{\text{max}}) `` or reactive input power  ``f(Q_{\text{max}}) ``                  | currency/hr |

If the polynomial cost function is selected, then:

| Column   | Description                                                                                                 | Unit     |
|:--------:|:------------------------------------------------------------------------------------------------------------|:---------|
| 5        | active power cost function coefficient  ``a_n`` or reactive power cost function coefficient  ``b_n``        |          |
| ...      |                                                                                                             |          |
| n-1      | active power cost function coefficient  ``a_1`` or reactive power cost function coefficient  ``b_1``        |          |
| n        | active power cost function coefficient  ``a_0`` or reactive power cost function coefficient  ``b_0``        |          |

---

## [Measurement Data Structure](@id measurementinputdata)
The measurement input data structure consists of variables `pmuVoltage` and `pmuCurrent` associated with phasor measurements, and `legacyFlow`, `legacyCurrent`, `legacyInjection` and `legacyVoltage` associated with legacy measurements.

In general, the measurement input data is used for the state estimation routines and measurement generator, where each measurement set needs not to be consistent with the total number of buses and branches. Also, JuliaGrid supports more than one measurement of the same type per bus or branch.

When the corresponding measurement is defined, then a bus number or branch number must be harmonized with a bus number or branch number in the `bus` and `branch` input data. Next, we describe the structure of measurement variables included in the input data file.


**The `pmuVoltage` data structure** describes bus voltage phasor measurements, where voltage phasors are measured in the polar coordinate system. The optional column PMU number is used only by the measurement generator function `runmg()`, and it is useful if several PMUs exist on a single bus.

| Column   | Description                                                                      | Unit     |
|:--------:|:---------------------------------------------------------------------------------|:---------| 	 
| 1        | bus number defined as positive integer                                           |          |
| 2        | voltage magnitude measurement value                                              | per-unit |
| 3        | voltage magnitude measurement variance                                           | per-unit |
| 4        | voltage magnitude measurement status where in-service = 1, out-of-service = 0    |          |
| 5        | bus voltage angle measurement value                                              | radian   |
| 6        | bus voltage angle measurement variance                                           | radian   |
| 7        | voltage angle measurement status where in-service = 1, out-of-service = 0        |          |
| 8        | voltage magnitude exact value, optional column for the state estimation          | per-unit |
| 9        | voltage angle exact value, optional column for the state estimation              | radian   |
| 10       | PMU number defined as positive integer, optional column for the state estimation |          |

```@raw html
&nbsp;
```

**The `pmuCurrent` data structure** describes branch current phasor measurements, where current phasors are measured in the polar coordinate system. Here, each PMU number should be harmonized with PMU numbers in the variable `pmuVoltage`.

| Column  | Description                                                                      | Unit     |
|:-------:|:---------------------------------------------------------------------------------|:---------| 	 
| 1       | branch number defined as positive integer                                        |          |
| 2       | from bus number defined as positive integer                                      |          |
| 3       | to bus number defined as positive integer                                        |          |
| 4       | current magnitude measurement value                                              | per-unit |
| 5       | current magnitude measurement variance                                           | per-unit |
| 6       | current magnitude measurement status where in-service = 1, out-of-service = 0    |          |
| 7       | current angle measurement value                                                  | radian   |
| 8       | current angle measurement variance                                               | radian   |
| 9       | current angle measurement status where in-service = 1, out-of-service = 0        |          |
| 10      | current magnitude exact value, optional column for the state estimation          | per-unit |
| 11      | current angle exact value, optional column for the state estimation              | radian   |
| 12      | PMU number defined as positive integer, optional column for the state estimation |          |

```@raw html
&nbsp;
```

**The `legacyFlow` data structure** describes active and reactive power flow measurements.

| Column  | Description                                                                      | Unit     |
|:-------:|:---------------------------------------------------------------------------------|:---------| 	 
| 1       | branch number defined as positive integer                                        |          |
| 2       | from bus number defined as positive integer                                      |          |
| 3       | to bus number defined as positive integer                                        |          |
| 4       | active power flow measurement value                                              | per-unit |
| 5       | active power flow measurement variance                                           | per-unit |
| 6       | active power flow measurement status where in-service = 1, out-of-service = 0    |          |
| 7       | reactive power flow measurement value                                            | per-unit |
| 8       | reactive power flow measurement variance                                         | per-unit |
| 9       | reactive power flow measurement status where in-service = 1, out-of-service = 0  |          |
| 10      | active power flow exact value, optional column for the state estimation          | per-unit |
| 11      | reactive power flow exact value, optional column for the state estimation        | per-unit |

```@raw html
&nbsp;
```

**The `legacyCurrent` data structure** describes branch current magnitude measurements.

| Column  | Description                                                                    | Unit     |
|:-------:|:-------------------------------------------------------------------------------|:---------| 	 
| 1       | branch number defined as positive integer                                      |          |
| 2       | from bus number defined as positive integer                                    |          |
| 3       | to bus number defined as positive integer                                      |          |
| 4       | current magnitude measurement value                                            | per-unit |
| 5       | current magnitude measurement variance                                         | per-unit |
| 6       | current magnitude measurement status where in-service = 1, out-of-service = 0  |          |
| 7       | current magnitude exact value, optional column for the state estimation        | per-unit |

```@raw html
&nbsp;
```

**The `legacyInjection` data structure** describes bus active and reactive injection measurements.

| Column   | Description                                                                          | Unit     |
|:--------:|:-------------------------------------------------------------------------------------|:---------| 	 
| 1        | bus number defined as positive integer                                               |          |
| 2        | active power injection measurement value                                             | per-unit |
| 3        | active power injection measurement variance                                          | per-unit |
| 4        | active power injection measurement status where in-service = 1, out-of-service = 0   |          |
| 5        | reactive power injection measurement value                                           | per-unit |
| 6        | reactive power injection measurement variance                                        | per-unit |
| 7        | reactive power injection measurement status where in-service = 1, out-of-service = 0 |          |
| 8        | active power injection exact value, optional column for the state estimation         | per-unit |
| 9        | reactive power injection exact value, optional column for the state estimation       | per-unit |

```@raw html
&nbsp;
```

**The `pmuVoltage` data structure** describes bus voltage magnitude measurements.

| Column   | Description                                                                   | Unit     |
|:--------:|:------------------------------------------------------------------------------|:---------| 	 
| 1        | bus number defined as positive integer                                        |          |
| 2        | voltage magnitude measurement value                                           | per-unit |
| 3        | voltage magnitude measurement variance                                        | per-unit |
| 4        | voltage magnitude measurement status where in-service = 1, out-of-service = 0 |          |
| 5        | voltage magnitude exact value, optional column for the state estimation       | per-unit |

---

## [Use Cases](@id usecases)

The pre-defined power system data are located in the `src/data` as the `.h5` or `.xlsx` files.

| Case             | Grid         | Bus   | Shunt  | Generator  | Branch  |
|:-----------------|:-------------|------:|-------:|-----------:|--------:|
| case3            | transmission | 3     | 0      | 1          | 3       |
| case5            | transmission | 5     | 0      | 5          | 6       |
| case5nptel       | transmission | 5     | 0      | 1          | 7       |
| case6            | transmission | 6     | 0      | 2          | 7       |
| case6wood        | transmission | 6     | 0      | 3          | 11      |
| case9            | transmission | 9     | 0      | 3          | 9       |
| case14           | transmission | 14    | 1      | 5          | 20      |
| case_ieee30      | transmission | 30    | 2      | 6          | 41      |
| case30           | transmission | 30    | 2      | 15         | 45      |
| case47           | distribution | 47    | 4      | 5          | 46      |
| case84           | distribution | 84    | 0      | 0          | 96      |
| case118          | transmission | 118   | 14     | 54         | 186     |
| case300          | transmission | 300   | 29     | 69         | 411     |
| case1354pegase   | transmission | 1354  | 1082   | 260        | 1991    |
| case_ACTIVSg2000 | transmission | 2000  | 149    | 544        | 3206    |
| case_ACTIVSg10k  | transmission | 10000 | 281    | 2485       | 12706   |
| case_ACTIVSg70k  | transmission | 70000 | 3477   | 10390      | 88207   |

```@raw html
&nbsp;
```
The pre-defined power system and measurement data are located in the `src/data` as the `.h5` or `.xlsx` files.

| Case             | Grid         | Bus   | Shunt  | Generator  | Branch  | Phasor Measurement | Legacy Measurement |
|:-----------------|:-------------|------:|-------:|-----------:|--------:|-------------------:|-------------------:|
| case14se         | transmission | 14    | 1      | 5          | 20      | 70                 | 81                 |
| case30se         | transmission | 30    | 2      | 15         | 45      | 72                 | 206                |
