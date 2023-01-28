######### Units ##########
mutable struct Unit
    prefixSelect::Dict{String,Float64}
    suffixSelect::Dict{String,Array{String}}
    prefix::Dict{String,Float64}
    suffix::Dict{String,String}
end

"""
By default, the units for base power and base voltages are set to volt-ampere (VA) and
volt (V), but you can modify the prefixes using the macro:

    @base(power, voltage)

Prefixes must be specified according to the [SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes)
and should be included with the unit of `power` (VA) or unit of `voltage` (V). Keep in mind
that the macro must be used before creating the composite type `PowerSystem`.

# Example
```jldoctest
@base(MVA, kV)
system = powerSystem("case14.h5")
```
"""
macro base(power::Symbol, voltage::Symbol)
    power = string(power)
    suffixPower = parseSuffix(power, "base power")
    unit.prefix["base power"] = parsePrefix(power, suffixPower)

    voltage = string(voltage)
    suffixVoltage = parseSuffix(voltage, "base voltage")
    unit.prefix["base voltage"] = parsePrefix(voltage, suffixVoltage)
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
* [`addBus!()`](@ref addBus!): `active`, `conductance`
* [`shuntBus!()`](@ref shuntBus!): `conductance`
* [`addGenerator!()`](@ref addGenerator!): `active`, `minActive`, `maxActive`, `lowActive`, `upActive`, `loadFollowing`, `reserve10min`, `reserve30min`
* [`addActiveCost!()`](@ref addActiveCost!): `piecewise`, `polynomial`
* [`outputGenerator!()`](@ref outputGenerator!): `active`.

Changing the unit of reactive power unit is reflected in the following quantities:
* [`addBus!()`](@ref addBus!): `reactive`, `susceptance`
* [`shuntBus!()`](@ref shuntBus!): `susceptance`
* [`addGenerator!()`](@ref addGenerator!): `reactive`, `minReactive`, `maxReactive`, `minLowReactive`, `maxLowReactive`, `minUpReactive`, `maxUpReactive`, `reactiveTimescale`
* [`addReactiveCost!()`](@ref addReactiveCost!): `piecewise`, `polynomial`
* [`outputGenerator!()`](@ref outputGenerator!): `reactive`.

Changing the unit of apparent power unit is reflected in the following quantities:
* [`addBranch!()`](@ref addBranch!): `longTerm`, `shortTerm`, `emergency`.

# Example
```jldoctest
@power(MW, kVAr, VA)
```

"""
macro power(active::Symbol, reactive::Symbol, apparent::Symbol)
    active = string(active)
    unit.suffix["active power"] = parseSuffix(active, "active power")
    unit.prefix["active power"] =  parsePrefix(active, unit.suffix["active power"])

    reactive = string(reactive)
    unit.suffix["reactive power"] = parseSuffix(reactive, "reactive power")
    unit.prefix["reactive power"] =  parsePrefix(reactive, unit.suffix["reactive power"])

    apparent = string(apparent)
    unit.suffix["apparent power"] = parseSuffix(apparent, "apparent power")
    unit.prefix["apparent power"] =  parsePrefix(apparent, unit.suffix["apparent power"])
end

"""
JuliaGrid stores all data related with voltages in per-units and radians, and these cannot
be altered. However, the voltage magnitude and angle units of the built-in functions used
to add or modified power system elements can be modified using the macro:

    @voltage(magnitude, angle)

Prefixes must be specified according to the
[SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes) and should be included with
the unit of voltage `magnitude` (V). The second option is to define the unit of voltage
`magnitude` in per-unit (pu). The unit of the voltage `angle` should be given in radian
(rad) or degree (deg).

Changing the unit of voltage magnitude is reflected in the following quantities:
* [`addBus!()`](@ref addBus!): `magnitude`, `minMagnitude`, `maxMagnitude`
* [`addGenerator!()`](@ref addGenerator!): `magnitude`.

Changing the unit of voltage angle is reflected in the following quantities:
* [`addBus!()`](@ref addBus!): `angle`
* [`addBranch!()`](@ref addBranch!): `shiftAngle`, `minDiffAngle`, `maxDiffAngle`
* [`parameterBranch!()`](@ref parameterBranch!): `shiftAngle`.

# Example
```jldoctest
@voltage(kV, deg)
```
"""
macro voltage(magnitude::Symbol, angle::Symbol)
    magnitude = string(magnitude)
    unit.suffix["voltage magnitude"] = parseSuffix(magnitude, "voltage magnitude")
    unit.prefix["voltage magnitude"] =  parsePrefix(magnitude, unit.suffix["voltage magnitude"])

    angle = string(angle)
    unit.suffix["voltage angle"] = parseSuffix(angle, "voltage angle")
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
* [`addBranch!()`](@ref addBranch!): `resistance`, `reactance`
* [`parameterBranch!()`](@ref parameterBranch!): `resistance`, `reactance`.

Changing the units of admittance is reflected in the following quantities:
* [`addBranch!()`](@ref addBranch!): `susceptance`
* [`parameterBranch!()`](@ref parameterBranch!): `susceptance`.

# Example
```jldoctest
@voltage(Ω, pu)
```
"""
macro parameter(impedance::Symbol, admittance::Symbol)
    impedance = string(impedance)
    unit.suffix["impedance"] = parseSuffix(impedance, "impedance")
    unit.prefix["impedance"] =  parsePrefix(impedance, unit.suffix["impedance"])

    admittance = string(admittance)
    unit.suffix["admittance"] = parseSuffix(admittance, "admittance")
    unit.prefix["admittance"] =  parsePrefix(admittance, unit.suffix["admittance"])
end

######### Set Default Units ##########
function defaultUnit()
    prefixSelect = Dict("q" => 1e-30, "r" => 1e-27, "y" => 1e-24, "z" => 1e-21, "a" => 1e-18, "f" => 1e-15,
        "p" => 1e-12, "n" => 1e-9, "μ" => 1e-6, "m" => 1e-3, "c" => 1e-2, "d" => 1e-1, "da" => 1e1,
        "h" => 1e2, "k" => 1e3, "M" => 1e6, "G" => 1e9, "T" => 1e12, "P" => 1e15, "E" => 1e18, "Z" => 1e21,
        "Y" => 1e24, "R" => 1e27, "Q" => 1e30)

    suffixSelect = Dict("base power" => ["VA"], "base voltage" => ["V"],
        "active power" => ["W", "pu"], "reactive power" => ["VAr", "pu"], "apparent power" => ["VA", "pu"],
        "voltage magnitude" => ["V", "pu"], "voltage angle" => ["deg", "rad"],
        "current magnitude" => ["A", "pu"], "current angle" => ["deg", "rad"],
        "impedance" => [string(:Ω), "pu"], "admittance" => ["S", "pu"])

    prefix = Dict("base power" => 1.0, "base voltage" => 1.0,
        "active power" => 1.0, "reactive power" => 1.0, "apparent power" => 1.0,
        "voltage magnitude" => 1.0, "current magnitude" => 1.0,
        "impedance" => 1.0, "admittance" => 1.0)

    suffix = Dict("active power" => "pu", "reactive power" => "pu", "apparent power" => "pu",
        "voltage magnitude" => "pu", "voltage angle" => "rad",
        "current magnitude" => "pu", "current angle" => "rad",
        "impedance" => "pu", "admittance" => "pu")

    return Unit(prefixSelect, suffixSelect, prefix, suffix)
end

######### Parse Suffix (Unit) ##########
function parseSuffix(inputUnit::String, inputType::String)
    suffix = ""
    @inbounds for i in unit.suffixSelect[inputType]
        if endswith(inputUnit, i)
            suffix = i
        end
    end
    if isempty(suffix) || ((suffix == "pu" || suffix == "rad") && suffix != inputUnit)
        error("The unit $inputUnit of $inputType is illegal.")
    end

    return suffix
end

######### Parse Prefix ##########
function parsePrefix(inputUnit::String, suffix::String)
    prefixFloat = 1.0
    if suffix != inputUnit
        prefix = split(inputUnit, suffix)[1]
        if !(prefix in keys(unit.prefixSelect))
            error("The unit prefix $prefix is illegal.")
        else
            prefixFloat = unit.prefixSelect[prefix]
        end
    end

    return prefixFloat
end

######### Transform to per-unit system ##########
function topu(unit::Unit, baseInv::Float64, type::String)
    if unit.suffix[type] == "pu"
        scale = 1.0
    else
        scale = unit.prefix[type] * baseInv
        if scale == Inf
            error("The illegal base value.")
        end
    end

    return scale
end

######### Transform to radians ##########
function torad(unit::Unit, type::String)
    if unit.suffix[type] == "rad"
        scale = 1.0
    else
        scale = pi / 180
    end

    return scale
end

