JuliaGrid
=============

JuliaGrid is an open-source and easy-to-use simulation tool and solver developed for researchers and educators. It is available as a Julia package, and its source code is released under the MIT License. JuliaGrid primarily focuses on steady-state power system analyses, providing a versatile set of algorithms while also allowing for easy manipulation of both the power system configuration and the analyses involved.

Our documentation is divided into three distinct categories. The manual provides users with guidance on using available functions, explaining the expected outcomes, and offering instructions for modifying power system configurations and specific analyses. The tutorials delve deeper into the mathematical implementation of algorithms, allowing users to gain an in-depth understanding of the formulas behind various functions. Lastly, the API references offer a comprehensive list of functions within the package, categorized according to specific analyses.

In order to encourage code reusability and give users the ability to customize their analyses as required, we deconstruct specific analyses. However, the overall logic can be simplified as follows: users should initially build a power system, then select between the AC or DC model, define the specific type of analysis, and ultimately, solve the generated framework.

Below, we have provided a list of examples to assist users in getting started with the JuliaGrid package. These examples highlight some of the possibilities that the package offers.

---

#### AC Power Flow
```@example
using JuliaGrid # hide
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end

power!(system, analysis)
current!(system, analysis)

nothing # hide
```

---

#### DC Power Flow
```@example
using JuliaGrid # hide
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)

addGenerator!(system, analysis; bus = 1, active = 0.2)
solve!(system, analysis)

nothing # hide
```

---

#### AC Optimal Power Flow
```julia
using JuMP, Ipopt

system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
JuMP.set_silent(analysis.jump) #hide
solve!(system, analysis)

power!(system, analysis)
current!(system, analysis)

updateBus!(system, analysis; label = 1, active = 0.2)
addBranch!(system, analysis; from = 1, to = 5, resistance = 0.01, reactance = 0.2)
solve!(system, analysis)
```

---

#### DC Optimal Power Flow
```julia
using JuMP, HiGHS

system = powerSystem("case14.h5")
acModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
JuMP.set_silent(analysis.jump) #hide
solve!(system, analysis)

power!(system, analysis)

addGenerator!(system, analysis; bus = 1, active = 0.1, maxActive = 0.5)
solve!(system, analysis)
```