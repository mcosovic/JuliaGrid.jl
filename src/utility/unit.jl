######### Units ##########
mutable struct Unit
    prefixSelect::Dict{String,Float64}
    suffixSelect::Dict{String,Array{String}}
    prefix::Dict{String,Float64}
    suffix::Dict{String,String}
end

"""
JuliaGrid stores all data, with the exception of base values, in per-unit and radians, 
and these cannot be altered. However, the units of the built-in functions can be modified 
using the macro command:
    
    @unit(type; firstUnit, secondUnit)
    
The macro command modifies prefixes and units, where prefixes are defined in accordance 
with the International System of Units. It is important to note that the macro changes 
the unit system associated with the following built-in functions:
* [`addBus!()`](@ref addBus!)
* [`addBranch!()`](@ref addBranch!)
* [`addGenerator!()`](@ref addGenerator!)
* [`shuntBus!()`](@ref shuntBus!)
* [`parameterBranch!()`](@ref parameterBranch!) 
* [`outputGenerator!()`](@ref outputGenerator!).

# Base power and base voltage units
By default, the units for base power and base voltages are set to volt-ampere (VA) and 
volt (V), but prefixes can be modified using the macro:
```jldoctest
@unit(base, MVA, kV)
```
The macro for setting base units must be executed prior to constructing the composite type 
`PowerSystem`.

# Active and reactive power units
By default, the units for active and reactive powers are set to per-units, but these can 
be altered using:
```jldoctest
@unit(power, MW, MVAr)
```
It is also possible to combine SI units with per-units:
```jldoctest
@unit(power, pu, MVAr)
```

# Voltage magnitude and angle units
By default, the units for voltage magnitudes and angles are set to per-unit and radian, 
but these can be modified using:
```jldoctest
@unit(voltage, kV, deg)
```

# Current magnitude and angle units
Similar to the voltage, the units are set to per-unit and radian, and can be altered using:
```jldoctest
@unit(current, A, deg)
```

# Impedance and admitance units
By default, the units for impedances and admitances are set to per-units, but these can be 
modified using:
```jldoctest
@unit(parameter, Ω, kS)
```

# Example
Using the macro, it is possible to define the system of units used in Matpower case files:
```jldoctest
@unit(base, MVA, kV)
@unit(power, MW, MVAr)
@unit(voltage, pu, deg)
```
"""
macro unit(type::Symbol, unitA::Symbol, unitB::Symbol)
    if type == :base
        unitPower = string(unitA)
        suffixPower = parseSuffix(unitPower, "base power")
        unit.prefix["base power"] = parsePrefix(unitPower, suffixPower)

        unitVoltage = string(unitB)
        suffixVoltage = parseSuffix(unitVoltage, "base voltage")
        unit.prefix["base voltage"] = parsePrefix(unitVoltage, suffixVoltage)
    end

    if type == :power
        unitInput = string(unitA)
        unit.suffix["active power"] = parseSuffix(unitInput, "active power")
        unit.prefix["active power"] =  parsePrefix(unitInput, unit.suffix["active power"])
        
        unitInput = string(unitB)
        unit.suffix["reactive power"] = parseSuffix(unitInput, "reactive power")
        unit.prefix["reactive power"] =  parsePrefix(unitInput, unit.suffix["reactive power"])
    end

    if type == :voltage
        unitInput = string(unitA)
        unit.suffix["voltage magnitude"] = parseSuffix(unitInput, "voltage magnitude")
        unit.prefix["voltage magnitude"] =  parsePrefix(unitInput, unit.suffix["voltage magnitude"])
        
        unitInput = string(unitB)
        unit.suffix["voltage angle"] = parseSuffix(unitInput, "voltage angle")
    end

    if type == :current
        unitInput = string(unitA)
        unit.suffix["current magnitude"] = parseSuffix(unitInput, "current magnitude")
        unit.prefix["current magnitude"] =  parsePrefix(unitInput, unit.suffix["current magnitude"])
        
        unitInput = string(unitB)
        unit.suffix["current angle"] = parseSuffix(unitInput, "current angle")
    end

    if type == :parameter
        unitInput = string(unitA)
        unit.suffix["impedance"] = parseSuffix(unitInput, "impedance")
        unit.prefix["impedance"] =  parsePrefix(unitInput, unit.suffix["impedance"])
        
        unitInput = string(unitB)
        unit.suffix["admittance"] = parseSuffix(unitInput, "admittance")
        unit.prefix["admittance"] =  parsePrefix(unitInput, unit.suffix["admittance"])
    end
end

######### Set Default Units ##########
function defaultUnit()
    prefixSelect = Dict("q" => 1e-30, "r" => 1e-27, "y" => 1e-24, "z" => 1e-21, "a" => 1e-18, "f" => 1e-15,
        "p" => 1e-12, "n" => 1e-9, "μ" => 1e-6, "m" => 1e-3, "c" => 1e-2, "d" => 1e-1, "da" => 1e1,
        "h" => 1e2, "k" => 1e3, "M" => 1e6, "G" => 1e9, "T" => 1e12, "P" => 1e15, "E" => 1e18, "Z" => 1e21,
        "Y" => 1e24, "R" => 1e27, "Q" => 1e30)

    suffixSelect = Dict("base power" => ["VA"], "base voltage" => ["V"],
        "active power" => ["W", "pu"], "reactive power" => ["VAr", "pu"],
        "voltage magnitude" => ["V", "pu"], "voltage angle" => ["deg", "rad"],
        "current magnitude" => ["A", "pu"], "current angle" => ["deg", "rad"],
        "impedance" => [string(:Ω), "pu"], "admittance" => ["S", "pu"])

    prefix = Dict("base power" => 1.0, "base voltage" => 1.0,
        "active power" => 1.0, "reactive power" => 1.0,
        "voltage magnitude" => 1.0, "current magnitude" => 1.0,
        "impedance" => 1.0, "admittance" => 1.0)

    suffix = Dict("active power" => "pu", "reactive power" => "pu",
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

