JuliaGrid
=============

JuliaGrid is an open-source and easy-to-use simulation tool and solver developed for researchers and educators. It is available as a Julia package, and its source code is released under the MIT License. JuliaGrid primarily focuses on steady-state power system analyses and provides a versatile set of algorithms, making it convenient for users to manipulate power system configurations with ease.

Our documentation is organized into three distinct categories, with each focusing on specific aspects of the tool. The manual provides users with guidance on how to utilize the available functions, what to expect during their execution, and instructions on manipulating power system configurations for steady-state analyses. The tutorials delve deeper into the mathematical implementation of algorithms, allowing users to gain an in-depth understanding of the formulas behind various functions. Lastly, the API references offer a comprehensive list of functions within the package, categorized according to specific analyses.

To promote code reusability and empower users to tailor their analyses to their needs, we break down specific analyses into logical frameworks. In JuliaGrid, users first construct a power system, then choose between the AC or DC framework, create specific analysis framework, and finally, solve the generated framework.

Below, we have listed some examples that can help users quickly get started with using the JuliaGrid package.

---

### AC Power Flow
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

### DC Power Flow
```@example
using JuliaGrid # hide
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)

power!(system, analysis)

nothing # hide
```

---

### AC Optimal Power Flow
```@example
using JuliaGrid # hide
using JuMP, Ipopt

system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
JuMP.set_silent(analysis.jump) #hide
solve!(system, analysis)

power!(system, analysis)
current!(system, analysis)

nothing # hide
```

---

### DC Optimal Power Flow
```@example 
using JuliaGrid # hide
using JuMP, HiGHS

system = powerSystem("case14.h5")
acModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
JuMP.set_silent(analysis.jump) #hide
solve!(system, analysis)

power!(system, analysis)

nothing # hide
```