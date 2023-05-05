const prefix = Dict(
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

const suffix = Dict(
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

const factor = Dict(
    :activePower => 0.0,
    :reactivePower => 0.0,
    :apparentPower => 0.0,
    :voltageMagnitude => 0.0,
    :voltageAngle => 1.0,
    :currentMagnitude => 0.0,
    :currentAngle => 1.0,
    :impedance => 0.0,
    :admittance => 0.0,
    :baseVoltage => 1.0,
    )

"""
By default, the units for base power and base voltages are set to volt-ampere (VA) and volt (V),
but you can modify the prefixes using the macro:

    @base(system::PowerSystem, power, voltage)

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
    power = string(power)
    suffixPower = parseSuffix(power, :basePower)
    prefixPower = parsePrefix(power, suffixPower)

    voltage = string(voltage)
    suffixVoltage = parseSuffix(voltage, :baseVoltage)
    prefixVoltage = parsePrefix(voltage, suffixVoltage)

    return quote
        system = $(esc(system))

        prefixOld = system.base.power.prefix
        system.base.power.value = system.base.power.value * prefixOld / $prefixPower
        system.base.power.prefix = $prefixPower
        system.base.power.unit = $power

        prefixOld = system.base.voltage.prefix
        system.base.voltage.value = system.base.voltage.value * prefixOld / $prefixVoltage
        system.base.voltage.prefix = $prefixVoltage
        system.base.voltage.unit = $voltage
    end
end

"""
JuliaGrid stores all data related with powers in per-units, and these cannot be altered.
However, the power units of the built-in functions used to add or modified power system
elements can be modified using the macro:

    @power(active, reactive, apparent)

Prefixes must be specified according to the
[SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes) and should be included with
the unit of `active` power (W), `reactive` power (VAr), or `apparent` power (VA). Also it is a
possible to combine SI units with/without prefixes with per-units (pu).

Changing the unit of active power is reflected in the following quantities:
* [`addBus!`](@ref addBus!): `active`, `conductance`
* [`shuntBus!`](@ref shuntBus!): `conductance`
* [`addGenerator!`](@ref addGenerator!): `active`, `minActive`, `maxActive`, `lowActive`, `upActive`, `loadFollowing`, `reserve10min`, `reserve30min`
* [`addActiveCost!`](@ref addActiveCost!): `piecewise`, `polynomial`
* [`outputGenerator!`](@ref outputGenerator!): `active`
* [`addBranch!`](@ref addBranch!): `longTerm`, `shortTerm`, `emergency` if rating `type = 2`.

Changing the unit of reactive power unit is reflected in the following quantities:
* [`addBus!`](@ref addBus!): `reactive`, `susceptance`
* [`shuntBus!`](@ref shuntBus!): `susceptance`
* [`addGenerator!`](@ref addGenerator!): `reactive`, `minReactive`, `maxReactive`, `minLowReactive`, `maxLowReactive`, `minUpReactive`, `maxUpReactive`, `reactiveTimescale`
* [`addReactiveCost!`](@ref addReactiveCost!): `piecewise`, `polynomial`
* [`outputGenerator!`](@ref outputGenerator!): `reactive`.

Changing the unit of apparent power unit is reflected in the following quantities:
* [`addBranch!`](@ref addBranch!): `longTerm`, `shortTerm`, `emergency` if rating `type = 1` or `type = 3`.

# Example
```jldoctest
@power(MW, kVAr, VA)
```

"""
macro power(active::Symbol, reactive::Symbol, apparent::Symbol)
    active = string(active)
    suffixUser = parseSuffix(active, :activePower)
    factor[:activePower] = parsePrefix(active, suffixUser)

    reactive = string(reactive)
    suffixUser = parseSuffix(reactive, :reactivePower)
    factor[:reactivePower] = parsePrefix(reactive, suffixUser)

    apparent = string(apparent)
    suffixUser = parseSuffix(apparent, :apparentPower)
    factor[:apparentPower] = parsePrefix(apparent, suffixUser)
end

"""
JuliaGrid stores all data related with voltages in per-units and radians, and these cannot
be altered. However, the voltage magnitude and angle units of the built-in functions used
to add or modified power system elements can be modified using the macro:

    @voltage(magnitude, angle, base)

The prefixes must adhere to the [SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes)
and should be specified along with the unit of voltage, either `magnitude` (V) or `base` (V).
Alternatively, the unit of voltage `magnitude` can be expressed in per-unit (pu). The unit of
voltage angle should be in radians (rad) or degrees (deg).

Changing the unit of voltage magnitude is reflected in the following quantities:
* [`addBus!`](@ref addBus!): `magnitude`, `minMagnitude`, `maxMagnitude`
* [`addGenerator!`](@ref addGenerator!): `magnitude`.

Changing the unit of voltage angle is reflected in the following quantities:
* [`addBus!`](@ref addBus!): `angle`
* [`addBranch!`](@ref addBranch!): `shiftAngle`, `minDiffAngle`, `maxDiffAngle`
* [`parameterBranch!`](@ref parameterBranch!): `shiftAngle`.

Changing the unit prefix of voltage base is reflected in the following quantity:
* [`addBus!`](@ref addBus!): `base`.

# Example
```jldoctest
@voltage(pu, deg, kV)
```
"""
macro voltage(magnitude::Symbol, angle::Symbol, base::Symbol)
    magnitude = string(magnitude)
    suffixUser = parseSuffix(magnitude, :voltageMagnitude)
    factor[:voltageMagnitude] = parsePrefix(magnitude, suffixUser)

    angle = string(angle)
    suffixUser = parseSuffix(angle, :voltageAngle)
    factor[:voltageAngle] = parsePrefix(angle, suffixUser)

    base = string(base)
    suffixUser = parseSuffix(base, :baseVoltage)
    factor[:baseVoltage] = parsePrefix(base, suffixUser)
end

"""
JuliaGrid stores all data related with impedances and admittancies in per-units, and these
cannot be altered. However, units of impedance and admittance of the built-in functions
used to add or modified power system elements can be modified using the macro:

    @parameter(impedance, admittance)

Prefixes must be specified according to the
[SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes) and should be
included with the unit of `impedance` (Ω) or unit of `admittance` (S). The second option is to
define the units in per-unit (pu).

In the case where impedance and admittance are being used in SI units (Ω and S) and these
units are related to the transformer, the assignment must be based on the primary side of
the transformer.

Changing the units of impedance is reflected in the following quantities in specific
functions:
* [`addBranch!`](@ref addBranch!): `resistance`, `reactance`
* [`parameterBranch!`](@ref parameterBranch!): `resistance`, `reactance`.

Changing the units of admittance is reflected in the following quantities:
* [`addBranch!`](@ref addBranch!): `susceptance`
* [`parameterBranch!`](@ref parameterBranch!): `susceptance`.

# Example
```jldoctest
@parameter(Ω, pu)
```
"""
macro parameter(impedance::Symbol, admittance::Symbol)
    impedance = string(impedance)
    suffixUser = parseSuffix(impedance, :impedance)
    factor[:impedance] = parsePrefix(impedance, suffixUser)

    admittance = string(admittance)
    suffixUser = parseSuffix(admittance, :admittance)
    factor[:admittance] = parsePrefix(admittance, suffixUser)
end

######### Parse Suffix (Unit) ##########
function parseSuffix(input::String, type::Symbol)
    sufixUser = ""
    @inbounds for i in suffix[type]
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
            if !(prefixUser in keys(prefix))
                error("The unit prefix $prefixUser is illegal.")
            else
                scale = prefix[prefixUser]
            end
        end
    end

    return scale
end

######### Scale Values to Transform SI to pu ##########
function si2pu(prefix::Float64, base::N, factor::N)
    if factor == 0.0
        scale = 1.0
    else
        scale = factor / (prefix * base)
        if scale == Inf
            error("The illegal base value.")
        end
    end

    return scale
end

######### Impedance Base Value ##########
function baseImpedance(system::PowerSystem, baseVoltage::N, turnsRatio::N)
    base = 1.0
    prefix = 1.0
    if factor[:impedance] != 0.0 || factor[:admittance] != 0.0
        if turnsRatio != 0
            prefix = (turnsRatio * system.base.voltage.prefix)^2 / system.base.power.prefix
        else
            prefix = system.base.voltage.prefix^2 / system.base.power.prefix
        end
        base = baseVoltage^2 / system.base.power.value
    end

    return prefix, base
end