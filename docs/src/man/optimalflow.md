# [Optimal Power Flow](@id runopf)

JuliaGrid is based on common network elements and benefits the [unified branch model](@ref branchmodel) to perform the optimal power flow analysis. JuliaGrid supports only the optimal DC power flow model, which is obtained by linearisation of the non-linear model.

---

## Run Settings
Input arguments of the function `runopf()` describe the optimal power flow settings. The order of inputs and their appearance is arbitrary, with only DATA input required. Still, for the methodological reasons, the syntax examples follow a certain order.

#### Syntax
```julia-repl
runopf(DATA, METHOD)
runopf(DATA, METHOD, DISPLAY)
runopf(DATA, METHOD, DISPLAY; SAVE)
```
```@raw html
&nbsp;
```
#### Description
```julia-repl
runopf(DATA, METHOD) solves the optimal power flow problem
runopf(DATA, METHOD, DISPLAY) shows results in the terminal
runopf(DATA, METHOD, DISPLAY; SAVE) exports results
```
```@raw html
&nbsp;
```
#### Output
```julia-repl
results, system, info = runopf() returns results, power system and info data
```
```@raw html
&nbsp;
```
####  Examples
```julia-repl
results, system, info = runopf("case118.h5", "dc", "main", "flow", "generation")
```
```julia-repl
results, system, info = runopf("case14.h5", "dc"; save = "D:/case14results.xlsx")
```
```julia-repl
results, system, info = runopf("case14.m", "dc", "main")
```
---

## Variable Arguments
The optimal power flow function `runopf()` receives a group of variable number of arguments: DATA, METHOD and DISPLAY.

| DATA            | input power system data                                                     |
|:----------------|:----------------------------------------------------------------------------|
|                 |                                                                             |
| **Example**     | `"case14.h5"`                                                               |
| **Description** | loads the power system data using h5-file from the package                  |
|                 |                                                                             |
| **Example**     | `"case14.xlsx"`                                                             |
| **Description** |  loads the power system data using xlsx-file from the package               |
|                 |                                                                             |
| **Example**     | `"case14.m"`                                                                |
| **Description** | loads the power system data using Matpower m-file format from the package   |
|                 |                                                                             |
| **Example**     | `"C:/case14.h5"`                                                            |
| **Description** |  loads the power system data using h5-file from a custom path               |
|                 |                                                                             |
| **Example**     | `"C:/case14.xlsx"`                                                          |                                     
| **Description** |  loads the power system data using xlsx-file from a custom path             |
|                 |                                                                             |
| **Example**     | `"C:/case14.m"`                                                             |
| **Description** | loads the power system data using Matpower m-file format from a custom path |


```@raw html
&nbsp;
```

```@raw html
&nbsp;
```

| METHOD          | solves the optimal power flow problem                                                                             |
|:----------------|:------------------------------------------------------------------------------------------------------------------|
|                 |                                                                                                                   |
| **Command**     | `"dc"`                                                                                                            |
| **Description** |  runs the DC optimal power flow analysis                                                                          |

```@raw html
&nbsp;
```

| DISPLAY         | shows results in the terminal                     |
|:----------------|:--------------------------------------------------|
|                 |                                                   |
| **Command**     | `"main"`                                          |
| **Description** | shows main bus data display in the Julia REPL     |
|                 |                                                   |
| **Command**     | `"flow"`                                          |
| **Description** | shows power flow data display in the Julia REPL   |
|                 |                                                   |
| **Command**     | `"generation"`                                    |
| **Description** | shows generator data display in the Julia REPL    |

---

## Keyword Arguments
The optimal power flow function `runopf()` receives a argument by keyword SAVE.

| SAVE            | exports results                  |
|:----------------|:---------------------------------|
|                 |                                  |
| **Command**     | `save = "path/name.h5"`          |
| **Description** |  saves results in the h5-file    |
|                 |                                  |
| **Command**     | `save = "path/name.xlsx"`        |
| **Description** |  saves results in the xlsx-file  |

---

## Input Data Structure
The function supports two input types: `.h5` or `.xlsx` file extensions, where to describe a power system using the same input data structure as Matpower, except for the first column in the `branch` data. Note that, in the case of large-scale systems, we strongly recommend to use the `.h5` extension for the input as well as the output data.  

The minimum amount of information within an instance of the data structure required to run the module requires `bus`, `branch`, `generator` and `generatorcost` variables.

We advise the reader to read the section [Power System Data Structure](@ref powersysteminputdata) which provides the structure of the input DATA, with numerous examples given in the section [Use Cases](@ref usecases).

---

## Output Data Structure
The power flow function `runopf()` returns a struct variable `results` with fields `main`, `flow`, `generation` containing the optimal power flow analysis results. Further, the variable `system` contains the input data that describes the power system, while the variable `info` contains basic information about the power system.
```@raw html
&nbsp;
```
#### DC Optimal Power Flow
The `main` data structure contains results related to the bus.

| Column   | Description                                    | Unit |
|:--------:|:-----------------------------------------------|:-----| 	 
| 1        | bus number defined as positive integer         | -    |
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
| 1       | branch number defined as positive integer   | -    |
| 2       | from bus number defined as positive integer | -    |
| 3       | to bus number defined as positive integer   | -    |
| 4       | from bus active power flow                  | MW   |
| 5       | to bus active power flow                    | MW   |

```@raw html
&nbsp;
```
The `generation` data structure contains results related to the generator.

| Column   | Description                            | Unit |
|:--------:|:---------------------------------------|:-----| 	 
| 1        | bus number defined as positive integer | -    |
| 2        | active power generation                | MW   |
