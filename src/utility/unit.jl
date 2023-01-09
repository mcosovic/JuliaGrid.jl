######### Units ##########
mutable struct Unit
    prefixSelect::Dict{String,Float64}
    suffixSelect::Dict{String,Array{String}}
    prefix::Dict{String,Float64}
    scale::Dict{String,Float64}
end

"""
By default, the units for base power and base voltage are set to volt-amperes (VA) and 
volts (V). The function can be used to change these units by defining the appropriate 
prefixes for the aforementioned units:
   
    baseUnit!(system::PowerSystem; power::Symbol, voltage::Symbol)

Note that the prefixes are defined as specified in the International System of Units.

# Example
```jldoctest
system = powerSystem("case14.h5")
baseUnit!(system; power = :MVA, voltage = :kV)
```
"""
function baseUnit!(system::PowerSystem; power = Symbol(system.base.power.unit)::Symbol, voltage = Symbol(system.base.voltage.unit)::Symbol)
    powerUnit = string(power)
    suffix = parseSuffix(powerUnit, "base power")
    prefix = parsePrefix(powerUnit, suffix)

    system.base.power.threePhase *= unit.prefix["base power"] / prefix
    unit.prefix["base power"] = prefix
    system.base.power.unit = powerUnit

    voltageUnit = string(voltage)
    suffix = parseSuffix(voltageUnit, "base voltage")
    prefix = parsePrefix(voltageUnit, suffix)

    system.base.voltage.lineToLine *= unit.prefix["base voltage"] / prefix
    unit.prefix["base voltage"] = prefix
    system.base.voltage.unit = voltageUnit

    if unit.prefix["active power"] != 1.0
        unit.scale["active power"] = unit.prefix["active power"] / unit.prefix["base power"]
    end
    if unit.prefix["reactive power"] != 1.0
        unit.scale["reactive power"] = unit.prefix["reactive power"] / unit.prefix["base power"]
    end
    if unit.prefix["voltage magnitude"] != 1.0
        unit.scale["voltage magnitude"] = unit.prefix["voltage magnitude"] / unit.prefix["base voltage"]
    end
    if unit.prefix["current magnitude"] != 1.0
        unit.scale["current magnitude"] = unit.prefix["current magnitude"] * unit.prefix["base voltage"] / unit.prefix["base power"]
    end
    if unit.prefix["impedance"] != 1.0
        unit.scale["impedance"] = unit.prefix["impedance"] * unit.prefix["base power"] / (unit.prefix["base voltage"]^2)
    end
    if unit.prefix["admittance"] != 1.0
        unit.scale["admittance"] = unit.prefix["admittance"] *(unit.prefix["base voltage"]^2) / unit.prefix["base power"]
    end
end

######### User Unit Settings ##########
macro unit(args...)
    if args[1] == :power
        activeUnit = string(args[2])
        suffix = parseSuffix(activeUnit, "active power")
        if suffix != "pu"
            prefix =  parsePrefix(activeUnit, suffix)
            unit.scale["active power"] = prefix / unit.prefix["base power"]
            unit.prefix["active power"] = prefix
        end

        reactiveUnit = string(args[3])
        suffix = parseSuffix(reactiveUnit, "reactive power")
        if suffix != "pu"
            prefix =  parsePrefix(reactiveUnit, suffix)
            unit.scale["reactive power"] = prefix / unit.prefix["base power"]
            unit.prefix["reactive power"] = prefix
        end
    end

    if args[1] == :voltage
        magnitude = string(args[2])
        suffix = parseSuffix(magnitude, "voltage magnitude")
        if suffix != "pu"
            prefix =  parsePrefix(magnitude, suffix)
            unit.scale["voltage magnitude"] = prefix / unit.prefix["base voltage"]
            unit.prefix["voltage magnitude"] = prefix
        end

        angle  = string(args[3])
        suffix = parseSuffix(angle, "voltage angle")
        if suffix == "deg"
            unit.scale["voltage angle"] = pi / 180
        end
    end

    if args[1] == :current
        magnitude = string(args[2])
        suffix = parseSuffix(magnitude, "current magnitude")
        if suffix != "pu"
            prefix =  parsePrefix(magnitude, suffix)
            unit.scale["current magnitude"] = prefix * unit.prefix["base voltage"] / unit.prefix["base power"]
            unit.prefix["current magnitude"] = prefix
        end

        angle  = string(args[3])
        suffix = parseSuffix(angle, "current angle")
        if suffix == "deg"
            unit.scale["current angle"] = pi / 180
        end
    end

    if args[1] == :parameter
        impedance = string(args[2])
        suffix = parseSuffix(impedance, "impedance")
        if suffix != "pu"
            prefix =  parsePrefix(impedance, suffix)
            unit.scale["impedance"] = prefix * unit.prefix["base power"] / (unit.prefix["base voltage"]^2)
            unit.prefix["impedance"] = prefix
        end

        admittance = string(args[3])
        suffix = parseSuffix(admittance, "admittance")
        if suffix != "pu"
            prefix =  parsePrefix(admittance, suffix)
            unit.scale["admittance"] = prefix * (unit.prefix["base voltage"]^2) / unit.prefix["base power"]
            unit.prefix["admittance"] = prefix
        end
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

    scale = Dict("active power" => 1.0, "reactive power" => 1.0,
        "voltage magnitude" => 1.0, "voltage angle" => 1.0,
        "current magnitude" => 1.0, "current angle" => 1.0,
        "impedance" => 1.0, "admittance" => 1.0)

    return Unit(prefixSelect, suffixSelect, prefix, scale)
end

######### Parse Suffix (Unit) ##########
function parseSuffix(inputUnit::String, inputType::String)
    suffix = ""
    for i in unit.suffixSelect[inputType]
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

