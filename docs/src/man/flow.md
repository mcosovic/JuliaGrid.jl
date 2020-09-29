# [Power Flow](@id runpf)

JuliaGrid is based on common network elements and benefits the [unified branch model](@ref branchmodel) to perform the power flow analysis, which is used for defining load profiles, generator capabilities, voltage specification, contingency analysis, and planning.

To solve the AC power flow problem three different methods are available:
* [Gauss-Seidel](@ref gaussseidel),
* [Newton-Raphson](@ref newtonraphson),
* [fast Newton-Raphson](@ref fastnewtonraphson) with XB and BX schemes.

By default, the AC power flow methods solve the system of non-linear equations and reveal complex bus voltages ignoring any limits. However, JuliaGrid integrates generator reactive power limits in all available methods.

Besides the AC power flow, JuliaGrid supports the [DC power flow](@ref dcpowerflow) model, which is obtained by linearisation of the non-linear model.

---

## Run Settings
Input arguments of the function `runpf()` describe the power flow settings. The order of inputs and their appearance is arbitrary, with only DATA input required. Still, for the methodological reasons, the syntax examples follow a certain order.

#### Syntax
```julia-repl
runpf(DATA, METHOD)
runpf(DATA, METHOD, DISPLAY)
runpf(DATA, METHOD, DISPLAY; ACCONTROL)
runpf(DATA, METHOD, DISPLAY; ACCONTROL, SOLVE)
runpf(DATA, METHOD, DISPLAY; ACCONTROL, SOLVE, SAVE)
```
```@raw html
&nbsp;
```
#### Description
```julia-repl
runpf(DATA, METHOD) solves the power flow problem
runpf(DATA, METHOD, DISPLAY) shows results in the terminal
runpf(DATA, METHOD, DISPLAY; ACCONTROL) sets variables for the AC power flow
runpf(DATA, METHOD, DISPLAY; ACCONTROL, SOLVE) sets the linear system solver
runpf(DATA, METHOD, DISPLAY; ACCONTROL, SOLVE, SAVE) exports results
```
```@raw html
&nbsp;
```
#### Output
```julia-repl
results, system, info = runpf() returns results, power system and info data
```
```@raw html
&nbsp;
```
####  Examples
```julia-repl
results, system, info = runpf("case14.h5", "nr", "main", "flow", "generation")
```
```julia-repl
results, = runpf("case14.xlsx", "nr", "main"; max = 10, stop = 1.0e-8)
```
```julia-repl
results, = runpf("case14.h5", "gs", "main"; max = 500, stop = 1.0e-8, reactive = 1)
```
```julia-repl
results, = runpf("case14.h5", "dc"; solve = "lu", save = "D:/case14results.xlsx")
```
---

## Input Arguments
The power flow function `runpf()` receives a group of variable number of arguments: DATA, METHOD, DISPLAY, and group of arguments by keyword: ACCONTROL, SOLVE, SAVE.
```@raw html
&nbsp;
```

##### DATA - Variable Argument

| Example           | Description                                    |
|:------------------|:-----------------------------------------------|
|`"case14.h5"`      | loads the power system data from the package   |
|`"case14.xlsx"`    | loads the power system data from the package   |
|`"C:/case14.xlsx"` | loads the power system data from a custom path |

```@raw html
&nbsp;
```
##### METHOD - Variable Argument

| Command | Description
|:--------|:--------------------------------------------------------------------------------------|
|`"nr"`   | runs the AC power flow analysis using Newton-Raphson method, `default METHOD setting` |
|`"gs"`   | runs the AC power flow analysis using Gauss-Seidel method                             |
|`"fnrxb"`| runs the AC power flow analysis using XB fast Newton-Raphson method                   |
|`"fnrbx"`| runs the AC power flow analysis using BX fast Newton-Raphson method                   |
|`"dc"`   | runs the DC power flow analysis                                                       |

```@raw html
&nbsp;
```
##### DISPLAY - Variable Argument

| Command      | Description                    |
|:-------------|:-------------------------------|
|`"main"`      | shows main bus data display    |
|`"flow"`      | shows power flow data display  |
|`"generation"`| shows generator data display   |

```@raw html
&nbsp;
```
##### ACCONTROL - Keyword Argument

| Command      | Description                                                                              |
|:-------------|:-----------------------------------------------------------------------------------------|
|`max = value` | specifies the maximum number of iterations for the AC power flow, `default setting: 100` |
|`stop = value`| specifies the stopping criteria for the AC power flow, `default setting: 1.0e-8`         |
|`reactive = 1`| forces reactive power constraints, `default setting: 0`                                  |

```@raw html
&nbsp;
```
##### SOLVE - Keyword Argument

| Command            | Description                                            |
|:-------------------|:-------------------------------------------------------|
|`solve = "builtin"` | built-in linear system solver, `default SOLVE setting` |
|`solve = "lu"`      | LU linear system solver                                |

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
The function supports two input types: `.h5` or `.xlsx` file extensions, where to describe a power system using the same input data structure as Matpower, except for the first column in the `branch` data. Note that, in the case of large-scale systems, we strongly recommend to use the `.h5` extension for the input as well as the output data.  

The minimum amount of information within an instance of the data structure required to run the module requires `bus` and `branch` variables.

We advise the reader to read the section [Power System Data Structure](@ref powersysteminputdata) which provides the structure of the input DATA, with numerous examples given in the section [Use Cases](@ref usecases).

---

## Output Data Structure
The power flow function `runpf()` returns a struct variable `results` with fields `main`, `flow`, `generation` containing power flow analysis results, and the additional field `iterations` for the AC power flow. Further, the variable `system` contains the input data that describes the power system, while the variable `info` contains basic information about the power system.
```@raw html
&nbsp;
```
#### DC Power Flow
We define electrical quantities generated by the JuliaGrid in the section [DC Power Flow Analysis](@ref dcpfanalysis).

The `main` data structure contains results related to the bus.

| Column   | Description                                    | Unit |
|:--------:|:-----------------------------------------------|:-----| 	 
| 1        | bus number defined as positive integer         |      |
| 2        | voltage angle                                  | deg  |
| 3        | active power injection                         | MW   |
| 4        | active power generation                        | MW   |
| 5        | active power demand                            | MW   |
| 6        | active power consumed by the shunt conductance | MW   |

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
The `generation` data structure contains results related to the generator.

| Column   | Description                            | Unit |
|:--------:|:---------------------------------------|:-----| 	 
| 1        | bus number defined as positive integer |      |
| 2        | active power generation                | MW   |

```@raw html
&nbsp;
```

#### AC Power Flow
We define electrical quantities generated by the JuliaGrid in the section [AC Power Flow Analysis](@ref acpfanalysis).

The `main` data structure contains results related to the bus.

| Column   | Description                                      | Unit     |
|:--------:|:-------------------------------------------------|:---------| 	 
| 1        | bus number defined as positive integer           |          |
| 2        | voltage magnitude                                | per-unit |
| 3        | voltage angle                                    | deg      |
| 4        | active power injection                           | MW       |
| 5        | reactive power injection                         | MVAr     |
| 6        | active power generation                          | MW       |
| 7        | reactive power generation                        | MVAr     |
| 8        | active power demand                              | MW       |
| 9        | reactive power demand                            | MVAr     |
| 10       | active power consumed by the shunt conductance   | MW       |
| 11       | reactive power consumed by the shunt susceptance | MVAr     |

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
The `generation` data structure contains results related to the generator.

| Column   | Description                            | Unit |
|:--------:|:---------------------------------------|:-----| 	 
| 1        | bus number defined as positive integer |      |
| 2        | active power generation                | MW   |
| 3        | reactive power generation              | MVAr |

---

## Flowchart
The power flow flowchart depicts the algorithm process according to user settings.

![](../assets/powerflow_chart.svg)
