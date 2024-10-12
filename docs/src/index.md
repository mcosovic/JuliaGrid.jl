JuliaGrid
=============

JuliaGrid is a fast, flexible and easy-to-use open-source tool for analysis and modification of power system configurations and measurement data. It represents a comprehensive framework for steady-state power system analysis written in the Julia programming language. The framework is available as a Julia package under MIT License. JuliaGrid is primarily designed for  researchers and academics, providing various state-of-the-art algorithms.

The fremowork's architecture centres around code-reusability paradigm, allowing users a high level of customization for their experiments. To simplify, the overall logic for setting the experiments and its analysis can be as follows:
* Users define a power system with/without measurement data.
* Users select between the AC or DC model.
* Users define the specific type of required analysis.
* Finally, they solve the generated power system model.

---

## Installation Guide
JuliaGrid is compatible with Julia version 1.9 and later. To get started with JuliaGrid, users should first install Julia and consider using a code editor for a smoother coding experience.

---

#### Install Julia
Begin by [downloading and installing](https://julialang.org/downloads/) Julia. We can choose either the Current Stable Release or the Long-term Support Release.

The Current Stable Release is the most recent version of Julia, providing access to the latest features and typically offering better performance. For most users, we recommend installing the Current Stable Release. The Long-term Support Release is an older version of Julia that has continued to receive bug and security fixes. However, it may not have the latest features or performance improvements.

---

#### Install Code Editor
For a smoother development experience, we recommend using a code editor. While you can write Julia code in any text editor, using an integrated development environment (IDE) makes coding easier and more efficient. We suggest installing [Visual Studio Code](https://code.visualstudio.com/), which provides excellent support for Julia through its dedicated Julia extension. Visual Studio Code offers features like syntax highlighting, debugging, and autocompletion, making it an ideal choice for both beginners and experienced users.

The [Julia extension](https://marketplace.visualstudio.com/items?itemName=julialang.language-julia) for Visual Studio Code includes built-in dynamic autocompletion, inline results, plot pane, integrated REPL, variable view, code navigation, and many other advanced language features.  For a step-by-step guide on how to use Julia in Visual Studio Code, you can follow the tutorial available [here](https://code.visualstudio.com/docs/languages/julia).

---

#### Install JuliaGrid
To get the JuliaGrid package installed, execute the following Julia command:
```julia
import Pkg
Pkg.add("JuliaGrid")
```

When a new version of JuliaGrid is released, you can update it with the following command:
```julia
import Pkg
Pkg.update("JuliaGrid")
```

---

## Documentation Structure
JuliaGrid documentation consists of three main parts:
* The manual provides users with guidance on how to use available functions, its return values, and offers instructions for modifying power system configurations, measurement data, and other user specific analysis.
* The tutorials delve deeper into the theoretical underpinnings of state-of-the-art algorithms, allowing users to gain an in-depth understanding of the equations used in various functions.
* API references offer a comprehensive list of objects, functions and methods within the package, categorised according to specific use-cases.

---

## Getting Started

Below, we have provided a list of exhaustive examples in order to ease users in getting started with the JuliaGrid package. These examples highlight some of the functionalities that the framework offers.

---

#### AC Power Flow
```julia
using JuliaGrid

system = powerSystem("case14.h5")          # Build the power system model
acModel!(system)                           # Create matrices and vectors for the AC model

analysis = newtonRaphson(system)           # Build the power flow model
for iteration = 1:10                       # Begin the iteration loop
    stopping = mismatch!(system, analysis) # Compute power mismatches
    if all(stopping .< 1e-8)               # Check if the stopping criterion is met
        println("Solution Found.")         # Output message indicating convergence
        break                              # Stop iterations if the criterion is met
    end
    solve!(system, analysis)               # Compute voltage magnitudes and angles
end
power!(system, analysis)                   # Compute powers within the power system
current!(system, analysis)                 # Compute currents within the power system

printBusData(system, analysis)             # Print data related to buses
```

---

#### DC Power Flow
```julia
using JuliaGrid

@power(MW, MVAr, MVA)                    # Specify the power units for input data
system = powerSystem("case14.h5")        # Build the power system model
dcModel!(system)                         # Create matrices and vectors for the DC model

analysis = dcPowerFlow(system)           # Build the power flow analysis
solve!(system, analysis)                 # Compute voltage angles

@generator(active = 20)                  # Define the template for generators
addGenerator!(system, analysis; bus = 1) # Add the new generator to the power system
solve!(system, analysis)                 # Recompute voltage angles with the updated model

printBusSummary(system, analysis)        # Print a summary of data related to buses
```

---

#### AC Optimal Power Flow
```julia
using JuliaGrid, Ipopt

system = powerSystem("case14.h5")              # Build the power system model
acModel!(system)                               # Create matrices and vectors for the AC model

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer) # Build the optimal power flow model
solve!(system, analysis)                       # Compute generator powers and bus voltages
current!(system, analysis)                     # Compute currents within the power system

@branch(resistance = 0.01, reactance = 0.2)    # Define the new template for branches
addBranch!(system, analysis; from = 1, to = 5) # Add the new branch to the power system
solve!(system, analysis)                       # Recompute solutions with the updated model
```

---

#### DC Optimal Power Flow
```julia
using JuliaGrid, HiGHS

system = powerSystem("case14.h5") # Build the power system model
dcModel!(system)                  # Create matrices and vectors for the DC model

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer) # Build the optimal power flow model
solve!(system, analysis)          # Compute generator powers and bus voltages
power!(system, analysis)          # Compute active powers within the power system

printBranchData(system, analysis) # Print data related to branches
```

---

#### AC State Estimation
```julia
using JuliaGrid

system = powerSystem("case14.h5")            # Build the power system model
device = measurement("measurement14.h5")     # Build the measurement model
acModel!(system)                             # Create matrices and vectors for the AC model

analysis = gaussNewton(system, device)       # Build the state estimation model
for iteration = 1:20                         # Begin the iteration loop
    stopping = solve!(system, analysis)      # Compute estimate of voltages
    if stopping < 1e-8                       # Check if the stopping criterion is met
        println("Solution Found.")           # Output message indicating convergence
        break                                # Stop iterations if the criterion is met
    end
end
power!(system, analysis)                     # Compute active powers within the power system

printWattmeterData(system, device, analysis) # Print data related to wattmeters
```
---

#### PMU State Estimation
```julia
using JuliaGrid

system = powerSystem("case14.h5")        # Build the power system model
device = measurement("measurement14.h5") # Build the measurement model
acModel!(system)                         # Create matrices and vectors for the AC model

analysis = pmuStateEstimation(system, device) # Build the state estimation model
solve!(system, analysis)                 # Compute estimate of voltages

updatePmu!(system, device, analysis; label = "To 1", angle = 0.0) # Update phasor measurement
solve!(system, analysis)                 # Recompute the solution with the updated model

printPmuData(system, device, analysis)   # Print data related to PMUs
```

---

#### DC State Estimation
```julia
using JuliaGrid

system = powerSystem("case14.h5")        # Build the power system model
device = measurement("measurement14.h5") # Build the measurement model
dcModel!(system)                         # Create matrices and vectors for the DC model

analysis = dcStateEstimation(system, device) # Build the state estimation model
solve!(system, analysis)                 # Compute estimate of voltage angles

residualTest!(system, device, analysis)  # Perform bad data analysis and remove outlier
solve!(system, analysis)                 # Recompute voltage angles with the updated model
```

---

## Contributors
 - [Ognjen Kundacina](https://www.linkedin.com/in/ognjen-kundacina-machine-learning-guy/) - The Institute for Artificial Intelligence Research and Development of Serbia
 - [Muhamed Delalic](https://www.linkedin.com/in/muhameddelalic/) - University of Sarajevo, Bosnia and Herzegovina
 - [Armin Teskeredzic](https://www.linkedin.com/in/armin-teskered%C5%BEi%C4%87-69a099231/) - RWTH Aachen University, Germany
 - [Mirsad Cosovic](https://www.linkedin.com/in/mirsad-cosovic-5a4972a9/) - University of Sarajevo, Bosnia and Herzegovina