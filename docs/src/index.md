JuliaGrid
=============

JuliaGrid is an open-source and easy-to-use simulation tool and solver developed for researchers and educators. It is available as a Julia package, and its source code is released under the MIT License. JuliaGrid primarily focuses on steady-state power system analyses, providing a versatile set of algorithms while also allowing for easy manipulation of power system configurations, measurement data, and the analyses involved.

Our documentation is divided into three distinct categories:
* The manual provides users with guidance on using available functions, explaining the expected outcomes, and offering instructions for modifying power system configurations, measurement data, and specific analyses.
* The tutorials delve deeper into the mathematical implementation of algorithms, allowing users to gain an in-depth understanding of the formulas behind various functions.
* Lastly, the API references offer a comprehensive list of functions within the package, categorized according to specific analyses.

In order to encourage code reusability and give users the ability to customize their analyses as required, we deconstruct specific analyses. However, the overall logic can be simplified as follows:
* Users start by constructing a power system (and measurement data if state estimation analyses are involved).
* They then choose between the AC or DC model.
* Next, users define the specific type of analysis.
* Ultimately, they solve the generated framework.

Below, we have provided a list of examples to assist users in getting started with the JuliaGrid package. These examples highlight some of the possibilities that the package offers.

---

#### Installation
JuliaGrid is compatible with Julia version 1.8 and newer. To get the JuliaGrid package installed, execute the following Julia command:
```julia
import Pkg
Pkg.add("JuliaGrid")
```

---

#### AC Power Flow
```julia
using JuliaGrid

system = powerSystem("case14.h5")          # Build the power system model
acModel!(system)                           # Generate matrices and vectors in the AC model

analysis = newtonRaphson(system)           # Initialize the Newton-Raphson method
for iteration = 1:10                       # Begin the iteration loop
    stopping = mismatch!(system, analysis) # Compute power mismatches
    if all(stopping .< 1e-8)               # Check if the stopping criterion is met
        break                              # Stop the iteration loop if the criterion is met
    end
    solve!(system, analysis)               # Compute bus voltages
end

power!(system, analysis)                   # Compute powers within the power system
current!(system, analysis)                 # Compute currents within the power system
```

---

#### DC Power Flow
```julia
using JuliaGrid

@power(MW, MVAr, MVA)                    # Specify the power units for input data
system = powerSystem("case14.h5")        # Build the power system model
dcModel!(system)                         # Generate matrices and vectors in the DC model

analysis = dcPowerFlow(system)           # Initialize the DC power flow analysis
solve!(system, analysis)                 # Compute bus voltage angles

@generator(active = 20)                  # Define a template for generators
addGenerator!(system, analysis; bus = 1) # Add a new generator into the power system
solve!(system, analysis)                 # Compute bus voltage angles in the updated setup
```

---

#### AC Optimal Power Flow
```julia
using JuliaGrid, Ipopt

system = powerSystem("case14.h5")              # Build the power system model
acModel!(system)                               # Generate matrices and vectors in the AC model

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer) # Build the AC optimal power flow model
solve!(system, analysis)                       # Compute generator powers and bus voltages

current!(system, analysis)                     # Compute currents within the power system

@branch(resistance = 0.01, reactance = 0.2)    # Define a new template for branches
addBranch!(system, analysis; from = 1, to = 5) # Add a new branch into the power system
solve!(system, analysis)                       # Compute a new solution in the updated setup
```

---

#### DC Optimal Power Flow
```julia
using JuliaGrid, HiGHS

system = powerSystem("case14.h5")                 # Build the power system model
dcModel!(system)                                  # Generate matrices and vectors in DC model

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer) # Build the DC optimal power flow model
solve!(system, analysis)                          # Compute generator powers and bus voltages

updateBus!(system, analysis; label = 1, type = 1) # Modify the existing bus
updateBus!(system, analysis; label = 2, type = 3) # Designate the new slack bus
solve!(system, analysis)                          # Compute new solution in the updated setup
```

---

#### AC State Estimation
```julia
using JuliaGrid

system = powerSystem("case14.h5")        # Build the power system model
device = measurement("measurement14.h5") # Build the measurement model
acModel!(system)                         # Generate matrices and vectors in the AC model

analysis = gaussNewton(system, device)   # Initialize the AC state estimation model
for iteration = 1:20                     # Begin the iteration loop
    stopping = solve!(system, analysis)  # Compute estimate of bus voltages
    if stopping < 1e-8                   # Check if the stopping criterion is met
        break                            # Stop the iteration loop if the criterion is met
    end
end
```

---

#### PMU State Estimation
```julia
using JuliaGrid

system = powerSystem("case14.h5")             # Build the power system model
device = measurement("measurement14.h5")      # Build the measurement model
acModel!(system)                              # Generate matrices and vectors in the AC model

analysis = pmuWlsStateEstimation(system, device) # Initialize the WLS state estimation model
solve!(system, analysis)                      # Compute estimate of bus voltages

updatePmu!(system, device, analysis; label = 1, angle = 0.0) # Update phasor measurement

solve!(system, analysis)                     # Compute estimate of bus voltages
```

---

#### DC State Estimation
```julia
using JuliaGrid

system = powerSystem("case14.h5")            # Build the power system model
device = measurement("measurement14.h5")     # Build the measurement model
dcModel!(system)                             # Generate matrices and vectors in DC model

analysis = dcWlsStateEstimation(system, device) # Initialize the WLS state estimation model
solve!(system, analysis)                     # Compute estimate of bus voltage angles

residualTest!(system, device, analysis)      # Perform bad data analysis and remove outlier
solve!(system, analysis)                     # Compute estimate of bus voltage angles
```

---


#### Contributors
 - [Ognjen Kundacina](https://www.linkedin.com/in/ognjen-kundacina-machine-learning-guy/) - The Institute for Artificial Intelligence Research and Development of Serbia
 - [Muhamed Delalic](https://www.linkedin.com/in/muhameddelalic/) - University of Sarajevo, Bosnia and Herzegovina
 - Lin Zeng - Cornell University, Ithaca, NY, USA
 - [Mirsad Cosovic](https://www.linkedin.com/in/mirsad-cosovic-5a4972a9/) - University of Sarajevo, Bosnia and Herzegovina
