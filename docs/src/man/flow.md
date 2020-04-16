# Power Flow

The function runs the AC and DC power flow analysis, where reactive power constraints can be used for the AC power flow analysis.

The AC power flow analysis includes four different algorithms:
 - Newton-Raphson,
 - Gauss-Seidel,
 - XB fast decoupled Newton-Raphson,
 - BX fast decoupled Newton-Raphson.

## The Data Structure

The JuliaGrid works with **h5** or **xlsx** extensions as input files, with variables `bus`, `generator`, `branch`, and `basePower`. JuliaGrid is using the same data format as Matpower, with the exception of the first column in the `branch` data.

The minimum amount of information within an instance of the data structure required to run the module requires a `bus` and `branch` data.

First, the system base power is defined in (MVA) using `basePower`, and in the following, we describe the structure of other variables involved in the input file.

The bus data structure:

| Column   | Description        | Type                    | Unit      |
|:--------:|:-------------------|:------------------------|:----------|
| 1        | bus number         | positive integer        |           |
| 2        | bus type           | pq(1), pv(2), slack(3)  |           |
| 3        | demand             | active power            | MW        |
| 4        | demand             | reactive power          | MVAr      |
| 5        | shunt conductance  | active power            | MW        |
| 6        | shunt susceptance  | reactive power          | MVAr      |
| 7        | area               | positive integer        |           |
| 8        | initial voltage    | magnitude               | per-unit  |
| 9        | initial voltage    | angle                   | deg       |
| 10       | base voltage       | magnitude               | kV        |
| 11       | loss zone          | positive integer        |           |
| 12       | minimum voltage    | magnitude               | per-unit  |
| 13       | maximum voltage    | magnitude               | per-unit  |


The generator data structure:

| Column   | Description        | Type                     | Unit     |
|:--------:|:-------------------|:-------------------------|:---------|
| 1        | bus number         | positive integer         |          |
| 2        | generation         | active power             | MW       |
| 3        | generation         | reactive power           | MVAr     |
| 4        | maximum generation | reactive power           | MVAr     |
| 5        | minimum generation | reactive power           | MVAr     |
| 6        | voltage            | magnitude                | per-unit |
| 7        | base               | power                    | MVA      |
| 8        | status             | positive integer         |          |
| 9        | maximum generation | active power             | MW       |
| 10       | minimum generation | active power             | MW       |
| 11       | lower of pq curve  | active power             | MW       |
| 12       | upper of pq curve  | active power             | MW       |
| 13       | minimum at pc1     | reactive power           | MVAr     |
| 14       | maximum at pc1     | reactive power           | MVAr     |
| 15       | minimum at pc2     | reactive power           | MVAr     |
| 16       | maximum at pc2     | reactive power           | MVAr     |
| 17       | ramp rate acg      | active power per minut   | MW/min   |
| 18       | ramp rate 10       | active power             | MW       |
| 19       | ramp rate 30       | active power             | MW       |
| 20       | ramp rate Q        | reactive power per minut | MVAr/min |
| 21       | area factor        | positive integer         |          |

The branch data structure:

| Column  | Description                | Type             | Unit     |
|:-------:|:---------------------------|:-----------------|:---------|
| 1       | branch number              | positive integer |          |
| 2       | from bus number            | positive integer |          |
| 3       | to bus number              | positive integer |          |
| 4       | series parameter           | resistance       | per-unit |
| 5       | series parameter           | reactance        | per-unit |
| 6       | charging parameter         | susceptance      | per-unit |
| 7       | long term rate             | power            | MVA      |
| 8       | short term rate            | power            | MVA      |
| 9       | emergency rate             | power            | MVA      |
| 10      | transformer                | turns ratio      |          |
| 11      | transformer                | shift angle      | deg      |
| 12      | status                     | positive integer |          |
| 13      | minimum voltage difference | angle            | deg      |
| 14      | maximum voltage difference | angle            | deg      |


## Use Cases

The predefined cases are located in the `src/data` as the **h5-file** or **xlsx-file**.

| Case             | Grid         | Buses | Shunts | Generators | Branches |
|:-----------------|:-------------|------:|-------:|-----------:|---------:|
| case3            | transmission | 3     | 0      | 1          | 3        |
| case5            | transmission | 5     | 0      | 5          | 6        |
| case5nptel       | transmission | 5     | 0      | 1          | 7        |
| case6            | transmission | 6     | 0      | 2          | 7        |
| case6wood        | transmission | 6     | 0      | 3          | 11       |
| case9            | transmission | 9     | 0      | 3          | 9        |
| case14           | transmission | 14    | 1      | 5          | 20       |
| case_ieee30      | transmission | 30    | 2      | 6          | 41       |
| case30           | transmission | 30    | 2      | 15         | 45       |
| case47           | distribution | 47    | 4      | 5          | 46       |
| case84           | distribution | 84    | 0      | 0          | 96       |
| case118          | transmission | 118   | 14     | 54         | 186      |
| case300          | transmission | 300   | 29     | 69         | 411      |
| case1354pegase   | transmission | 1354  | 1082   | 260        | 1991     |
| case_ACTIVSg2000 | transmission | 2000  | 149    | 544        | 3206     |
| case_ACTIVSg10k  | transmission | 10000 | 281    | 2485       | 12706    |
| case_ACTIVSg70k  | transmission | 70000 | 3477   | 10390      | 88207    |


## Run Settings

The power flow settings should be given as input arguments of the function `runpf`. Although the syntax is given in a certain order, for methodological reasons, only ``DATA`` must appear, and the order of other inputs is arbitrary, as well as their appearance.


### Syntax
```
runpf(DATA, METHOD);
runpf(DATA, METHOD, DISPLAY);
runpf(DATA, METHOD, DISPLAY; ACCONTROL);
runpf(DATA, METHOD, DISPLAY; ACCONTROL, SOLVE);
runpf(DATA, METHOD, DISPLAY; ACCONTROL, SOLVE, SAVE);
```

### Description
```
runpf(DATA, METHOD) computes power flow problem
runpf(DATA, METHOD, DISPLAY) shows results in the terminal
runpf(DATA, METHOD, DISPLAY; ACCONTROL) sets variables for the AC power flow
runpf(DATA, METHOD, DISPLAY; ACCONTROL, SOLVE) sets the linear system solver
runpf(DATA, METHOD, DISPLAY; ACCONTROL, SOLVE, SAVE) exports results
```

### Output
```
bus, branch, generator = runpf(...) returns results of the power flow analysis
```

###  Examples
```julia-repl
julia> runpf("case14.h5", "nr", "main", "flow", "generator");
julia> runpf("case14.xlsx", "nr", "main"; max = 10, stop = 1.0e-8);
julia> runpf("case14.h5", "gs", "main"; max = 500, stop = 1.0e-8, reactive = 1);
julia> runpf("case14.h5", "dc", "main"; solve = "lu", save = "D:/case14results.xlsx");
```


### Input Variable Number of Arguments

DATA

| Example           | Description                                    |
|:------------------|:-----------------------------------------------|
|`"case14.h5"`      | loads the power system data from the package   |
|`"case14.xlsx"`    | loads the power system data from the package   |
|`"C:/case14.xlsx"` | loads the power system data from a custom path |


METHOD

  | Command | Description
  |:--------|:-----------------------------------------------------------------------|
  |`"nr"`   | runs the AC power flow analysis using Newton-Raphson algorithm         |
  |`"gs"`   | runs the AC power flow analysis using Gauss-Seidel algorithm           |
  |`"fnrxb"`| runs the AC power flow analysis using XB fast Newton-Raphson algorithm |
  |`"fnrbx"`| runs the AC power flow analysis using BX fast Newton-Raphson algorithm |
  |`"dc"`   | runs the DC power flow analysis                                        |


 DISPLAY

  | Command | Description
  | --- | --- |
  |`"main"`| shows main bus data display
  |`"flow"`| shows power flow data display
  |`"generator"`| shows generator data display

### Input Keyword Arguments

 ACCONTROL

  | Command | Description
  | --- | --- |
  |`max = value`| specifies the maximum number of iterations for the AC power flow <br>  `default setting: 100`
  |`stop = value`| specifies the stopping criteria for the AC power flow <br> `default setting: 1.0e-8`
  |`reactive = 1`| forces reactive power constraints <br>  `default setting: 0`


 SOLVE

  | Command | Description
  | --- | --- |
  |`solve = "mldivide"`| mldivide linear system solver, `default setting`
  |`solve = "lu"`| LU linear system solver

 SAVE

  | Command | Description
  | --- | --- |
  |`save = "path/name.h5"`| saves results in the h5-file
  |`save = "path/name.xlsx"`| saves results in the xlsx-file

### Flowchart
The power flow flowchart depicts the algorithm process according to user settings.
<img src="https://github.com/mcosovic/JuliaGrid/blob/master/doc/powerflow_chart.svg" width="550">
