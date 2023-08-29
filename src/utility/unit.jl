const prefixList = Dict(
    "q" => 1e-30,
    "r" => 1e-27,
    "y" => 1e-24,
    "z" => 1e-21,
    "a" => 1e-18,
    "f" => 1e-15,
    "p" => 1e-12,
    "n" => 1e-9,
    "μ" => 1e-6,
    "m" => 1e-3,
    "c" => 1e-2,
    "d" => 1e-1,
    "da" => 1e1,
    "h" => 1e2,
    "k" => 1e3,
    "M" => 1e6,
    "G" => 1e9,
    "T" => 1e12,
    "P" => 1e15,
    "E" => 1e18,
    "Z" => 1e21,
    "Y" => 1e24,
    "R" => 1e27,
    "Q" => 1e30
    )

const suffixList = Dict(
    :basePower => ["VA"],
    :baseVoltage => ["V"],
    :activePower => ["W", "pu"],
    :reactivePower => ["VAr", "pu"],
    :apparentPower => ["VA", "pu"],
    :voltageMagnitude => ["V", "pu"],
    :voltageAngle => ["deg", "rad"],
    :currentMagnitude => ["A", "pu"],
    :currentAngle => ["deg", "rad"],
    :impedance => [string(:Ω), "pu"],
    :admittance => ["S", "pu"]
    )


Base.@kwdef mutable struct PrefixLive
    activePower::Float64 = 0.0
    reactivePower::Float64 = 0.0
    apparentPower::Float64 = 0.0
    voltageMagnitude::Float64 = 0.0
    voltageAngle::Float64 = 1.0
    currentMagnitude::Float64 = 0.0
    currentAngle::Float64 = 1.0
    impedance::Float64 = 0.0
    admittance::Float64 = 0.0
    baseVoltage::Float64 = 1.0
end
prefix = PrefixLive()

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
    suffixPower = parseSuffix(powerString, :basePower)
    prefixPower = parsePrefix(powerString, suffixPower)

    voltageString = string(voltage)
    suffixVoltage = parseSuffix(voltageString, :baseVoltage)
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
the unit of `active` power (W), `reactive` power (VAr), or `apparent` power (VA). Also it
is a possible to combine SI units with/without prefixes with per-units (pu).

Changing the unit of active power is reflected in the following quantities:
* [`addBus!`](@ref addBus!): `active`, `conductance`,
* [`shuntBus!`](@ref shuntBus!): `conductance`,
* [`addGenerator!`](@ref addGenerator!): `active`, `minActive`, `maxActive`, `lowActive`, `upActive`, `loadFollowing`, `reserve10min`, `reserve30min`,
* [`addActiveCost!`](@ref addActiveCost!): `piecewise`, `polynomial`,
* [`outputGenerator!`](@ref outputGenerator!): `active`,
* [`addBranch!`](@ref addBranch!): `longTerm`, `shortTerm`, `emergency` if rating `type = 2`.

Changing the unit of reactive power unit is reflected in the following quantities:
* [`addBus!`](@ref addBus!): `reactive`, `susceptance`,
* [`shuntBus!`](@ref shuntBus!): `susceptance`,
* [`addGenerator!`](@ref addGenerator!): `reactive`, `minReactive`, `maxReactive`, `minLowReactive`, `maxLowReactive`, `minUpReactive`, `maxUpReactive`, `reactiveTimescale`,
* [`addReactiveCost!`](@ref addReactiveCost!): `piecewise`, `polynomial`,
* [`outputGenerator!`](@ref outputGenerator!): `reactive`.

Changing the unit of apparent power unit is reflected in the following quantities:
* [`addBranch!`](@ref addBranch!): `longTerm`, `shortTerm`, `emergency` if rating `type = 1` or `type = 3`.

# Example
```jldoctest
@power(MW, kVAr, VA)
```
"""
macro power(active::Symbol, reactive::Symbol, apparent::Symbol)
    activeString = string(active)
    suffixUser = parseSuffix(activeString, :activePower)
    prefix.activePower = parsePrefix(activeString, suffixUser)

    reactiveString = string(reactive)
    suffixUser = parseSuffix(reactiveString, :reactivePower)
    prefix.reactivePower = parsePrefix(reactiveString, suffixUser)

    apparentString = string(apparent)
    suffixUser = parseSuffix(apparentString, :apparentPower)
    prefix.apparentPower = parsePrefix(apparentString, suffixUser)
end

"""
    @voltage(magnitude, angle, base)

JuliaGrid stores all data related with voltages in per-units and radians, and these cannot
be altered. However, the voltage magnitude and angle units of the built-in functions used
to add or modified power system elements can be modified using the macro.

The prefixes must adhere to the [SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes)
and should be specified along with the unit of voltage, either `magnitude` (V) or `base` (V).
Alternatively, the unit of voltage `magnitude` can be expressed in per-unit (pu). The unit of
voltage angle should be in radians (rad) or degrees (deg).

Changing the unit of voltage magnitude is reflected in the following quantities:
* [`addBus!`](@ref addBus!): `magnitude`, `minMagnitude`, `maxMagnitude`,
* [`addGenerator!`](@ref addGenerator!): `magnitude`.

Changing the unit of voltage angle is reflected in the following quantities:
* [`addBus!`](@ref addBus!): `angle`,
* [`addBranch!`](@ref addBranch!): `shiftAngle`, `minDiffAngle`, `maxDiffAngle`,
* [`parameterBranch!`](@ref parameterBranch!): `shiftAngle`.

Changing the unit prefix of voltage base is reflected in the following quantity:
* [`addBus!`](@ref addBus!): `base`.

# Example
```jldoctest
@voltage(pu, deg, kV)
```
"""
macro voltage(magnitude::Symbol, angle::Symbol, base::Symbol)
    magnitudeString = string(magnitude)
    suffixUser = parseSuffix(magnitudeString, :voltageMagnitude)
    prefix.voltageMagnitude = parsePrefix(magnitudeString, suffixUser)

    angleString = string(angle)
    suffixUser = parseSuffix(angleString, :voltageAngle)
    prefix.voltageAngle = parsePrefix(angleString, suffixUser)

    baseString = string(base)
    suffixUser = parseSuffix(baseString, :baseVoltage)
    prefix.baseVoltage = parsePrefix(baseString, suffixUser)
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

Changing the unit of current magnitude is reflected in the following quantities:
* [`addAmmeter!`](@ref addAmmeter!): `mean`, `exact`, `variance`.

# Example
```jldoctest
@current(pu, deg)
```
"""
macro current(magnitude::Symbol, angle::Symbol)
    magnitudeString = string(magnitude)
    suffixUser = parseSuffix(magnitudeString, :currentMagnitude)
    prefix.currentMagnitude = parsePrefix(magnitudeString, suffixUser)

    angleString = string(angle)
    suffixUser = parseSuffix(angleString, :currentAngle)
    prefix.currentAngle = parsePrefix(angleString, suffixUser)
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

Changing the units of impedance is reflected in the following quantities in specific
functions:
* [`addBranch!`](@ref addBranch!): `resistance`, `reactance`,
* [`parameterBranch!`](@ref parameterBranch!): `resistance`, `reactance`.

Changing the units of admittance is reflected in the following quantities:
* [`addBranch!`](@ref addBranch!): `susceptance`,
* [`parameterBranch!`](@ref parameterBranch!): `susceptance`.

# Example
```jldoctest
@parameter(Ω, pu)
```
"""
macro parameter(impedance::Symbol, admittance::Symbol)
    impedanceString = string(impedance)
    suffixUser = parseSuffix(impedanceString, :impedance)
    prefix.impedance = parsePrefix(impedanceString, suffixUser)

    admittanceString = string(admittance)
    suffixUser = parseSuffix(admittanceString, :admittance)
    prefix.admittance = parsePrefix(admittanceString, suffixUser)
end

######### Parse Suffix (Unit) ##########
function parseSuffix(input::String, type::Symbol)
    sufixUser = ""
    @inbounds for i in suffixList[type]
        if endswith(input, i)
            sufixUser = i
        end
    end
    if isempty(sufixUser) || (sufixUser in ["pu"; "rad"; "deg"] && sufixUser != input)
        error("The unit $input of $type is illegal.")
    end

    return sufixUser
end

######### Parse Prefix ##########
function parsePrefix(input::String, suffixUser::String)
    if suffixUser == "pu"
        scale = 0.0
    elseif suffixUser == "deg"
        scale = pi / 180
    else
        scale = 1.0
        if suffixUser != input
            prefixUser = split(input, suffixUser)[1]
            if !(prefixUser in keys(prefixList))
                error("The unit prefix $prefixUser is illegal.")
            else
                scale = prefixList[prefixUser]
            end
        end
    end

    return scale
end

######### Impedance Base Value ##########
function baseImpedance(baseVoltage::Float64, basePowerInv::Float64, turnsRatio::Float64)
    base = 1.0
    if prefix.impedance != 0.0 || prefix.admittance != 0.0
        base = (baseVoltage * turnsRatio)^2 * basePowerInv
    end

    return base
end

######### Current Magnitude Base Value ##########
function baseCurrentInverse(basePowerInv::Float64, baseVoltage::Float64)
    base = 1.0
    if prefix.currentMagnitude != 0.0
        base = sqrt(3) * baseVoltage * basePowerInv
    end

    return base
end

######### To Per-Units with Default Values ##########
function topu(value, default, baseInv, prefixLive)
    if ismissing(value)
        if default.pu
            value = default.value
        else
            value = default.value * baseInv
        end
    else
        if prefixLive != 0.0
            value = (value * prefixLive) * baseInv
        end
    end

    return value
end

######### To Per-Units Live ##########
function topu(value, baseInv, prefixLive)
    if prefixLive != 0.0
       value = (value * prefixLive) * baseInv
    end

    return value
end

######### To Radians or Volts with Default Values ##########
function tosi(value, default, prefixLive)
    if ismissing(value)
        value = default
    else
        value = value * prefixLive
    end

    return value
end

######### Unitless Quantities with Default Values ##########
function unitless(value, default)
    if ismissing(value)
        value = default
    end

    return value
end