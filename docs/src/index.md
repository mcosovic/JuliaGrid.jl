# JuliaGrid

JuliaGrid is a fast, flexible, and easy-to-use open-source tool for steady-state power system analysis, developed in the Julia programming language. The framework enables easy modification of power system configurations and measurement data, allowing efficient quasi-steady-state analyses. It is available as a Julia package under the MIT License. JuliaGrid is primarily designed for researchers and academics, offering various state-of-the-art algorithms.

The framework's architecture centres around code-reusability paradigm, allowing users a high level of customization for their experiments. To simplify, the overall logic for setting the experiments and its analysis can be as follows:
* Users define a power system with/without measurement data.
* Users select between the AC or DC model.
* Users define the specific type of required analysis.
* Finally, they solve the generated power system model.

JuliaGrid offers comprehensive support for importing power system data from both Matpower and PSSE case files. In addition to data import, it provides tools for constructing detailed models of power systems and associated measurements. To accelerate future data access, it also enables saving processed data in the efficient HDF5 format.

---

### Installation Guide
JuliaGrid is compatible with Julia version 1.9 and later. To get started with JuliaGrid, users should first install Julia and consider using a code editor for a smoother coding experience. For detailed instructions, please consult the [Installation Guide](@ref InstallationGuide).

To get the JuliaGrid package installed, execute the following Julia command:
```julia
import Pkg
Pkg.add("JuliaGrid")
```

---

### Documentation Structure
JuliaGrid documentation consists of four main parts:
* The manual provides users with guidance on how to use available functions, its return values, and offers instructions for modifying power system configurations, measurement data, and other user specific analysis.
* The tutorials delve deeper into the theoretical underpinnings of state-of-the-art algorithms, allowing users to gain an in-depth understanding of the equations used in various functions.
* The examples section contains various power system datasets and uses toy examples to highlight JuliaGrid's abilities in steady-state and quasi-steady-state analyses.
* API references offer a comprehensive list of objects, functions and methods within the package, categorised according to specific use-cases.

---

### Getting Started
Below, we have provided a list of exhaustive examples in order to ease users in getting started with the JuliaGrid package. These examples highlight some of the functionalities that the framework offers.

---

#### AC Power Flow
```julia
using JuliaGrid

system = powerSystem("case14.h5") # Build the power system model

analysis = newtonRaphson(system)  # Build the power flow model
powerFlow!(analysis; verbose = 3) # Compute voltages

power!(analysis)                  # Compute powers
current!(analysis)                # Compute currents

printBusData(analysis)            # Print bus data
```

---

#### DC Power Flow
```julia
using JuliaGrid

@power(MW, MVAr)                          # Specify the power units
system = powerSystem("case14.h5")         # Build the power system model

analysis = dcPowerFlow(system)            # Build the power flow model
powerFlow!(analysis; power = true)        # Compute powers and voltage angles

@generator(active = 20.0)                 # Define the template
addGenerator!(analysis; bus = "Bus 1 HV") # Add the new generator

powerFlow!(analysis; power = true)        # Recompute powers and voltage angles

printBusSummary(analysis)                 # Print bus summary data
```

---

#### AC Optimal Power Flow
```julia
using JuliaGrid, Ipopt

system = powerSystem("case14.h5")                      # Build the power system model

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer) # Build the optimal power flow model
powerFlow!(analysis; current = true, verbose = 3)      # Compute voltages and currents

updateBranch!(analysis, label = 2, reactance = 0.5)    # Update branch parameters
updateGenerator!(analysis, label = 3, maxActive = 0.3) # Update generator parameters

powerFlow!(analysis; current = true, verbose = 3)      # Recompute voltages and currents
```

---

#### DC Optimal Power Flow
```julia
using JuliaGrid, HiGHS

system = powerSystem("case14.h5")                      # Build the power system model

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer) # Build the optimal power flow model
powerFlow!(analysis; power = true)                     # Compute powers and voltage angles

printBranchData(analysis)                              # Print branch data
```

---

#### AC State Estimation
```julia
using JuliaGrid

system, monitoring = ems("case14.h5", "monitoring.h5") # Build the energy management system

analysis = gaussNewton(monitoring)                     # Build the state estimation model
stateEstimation!(analysis; power = true, verbose = 3)  # Estimate voltages and powers

printWattmeterData(analysis)                           # Print wattmeter data
```
---

#### PMU State Estimation
```julia
using JuliaGrid

system, monitoring = ems("case14.h5", "monitoring.h5") # Build the energy management system

analysis = pmuStateEstimation(monitoring)              # Build the state estimation model
stateEstimation!(analysis)                             # Estimate voltages

printPmuData(analysis)                                 # Print PMU data
```

---

#### DC State Estimation
```julia
using JuliaGrid

system, monitoring = ems("case14.h5", "monitoring.h5") # Build the energy management system

analysis = dcStateEstimation(monitoring)               # Build the state estimation model
stateEstimation!(analysis)                             # Estimate voltage angles

residualTest!(analysis)                                # Perform bad data analysis
stateEstimation!(analysis)                             # Recompute voltage angles

printBusData(analysis)                                 # Print bus data
```

---

### Citing JuliaGrid
Please consider citing the following [preprint](https://arxiv.org/abs/2502.18229) if JuliaGrid contributes to your research or projects:
```latex
@article{juliagrid,
   title={JuliaGrid: An Open-Source Julia-Based Framework for Power System State Estimation},
   author={M. Cosovic, O. Kundacina, M. Delalic, A. Teskeredzic, D. Raca,
           A. Mesanovic, D. Miskovic, D. Vukobratovic, A. Monti},
   journal={arXiv preprint arXiv:2502.18229},
   year={2025}
}
```

---

### Contributors
 - [Ognjen Kundacina](https://www.linkedin.com/in/ognjen-kundacina-machine-learning-guy/) - The Institute for Artificial Intelligence Research and Development of Serbia
 - [Muhamed Delalic](https://www.linkedin.com/in/muhameddelalic/) - University of Sarajevo, Bosnia and Herzegovina
 - [Armin Teskeredzic](https://www.linkedin.com/in/armin-teskered%C5%BEi%C4%87-69a099231/) - RWTH Aachen University, Germany
 - [Mirsad Cosovic](https://www.linkedin.com/in/mirsad-cosovic-5a4972a9/) - University of Sarajevo, Bosnia and Herzegovina