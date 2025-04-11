# [Per-Unit System](@id PerUnitSystem)
In power system modeling and analysis, variables and parameters are often normalized using the per-unit system. The per-unit system is particularly advantageous for analyzing networks with multiple voltage levels connected by transformers with different turns ratios.

In static scenarios, there are four key quantities of interest: voltage, current, power, and impedance or admittance. Defining a per-unit system requires selecting base values for each of these quantities. However, since these quantities are interconnected by various laws, the choice of base values cannot be arbitrary. Typically, the base quantities are chosen as voltage and power, with the base current and impedance (or admittance) then calculated accordingly. Usually, base quantities are selected as follows:
* three-phase apparent power ``S_{3\phi(\text{b})}``,
* line-to-line voltage ``V_{LL(\text{b})}``.

While the value of three-phase apparent power is unique across the entire system, multiple line-to-line base voltages are used to account for the different voltage zones created by transformers.

!!! note "Info"
    Since balanced three-phase power systems are treated as a single line with a neutral return, confusion may arise regarding the relationship between the per-unit values of line voltages and phase voltages, as well as between the per-unit values of single-phase and three-phase powers [john1994power](@cite). To clarify these relationships, we will systematically explore the conversions between the per-unit and SI systems below.

---

## Powers
Let us consider the three-phase apparent power expressed in SI units, denoted as ``S_{3\phi(\text{si})}``. To convert this into the per-unit system, we divide it by the base power:
```math
S_{3\phi(\text{pu})} = \cfrac{S_{3\phi(\text{si})}}{S_{3\phi(\text{b})}}.
```

Now, let us examine the power of a single phase and convert it to the per-unit system:
```math
S_{1\phi(\text{pu})}  = \cfrac{S_{1\phi(\text{si})}}{S_{1\phi(\text{b})}} = \cfrac{S_{3\phi(\text{si})}}{3} \cfrac{3}{S_{3\phi(\text{b})}} = \cfrac{S_{3\phi(\text{si})}}{S_{3\phi(\text{b})}} = S_{3\phi(\text{pu})}.
```

This indicates that in the per-unit system, there is no distinction between three-phase and single-phase powers. The type of power only becomes relevant when converting back from per-unit to SI units, and vice versa.

!!! note "Info"
    As is standard practice, even if all simulations utilize a single-phase equivalent, input powers provided in SI units are assumed to represent three-phase powers. Similarly, if simulation results are displayed in SI units, they are considered to be three-phase powers, as we have selected three-phase power as the base value.

---

## Voltages
Format for input data that JuliaGrid uses required value for base voltage per each bus, and those values represent the line-to-line voltages. On the other hand, in all analyses we are working with line-to-neutral voltages. To convert a line-to-neutral voltage given in SI units ``V_{LN(\text{si})}`` to per-unit form ``V_{LN(\text{pu})}``, or vice versa, we use the formula:
```math
V_{LN(\text{pu})} = \cfrac{\sqrt{3}V_{LN(\text{si})}}{V_{LL(\text{b})}}.
```

!!! note "Info"
    Similarly to power, JuliaGrid simulations use a single-phase equivalent. Voltage values specified in volts correspond to line-to-neutral values, while base voltages are expected to be provided as line-to-line values.

---

## Impedances
Let us first consider the line itself, excluding transformers. The base impedance of the line is given by:
```math
Z_{L(\text{b})} = \cfrac{V_{LL(\text{b})}^2}{S_{3\phi(\text{b})}}.
```
If the impedance is provided in ohms, its value in the per-unit system is:
```math
Z_{L(\text{pu})} = \cfrac{Z_{L(\text{si})}}{Z_{L(\text{b})}} = \cfrac{Z_{L(\text{si})} S_{3\phi(\text{b})}}{V_{LL(\text{b})}^2}.
```

A common question that arises is which base voltage should be used for the line, considering the two ends of the line (from-bus and to-bus). The key assumption here is that the base voltages correspond to the nominal voltages of the transformers. Therefore, when the user defines base voltages, JuliaGrid assumes these voltages represent the nominal voltages of the transformers, implying that the base voltages on both the from-bus and to-bus ends of the line will be the same.

Now, let us consider the transformer. The base voltages at the from-bus end (primary side) ``V_{LLF(\text{b})}``, and the to-bus end (secondary side) ``V_{LLT(\text{b})}``,
will generally be different. This requires us to define a conversion method for impedance. Typically, when impedance is given in ohms, it refers to the primary side of the transformer, denoted as ``Z_{F(\text{si})}``,  while the impedance in our [unified branch model](@ref UnifiedBranchModelTutorials) refers to the secondary side, denoted as ``Z_{T(\text{si})}``. To convert the impedance from the from-bus end to the to-bus end, we use:
```math
Z_{T(\text{si})} = \cfrac{Z_{F(\text{si})}}{m^2},
```
where ``m`` is the effective turns ratio, calculated as:
```math
m = \tau \cfrac{V_{LLF(\text{b})}}{V_{LLT(\text{b})}},
```
with ``\tau`` is off-nominal turns ratio. This equation provides the impedance on the to-bus end of the branch or the secondary side of the transformer in ohms.

To convert this impedance to the per-unit system, we use the base impedance for the secondary side:
```math
Z_{T(\text{pu})} = \cfrac{Z_{T(\text{si})}}{Z_{T(\text{b})}},
```
where:
```math
Z_{T(\text{b})} = \cfrac{V_{LLT(\text{b})}^2}{S_{3\phi(\text{b})}}.
```

Substituting the previous expressions, we obtain the following formula for the impedance on the secondary side in per-unit system:
```math
Z_{T(\text{pu})} = \cfrac{Z_{F(\text{si})} S_{3\phi(\text{b})}}{\tau^2 V_{LLF(\text{b})}^2}.
```
This formula applies to both lines and transformers. For a line, where ``\tau = 1``, the formula simplifies and becomes the same as the impedance equation for a line.

!!! note "Info"
    In the case of a transformer, if impedances or admittances are provided in SI units, they must be specified for the primary side (from-bus end).

---

## Currents
Once the base power and base voltage values are set, we can calculate the base current flowing through a line or branch as follows:
```math
I_{L(\text{b})} = \cfrac{S_{3\phi(\text{b})}}{\sqrt{3}V_{LL(\text{b})}}.
```

When we transform currents that are given in SI unit to per-unit, or vice versa, we use the following formula:
```math
I_{L(\text{pu})} = \cfrac{I_{L(\text{si})}}{I_{L(\text{b})}} = \cfrac{\sqrt{3}I_{L(\text{si})}V_{LL(\text{b})}}{S_{3\phi(\text{b})}}.
```

---

## Per-Units to SI Units
To create a comprehensive tutorial, let us start with an example where input data is defined in per-units, while the simulation results are outputted in SI units.
```@example power
using JuliaGrid # hide
@default(template) # hide

system = powerSystem()
@base(system, MVA, kV)

nothing # hide
```

First, we initialize the power system container, setting the base value for three-phase apparent power ``S_{3\phi(\text{b})}``. We use a macro to specify that power is given in megavolt-amperes (MVA):
```@repl power
system.base.power.value
```
We also specify that base line-to-line voltages will be stored in kilovolts (kV).

---

##### Buses
Next, we add buses to the system:
```@example power
addBus!(system; label = "Bus 1", type = 3, magnitude = 1.0, base = 115e3)
addBus!(system; label = "Bus 2", type = 1, magnitude = 1.1, base = 230e3)
addBus!(system; label = "Bus 3", type = 1, active = 1.2, reactive = 0.1, base = 230e3)

nothing # hide
```

The `base` keyword allows us to specify base line-to-line voltages ``V_{LL(\text{b})}`` for each bus in volts (V). However, these voltages are stored in kV, as specified by the [`@base`](@ref @base) macro:
```@repl power
print(system.bus.label, system.base.voltage.value)
```

The `magnitude` keyword sets the initial line-to-neutral bus voltages in per-units:
```@repl power
print(system.bus.label, system.bus.voltage.magnitude)
```

Using the `active` and `reactive` keywords, we define the three-phase power demands for the load at `Bus 3` in per-units:
```@repl power
print(system.bus.label, system.bus.demand.active, system.bus.demand.reactive)
```

---

##### Branches
Now, let us define the branches:
```@example power
@branch(label = "Branch ?")
addBranch!(system; from = "Bus 1", to = "Bus 2", turnsRatio = 0.98, reactance = 0.03)
addBranch!(system; from = "Bus 2", to = "Bus 3", reactance = 0.1, susceptance = 0.03)

nothing # hide
```

The first branch represents a transformer, with its reactance given in per-units on the secondary side (to-bus end), and an off-nominal turns ratio of ``\tau = 0.98``. The second branch represents a transmission line, with parameters also specified in per-units:
```@repl power
prmt = system.branch.parameter;
print(system.branch.label, prmt.reactance, prmt.susceptance, prmt.turnsRatio)
```

---

##### Generators
Finally, we add a generator to our example:
```@example power
@generator(label = "Generator ?")
addGenerator!(system; bus = "Bus 1", active = 2.3, reactive = 0.2)

nothing # hide
```

We set up the generator at `Bus 1`, using the `active` and `reactive` keywords to define the three-phase power output of the generator in per-units:
```@repl power
output = system.generator.output;
print(system.generator.label, output.active, output.reactive)
```

---

##### AC Power Flow
For example, we can perform AC power flow analysis on our defined power system:
```@example power
analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(analysis)
end
power!(analysis)
nothing # hide
```

---

##### Results
Now, we can examine some results in SI units:
```@example power
@voltage(kV, deg)
@power(MW, MVAr)

show = Dict("Power Generation" => false, "Shunt Power" => false)
printBusData(analysis; show)
```

Here, the voltage magnitudes in kV represent line-to-neutral voltages for each bus, while the powers in MW and MVAr represent three-phase powers.

---

## SI Units to Per-Units
In this section, we will create the same power system as before, but using SI units:
```@example power
using JuliaGrid # hide
@default(template) # hide

@voltage(kV, deg, kV)
@power(MW, MVAr)
@parameter(Ω, S)

system = powerSystem()
@base(system, MVA, kV)

nothing # hide
```
Note that even though we define parameters in SI units, JuliaGrid will automatically convert these parameters to per-units and store them in that format.

---
##### Buses
Next, we add the same three buses, this time using SI units:
```@example power
addBus!(system; label = "Bus 1", type = 3, magnitude = 115 / sqrt(3) , base = 115.0)
addBus!(system; label = "Bus 2", type = 1, magnitude = 253 / sqrt(3), base = 230.0)
addBus!(system; label = "Bus 3", type = 1, active = 120, reactive = 100, base = 230.0)

nothing # hide
```

The `base` keyword specifies the base line-to-line voltages ``V_{LL(\text{b})}`` for each bus in kV, and these values are also stored in kV:
```@repl power
print(system.bus.label, system.base.voltage.value)
```

The `magnitude` keyword sets the initial line-to-neutral bus voltages in kV, but they are stored in per-units:
```@repl power
print(system.bus.label, system.bus.voltage.magnitude)
```

Using the `active` and `reactive` keywords, we define the three-phase power demands for the load at `Bus 3` in SI units, which are then stored in per-units:
```@repl power
print(system.bus.label, system.bus.demand.active, system.bus.demand.reactive)
```

---

##### Branches
Now, let us define the branches:
```@example power
@branch(label = "Branch ?")
addBranch!(system; from = "Bus 1", to = "Bus 2", turnsRatio = 0.98, reactance = 3.81)
addBranch!(system; from = "Bus 2", to = "Bus 3", reactance = 52.9, susceptance = 5.67e-5)

nothing # hide
```

The first branch represents a transformer, with its reactance specified in ohms on the primary side (from-bus end) and an off-nominal turns ratio of ``\tau = 0.98``. This reactance is then converted to the secondary side and transformed into per-units. The second branch represents a transmission line, with its parameters in SI units, which are also stored in per-units:
```@repl power
prmt = system.branch.parameter;
print(system.branch.label, prmt.reactance, prmt.susceptance, prmt.turnsRatio)
```

---

##### Generators
Finally, we add the same generator as before:
```@example power
@generator(label = "Generator ?")
addGenerator!(system; bus = "Bus 1", active = 230.0, reactive = 20.0)

nothing # hide
```

Using the `active` and `reactive` keywords, we define the three-phase power output of the generator in SI units, and these values are stored in per-units:
```@repl power
output = system.generator.output;
print(system.generator.label, output.active, output.reactive)
```

---

##### AC Power Flow
As before, we can perform AC power flow analysis on our defined power system:
```@example power
analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(analysis)
end
power!(analysis)
nothing # hide
```

---

##### Results
Now, we will examine the results in per-units:
```@example power
@voltage(pu, rad)
@power(pu, pu)

show = Dict("Power Generation" => false, "Shunt Power" => false)
printBusData(analysis; show)
```

Here, the voltage magnitudes in per-units represent line-to-neutral voltages for each bus, while the powers are independent of whether they are three-phase or single-phase, since they are expressed in per-units.