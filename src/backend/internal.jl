"""
    @base(system::PowerSystem, power, voltage)

By default, the units for base power and base voltages are set to volt-ampere (VA) and volt
(V), but you can modify the prefixes using the macro.

Prefixes must be specified according to the [SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes)
and should be included with the unit of `power` (VA) or unit of `voltage` (V). Keep in mind
that the macro must be used after creating the composite type `PowerSystem`.

# Example
```jldoctest
system = powerSystem("case14.h5")
@base(system, MVA, kV)
```
"""
macro base(system::Symbol, power::Symbol, voltage::Symbol)
    powerString = string(power)
    suffixPower = parseSuffix(powerString, unitList.basePower, "base power")
    prefixPower = parsePrefix(powerString, suffixPower)

    voltageString = string(voltage)
    suffixVoltage = parseSuffix(voltageString, unitList.baseVoltage, "base voltage")
    prefixVoltage = parsePrefix(voltageString, suffixVoltage)

    return quote
        system = $(esc(system))

        prefixOld = system.base.power.prefix
        system.base.power.value = system.base.power.value * prefixOld / $prefixPower
        system.base.power.prefix = $prefixPower
        system.base.power.unit = $powerString

        prefixOld = system.base.voltage.prefix
        system.base.voltage.value = system.base.voltage.value * prefixOld / $prefixVoltage
        system.base.voltage.prefix = $prefixVoltage
        system.base.voltage.unit = $voltageString
    end
end

"""
    @power(active, reactive, apparent)

JuliaGrid stores all data related with powers in per-units, and these cannot be altered.
However, the power units of the built-in functions used to add or modified power system
elements can be modified using the macro.

Prefixes must be specified according to the
[SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes) and should be included with
the unit of `active` power (W), `reactive` power (VAr), or `apparent` power (VA). Also, it
is a possible to combine SI units with/without prefixes with per-units (pu).

Changing the unit of `active` power is reflected in the following quantities:
* [`addBus!`](@ref addBus!), [`updateBus!`](@ref updateBus!), [`@bus`](@ref @bus):
  `active`, `conductance`;
* [`addBranch!`](@ref addBranch!), [`updateBranch!`](@ref updateBranch!),
  [`@branch`](@ref @branch): if `type = 2`: `minFromBus`, `maxFromBus`, `minToBus`, `maxToBus`;
* [`addGenerator!`](@ref addGenerator!), [`updateGenerator!`](@ref updateGenerator!),
  [`@generator`](@ref @generator): `active`, `minActive`, `maxActive`, `lowActive`,
  `upActive`, `loadFollowing`, `reserve10min`, `reserve30min`;
* [`cost!`](@ref cost!): if `active`: `piecewise`, `polynomial`;
* [`addWattmeter!`](@ref addWattmeter!), [`updateWattmeter!`](@ref updateWattmeter!):
  `active`, `variance`;
* [`@wattmeter`](@ref @wattmeter): , `varianceBus`, `varianceFrom`, `varianceTo`.

Changing the unit of `reactive` power unit is reflected in the following quantities:
* [`addBus!`](@ref addBus!), [`updateBus!`](@ref updateBus!), [`@bus`](@ref @bus):
  `reactive`, `susceptance`;
* [`addGenerator!`](@ref addGenerator!), [`updateGenerator!`](@ref updateGenerator!),
  [`@generator`](@ref @generator): `reactive`, `minReactive`, `maxReactive`,
  `minLowReactive`, `maxLowReactive`, `minUpReactive`, `maxUpReactive`, `reactiveRamp`;
* [`cost!`](@ref cost!): if `reactive`: `piecewise`, `polynomial`;
* [`addVarmeter!`](@ref addVarmeter!), [`updateVarmeter!`](@ref updateVarmeter!):
  `reactive`, `variance`;
* [`@varmeter`](@ref @varmeter): `varianceBus`, `varianceFrom`, `varianceTo`.

Changing the unit of `apparent` power unit is reflected in the following quantities:
* [`addBranch!`](@ref addBranch!), [`updateBranch!`](@ref updateBranch!),
  [`@branch`](@ref @branch): if `type = 1`: `minFromBus`, `maxFromBus`, `minToBus`, `maxToBus`.

# Example
```jldoctest
@power(MW, kVAr, VA)
```
"""
macro power(active::Symbol, reactive::Symbol, apparent::Symbol)
    unitList.activePowerLive = string(active)
    suffix = parseSuffix(unitList.activePowerLive, unitList.activePower, "active power")
    pfx.activePower = parsePrefix(unitList.activePowerLive , suffix)

    unitList.reactivePowerLive = string(reactive)
    suffix = parseSuffix(unitList.reactivePowerLive, unitList.reactivePower, "reactive power")
    pfx.reactivePower = parsePrefix(unitList.reactivePowerLive, suffix)

    unitList.apparentPowerLive = string(apparent)
    suffix = parseSuffix(unitList.apparentPowerLive, unitList.apparentPower, "apparent power")
    pfx.apparentPower = parsePrefix(unitList.apparentPowerLive, suffix)
end

"""
    @voltage(magnitude, angle, base)

JuliaGrid stores all data related with voltages in per-units and radians, and these cannot
be altered. However, the voltage magnitude and angle units of the built-in functions used
to add or modified power system elements can be modified using the macro.

The prefixes must adhere to the [SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes)
and should be specified along with the unit of voltage, either `magnitude` (V) or `base` (V).
Alternatively, the unit of voltage `magnitude` can be expressed in per-unit (pu). The unit of
voltage `angle` should be in radians (rad) or degrees (deg).

Changing the unit of voltage `magnitude` is reflected in the following quantities:
* [`addBus!`](@ref addBus!), [`updateBus!`](@ref updateBus!), [`@bus`](@ref @bus):
  `magnitude`, `minMagnitude`, `maxMagnitude`;
* [`addGenerator!`](@ref addGenerator!), [`updateGenerator!`](@ref updateGenerator!),
  [`@generator`](@ref @generator): `magnitude`;
* [`addVoltmeter!`](@ref addVoltmeter!), [`updateVoltmeter!`](@ref updateVoltmeter!),
  [`@voltmeter`](@ref @voltmeter): `magnitude`, `variance`;
* [`addPmu!`](@ref addPmu!), [`updatePmu!`](@ref updatePmu!): if `bus`: `magnitude`,
  `varianceMagnitude`;
* [`@pmu`](@ref @pmu): `varianceMagnitudeBus`.

Changing the unit of voltage `angle` is reflected in the following quantities:
* [`addBus!`](@ref addBus!), [`updateBus!`](@ref updateBus!), [`@bus`](@ref @bus): `angle`;
* [`addBranch!`](@ref addBranch!), [`updateBranch!`](@ref updateBranch!),
  [`@branch`](@ref @branch): `shiftAngle`, `minDiffAngle`, `maxDiffAngle`;
* [`addPmu!`](@ref addPmu!), [`updatePmu!`](@ref updatePmu!): if `bus`: `angle`, `varianceAngle`;
* [`@pmu`](@ref @pmu): `varianceAngleBus`.

Changing the unit prefix of voltage `base` is reflected in the following quantity:
* [`addBus!`](@ref addBus!), [`updateBus!`](@ref updateBus!), [`@bus`](@ref @bus): `base`.

# Example
```jldoctest
@voltage(pu, deg, kV)
```
"""
macro voltage(magnitude::Symbol, angle::Symbol, base::Symbol)
    unitList.voltageMagnitudeLive = string(magnitude)
    suffix = parseSuffix(unitList.voltageMagnitudeLive, unitList.voltageMagnitude, "voltage magnitude")
    pfx.voltageMagnitude = parsePrefix(unitList.voltageMagnitudeLive, suffix)

    unitList.voltageAngleLive = string(angle)
    suffix = parseSuffix(unitList.voltageAngleLive, unitList.voltageAngle, "voltage angle")
    pfx.voltageAngle = parsePrefix(unitList.voltageAngleLive, suffix)

    baseString = string(base)
    suffix = parseSuffix(baseString, unitList.baseVoltage, "base voltage")
    pfx.baseVoltage = parsePrefix(baseString, suffix)
end

"""
    @current(magnitude, angle)

JuliaGrid stores all data related with currents in per-units and radians, and these cannot
be altered. However, the current magnitude and angle units of the built-in functions used
to add or modified measurement devices can be modified using the macro.

The prefixes must adhere to the [SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes)
and should be specified along with the unit of current `magnitude` (V).
Alternatively, the unit of current `magnitude` can be expressed in per-unit (pu). The unit
of current angle should be in radians (rad) or degrees (deg).

Changing the unit of current `magnitude` is reflected in the following quantities:
* [`addBranch!`](@ref addBranch!), [`updateBranch!`](@ref updateBranch!),
  [`@branch`](@ref @branch): if `type = 3`: `minFromBus`, `maxFromBus`, `minToBus`, `maxToBus`.
* [`addAmmeter!`](@ref addAmmeter!), [`updateAmmeter!`](@ref updateAmmeter!):
  `magnitude`, `variance`;
* [`@ammeter`](@ref @ammeter): `varianceFrom`, `varianceTo`;
* [`addPmu!`](@ref addPmu!), [`updatePmu!`](@ref updatePmu!): if `from` or `to`:
  `magnitude`, `varianceMagnitude`;
* [`@pmu`](@ref @pmu): `varianceMagnitudeFrom`, `varianceMagnitudeTo`.

Changing the unit of current `angle` is reflected in the following quantities:
* [`addPmu!`](@ref addPmu!), [`updatePmu!`](@ref updatePmu!): if `from` or `to`:
  `angle`, `varianceAngle`;
* [`@pmu`](@ref @pmu): `varianceAngleFrom`, `varianceAngleTo`.

# Example
```jldoctest
@current(pu, deg)
```
"""
macro current(magnitude::Symbol, angle::Symbol)
    unitList.currentMagnitudeLive = string(magnitude)
    suffix = parseSuffix(unitList.currentMagnitudeLive, unitList.currentMagnitude, "current magnitude")
    pfx.currentMagnitude = parsePrefix(unitList.currentMagnitudeLive, suffix)

    unitList.currentAngleLive = string(angle)
    suffix = parseSuffix(unitList.currentAngleLive, unitList.currentAngle, "current angle")
    pfx.currentAngle = parsePrefix(unitList.currentAngleLive, suffix)
end

"""
    @parameter(impedance, admittance)

JuliaGrid stores all data related with impedances and admittancies in per-units, and these
cannot be altered. However, units of impedance and admittance of the built-in functions
used to add or modified power system elements can be modified using the macro.

Prefixes must be specified according to the
[SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes) and should be
included with the unit of `impedance` (Ω) or unit of `admittance` (S). The second option
is to define the units in per-unit (pu).

In the case where impedance and admittance are being used in SI units (Ω and S) and these
units are related to the transformer, the assignment must be based on the primary side of
the transformer.

Changing the units of `impedance` is reflected in the following quantities in specific
functions:
* [`addBranch!`](@ref addBranch!), [`updateBranch!`](@ref updateBranch!),
  [`@branch`](@ref @branch): `resistance`, `reactance`.

Changing the units of `admittance` is reflected in the following quantities:
* [`addBranch!`](@ref addBranch!), [`updateBranch!`](@ref updateBranch!),
  [`@branch`](@ref @branch): `conductance`, `susceptance`.

# Example
```jldoctest
@parameter(Ω, pu)
```
"""
macro parameter(impedance::Symbol, admittance::Symbol)
    impedanceString = string(impedance)
    suffix = parseSuffix(impedanceString, unitList.impedance, "impedance")
    pfx.impedance = parsePrefix(impedanceString, suffix)

    admittanceString = string(admittance)
    suffix = parseSuffix(admittanceString, unitList.admittance, "admittance")
    pfx.admittance = parsePrefix(admittanceString, suffix)
end

"""
    @labels(type)

JuliaGrid keeps all labels in ordered dictionaries as Strings. Users have the option to
use Integers instead, which can be a more efficient way to store labels, particularly for
large-scale systems.

# Example
```jldoctest
@labels(Integer)
```
"""
macro labels(type::Symbol)
    if type == :Integer || type == :Int64
        template.system = Int64
        template.device = Int64
    end
    if type == :String
        template.system = String
        template.device = String
    end
end


##### Parse Suffix (Unit) #####
function parseSuffix(input::String, unitList, type::String)
    suffix = ""
    @inbounds for i in unitList
        if endswith(input, i)
            suffix = i
        end
    end
    if isempty(suffix) || (suffix in ["pu"; "rad"; "deg"] && suffix != input)
        throw(ErrorException("The unit " * input * " of " * type * " is illegal."))
    end

    return suffix
end

##### Parse Prefix #####
function parsePrefix(input::String, suffix::String)
    if suffix in ["pu"; "rad"]
        scale = 0.0
    elseif suffix == "deg"
        scale = pi / 180
    else
        scale = 1.0
        if suffix != input
            prefix = split(input, suffix)[1]
            if !(prefix in keys(prefixList))
                throw(ErrorException("The unit prefix " * prefix * " is illegal."))
            else
                scale = prefixList[prefix]
            end
        end
    end

    return scale
end

"""
    @default(mode)

The macro is designed to reset various settings to their default values.

The `mode` argument can take on the following values:
* `unit`: Resets all units to their default settings.
* `power`: Sets active, reactive, and apparent power to per-units.
* `voltage`: Sets voltage magnitude to per-unit and voltage angle to radian.
* `parameter`: Sets impedance and admittance to per-units.
* `template`: Resets bus, branch, generator, voltmeter, ammeter, wattmeter, varmeter,
  and pmu templates to their default settings.
* `bus`: Resets the bus template to its default settings.
* `branch`: Resets the branch template to its default settings.
* `generator`: Resets the generator template to its default settings.
* `voltmeter`: Resets the voltmeter template to its default settings.
* `ammeter`: Resets the ammeter template to its default settings.
* `wattmeter`: Resets the wattmeter template to its default settings.
* `varmeter`: Resets the varmeter template to its default settings.
* `pmu`: Resets the pmu template to its default settings.

# Example
```jldoctest
@default(unit)
```
"""
macro default(mode::Symbol)
    if mode == :unit || mode == :power
        pfx.activePower = 0.0
        pfx.reactivePower = 0.0
        pfx.apparentPower = 0.0
        unitList.activePowerLive = "pu"
        unitList.reactivePowerLive = "pu"
    end

    if mode == :unit || mode == :voltage
        pfx.voltageMagnitude = 0.0
        pfx.voltageAngle = 0.0
        pfx.baseVoltage = 1.0
        unitList.voltageMagnitudeLive = "pu"
        unitList.voltageAngleLive = "rad"
    end

    if mode == :unit || mode == :current
        pfx.currentMagnitude = 0.0
        pfx.currentAngle = 0.0
        unitList.currentMagnitudeLive = "pu"
        unitList.currentAngleLive = "rad"
    end

    if mode == :unit || mode == :parameter
        pfx.impedance = 0.0
        pfx.admittance = 0.0
    end

    if mode == :template || mode == :bus
        template.bus.active.value = 0.0
        template.bus.active.pu = true
        template.bus.reactive.value = 0.0
        template.bus.reactive.pu = true

        template.bus.conductance.value = 0.0
        template.bus.conductance.pu = true
        template.bus.susceptance.value = 0.0
        template.bus.susceptance.pu = true

        template.bus.magnitude.value = 1.0
        template.bus.magnitude.pu = true
        template.bus.minMagnitude.value = 0.9
        template.bus.minMagnitude.pu = true
        template.bus.maxMagnitude.value = 1.1
        template.bus.maxMagnitude.pu = true

        template.bus.angle.value = 0.0
        template.bus.angle.pu = true

        template.bus.label = "?"
        template.bus.base = 138e3
        template.bus.type = Int8(1)
        template.bus.area = 1
        template.bus.lossZone = 1
    end

    if mode == :template || mode == :branch
        template.branch.resistance.value = 0.0
        template.branch.resistance.pu = true
        template.branch.reactance.value = 0.0
        template.branch.reactance.pu = true
        template.branch.conductance.value = 0.0
        template.branch.conductance.pu = true
        template.branch.susceptance.value = 0.0
        template.branch.susceptance.pu = true
        template.branch.shiftAngle.value = 0.0
        template.branch.shiftAngle.pu = true

        template.branch.minDiffAngle.value = -2*pi
        template.branch.minDiffAngle.pu = true
        template.branch.maxDiffAngle.value = 2*pi
        template.branch.maxDiffAngle.pu = true

        template.branch.minFromBus.value = 0.0
        template.branch.minFromBus.pu = true
        template.branch.maxFromBus.value = 0.0
        template.branch.maxFromBus.pu = true
        template.branch.minToBus.value = 0.0
        template.branch.minToBus.pu = true
        template.branch.maxToBus.value = 0.0
        template.branch.maxToBus.pu = true

        template.branch.label = "?"
        template.branch.turnsRatio = 1.0
        template.branch.status = Int8(1)
        template.branch.type = Int8(1)
    end

    if mode == :template || mode == :generator
        template.generator.active.value = 0.0
        template.generator.active.pu = true
        template.generator.reactive.value = 0.0
        template.generator.reactive.pu = true

        template.generator.magnitude.value = 1.0
        template.generator.magnitude.pu = true

        template.generator.minActive.value = 0.0
        template.generator.minActive.pu = true
        template.generator.maxActive.value = 0.0
        template.generator.maxActive.pu = true
        template.generator.minReactive.value = 0.0
        template.generator.minReactive.pu = true
        template.generator.maxReactive.value = 0.0
        template.generator.maxReactive.pu = true

        template.generator.lowActive.value = 0.0
        template.generator.lowActive.pu = true
        template.generator.minLowReactive.value = 0.0
        template.generator.minLowReactive.pu = true
        template.generator.maxLowReactive.value = 0.0
        template.generator.maxLowReactive.pu = true

        template.generator.upActive.value = 0.0
        template.generator.upActive.pu = true
        template.generator.minUpReactive.value = 0.0
        template.generator.minUpReactive.pu = true
        template.generator.maxUpReactive.value = 0.0
        template.generator.maxUpReactive.pu = true

        template.generator.loadFollowing.value = 0.0
        template.generator.loadFollowing.pu = true
        template.generator.reactiveRamp.value = 0.0
        template.generator.reactiveRamp.pu = true
        template.generator.reserve10min.value = 0.0
        template.generator.reserve10min.pu = true
        template.generator.reserve30min.value = 0.0
        template.generator.reserve30min.pu = true

        template.generator.label = "?"
        template.generator.status = Int8(1)
        template.generator.area = 0
    end

    if mode == :template || mode == :voltmeter
        template.voltmeter.variance.value = 1e-2
        template.voltmeter.variance.pu = true

        template.voltmeter.status = Int8(1)
        template.voltmeter.label = "?"
        template.voltmeter.noise = false
    end

    if mode == :template || mode == :ammeter
      template.ammeter.varianceFrom.value = 1e-2
      template.ammeter.varianceFrom.pu = true
      template.ammeter.varianceTo.value = 1e-2
      template.ammeter.varianceTo.pu = true

      template.ammeter.statusFrom = Int8(1)
      template.ammeter.statusTo = Int8(1)

      template.ammeter.label = "?"
      template.ammeter.noise = false
    end

    if mode == :template || mode == :wattmeter
      template.wattmeter.varianceBus.value = 1e-2
      template.wattmeter.varianceBus.pu = true
      template.wattmeter.varianceFrom.value = 1e-2
      template.wattmeter.varianceFrom.pu = true
      template.wattmeter.varianceTo.value = 1e-2
      template.wattmeter.varianceTo.pu = true

      template.wattmeter.statusBus = Int8(1)
      template.wattmeter.statusFrom = Int8(1)
      template.wattmeter.statusTo = Int8(1)

      template.wattmeter.label = "?"
      template.wattmeter.noise = false
    end

    if mode == :template || mode == :varmeter
      template.varmeter.varianceBus.value = 1e-2
      template.varmeter.varianceBus.pu = true
      template.varmeter.varianceFrom.value = 1e-2
      template.varmeter.varianceFrom.pu = true
      template.varmeter.varianceTo.value = 1e-2
      template.varmeter.varianceTo.pu = true

      template.varmeter.statusBus = Int8(1)
      template.varmeter.statusFrom = Int8(1)
      template.varmeter.statusTo = Int8(1)

      template.varmeter.label = "?"
      template.varmeter.noise = false
    end

    if mode == :template || mode == :pmu
      template.pmu.varianceMagnitudeBus.value = 1e-5
      template.pmu.varianceMagnitudeBus.pu = true
      template.pmu.varianceAngleBus.value = 1e-5
      template.pmu.varianceAngleBus.pu = true

      template.pmu.varianceMagnitudeFrom.value = 1e-5
      template.pmu.varianceMagnitudeFrom.pu = true
      template.pmu.varianceAngleFrom.value = 1e-5
      template.pmu.varianceAngleFrom.pu = true

      template.pmu.varianceMagnitudeTo.value = 1e-5
      template.pmu.varianceMagnitudeTo.pu = true
      template.pmu.varianceAngleTo.value = 1e-5
      template.pmu.varianceAngleTo.pu = true

      template.pmu.statusMagnitudeBus = Int8(1)
      template.pmu.statusAngleBus = Int8(1)

      template.pmu.statusMagnitudeFrom = Int8(1)
      template.pmu.statusAngleFrom = Int8(1)

      template.pmu.statusMagnitudeTo = Int8(1)
      template.pmu.statusAngleTo = Int8(1)

      template.pmu.label = "?"
      template.pmu.noise = false
      template.pmu.correlated = false
      template.pmu.polar = false
    end

    if mode == :template
        template.system = String
        template.device = String
    end
end