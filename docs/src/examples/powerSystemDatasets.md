# [Power System Datasets](@id PowerSystemDataExamples)
The table below showcases a range of widely used power system datasets that users can leverage for analysis. These datasets vary in size and complexity, providing flexibility for different applications. For instructions on how to load these models into JuliaGrid, please refer to the [Build Model](@ref BuildModelManual) section of the manual.

| Power System                              | Buses | Branches | Generators | Download Links
|:------------------------------------------|:-----:|:--------:|:----------:|:------------------------------------------------:|
| IEEE 14-bus test case                     | 14    | 20       | 5          | [[hdf5](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/cases/case14.h5)] [[matpower](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/matlab/case14.m)] [[built-in](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/julia/case14.jl)]
| IEEE 30-bus test case                     | 30    | 41       | 6          | [[hdf5](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/hdf5/case_ieee30.h5)] [[matpower](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/matlab/case_ieee30.m)] [[built-in](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/julia/case_ieee30.jl)]
| IEEE 118-bus test case                    | 118   | 186      | 54         | [[hdf5](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/hdf5/case118.h5)] [[matpower](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/matlab/case118.m)]
| IEEE 300-bus test case                    | 300   | 411      | 69         | [[hdf5](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/hdf5/case300.h5)] [[matpower](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/matlab/case300.m)]
| Part of the European transmission network | 1354  | 1991     | 260        | [[hdf5](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/hdf5/case1354pegase.h5)] [[matpower](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/matlab/case1354pegase.m)]
| French transmission network               | 1951  | 2596     | 392        | [[hdf5](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/hdf5/case1951rte.h5)] [[matpower](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/matlab/case1951rte.m)]
| Synthetic US WECC model                   | 10000 | 12706    | 2485       | [[hdf5](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/hdf5/case_ACTIVSg10k.h5)] [[matpower](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/matlab/case_ACTIVSg10k.m)]
| Synthetic US NE/Mid-Atlantic model        | 25000 | 32230    | 4834       | [[hdf5](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/hdf5/case_ACTIVSg25k.h5)] [[matpower](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/matlab/case_ACTIVSg25k.m)]
| Synthetic Eastern US model                | 70000 | 88207    | 10390      | [[hdf5](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/hdf5/case_ACTIVSg70k.h5)] [[matpower](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/matlab/case_ACTIVSg70k.m)]
| Synthetic US model                        | 82000 | 104121   | 13419      | [[hdf5](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/hdf5/case_SyntheticUSA.h5)] [[matpower](https://github.com/mcosovic/JuliaGridData/raw/refs/heads/main/power_systems/matlab/case_SyntheticUSA.m)]


Once users have established a power system model, they can proceed with the various types of analyses offered by JuliaGrid. While these power systems contain a comprehensive data structure for different analyses, only specific parameters are needed for certain types of analysis. For example, state estimation relies on initial bus voltage values and branch parameters.

In this context, we can define a minimal working dataset that establishes the power system topology. In JuliaGrid, this can be achieved by introducing only buses and generators, while branches require at least one parameter related to the unified branch model. From there, the minimal model can be further refined for specific types of analysis, as explored in examples dedicated to different analysis types.

----

##### [Example of a Minimal Working Power System Dataset](@id MinimalWorkingDatasetExamples)
The power system shown in Figure 1 serves as an example to demonstrate various JuliaGrid features related to steady-state and quasi-steady-state analysis.

```@raw html
<img src="../../assets/example_4bus.svg" class="center" width="450"/>
<figcaption>Figure 1: The 4-bus power system.</figcaption>
&nbsp;
```

We begin by defining the minimal data required to establish the power system model:
```@example 4bus
using JuliaGrid, JuMP, Ipopt # hide
@default(template) # hide
@default(unit) # hide

system = powerSystem()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 3")
addBus!(system; label = "Bus 4")

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.06)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.22)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.19)
addBranch!(system; label = "Branch 4", from = "Bus 2", to = "Bus 4", reactance = 0.32)

addGenerator!(system; label = "Generator 1", bus = "Bus 1")
addGenerator!(system; label = "Generator 2", bus = "Bus 3")

nothing # hide
```

The model consists of four buses, two generators, and four branches, each defined with its respective reactance value. As we explore different types of analyses, additional parameters will be introduced incrementally to meet specific analytical requirements.



