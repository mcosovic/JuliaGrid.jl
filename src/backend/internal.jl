"""
    @base(system::PowerSystem, power, voltage)

By default, the units for base power and base voltages are set to volt-ampere (VA) and volt (V), but
users can modify the prefixes using the macro.

The macro modifies global JuliaGrid settings that remain active until changed again.

Prefixes must be specified according to the [SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes)
and should be included with the unit of `power` (VA) or unit of `voltage` (V). Keep in mind that the
macro must be used after creating the type `PowerSystem`.

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
        local sys = $(esc(system))

        prefixOld = sys.base.power.prefix
        sys.base.power.value = sys.base.power.value * prefixOld / $prefixPower
        sys.base.power.prefix = $prefixPower
        sys.base.power.unit = $powerString

        prefixOld = sys.base.voltage.prefix
        sys.base.voltage.value = sys.base.voltage.value * prefixOld / $prefixVoltage
        sys.base.voltage.prefix = $prefixVoltage
        sys.base.voltage.unit = $voltageString
    end
end

"""
    @power(active, reactive, apparent)

JuliaGrid stores all data related with powers in per-units, and these cannot be altered. However, the
power units of the built-in functions used to add or modified power system elements can be modified
using the macro.

The macro modifies global JuliaGrid settings that remain active until changed again.

Prefixes must be specified according to the [SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes)
and should be included with the unit of `active` power (W), `reactive` power (VAr), or `apparent` power
(VA). Also, it is a possible to combine SI units with/without prefixes with per-units (pu).

Changing the unit of `active` power is reflected in the following quantities:
* [`addBus!`](@ref addBus!), [`updateBus!`](@ref updateBus!), [`@bus`](@ref @bus):
`active`, `conductance`;
* [`addBranch!`](@ref addBranch!), [`updateBranch!`](@ref updateBranch!),
  [`@branch`](@ref @branch): if `type = 2`: `minFromBus`, `maxFromBus`, `minToBus`, `maxToBus`;
* [`addGenerator!`](@ref addGenerator!), [`updateGenerator!`](@ref updateGenerator!),
  [`@generator`](@ref @generator): `active`, `minActive`, `maxActive`, `lowActive`,
  `upActive`;
* [`cost!`](@ref cost!): if `active`: `piecewise`, `polynomial`;
* [`addWattmeter!`](@ref addWattmeter!), [`updateWattmeter!`](@ref updateWattmeter!):
  `active`, `variance`;
* [`@wattmeter`](@ref @wattmeter): , `varianceBus`, `varianceFrom`, `varianceTo`.

Changing the unit of `reactive` power unit is reflected in the following quantities:
* [`addBus!`](@ref addBus!), [`updateBus!`](@ref updateBus!), [`@bus`](@ref @bus):
  `reactive`, `susceptance`;
* [`addGenerator!`](@ref addGenerator!), [`updateGenerator!`](@ref updateGenerator!),
  [`@generator`](@ref @generator): `reactive`, `minReactive`, `maxReactive`,
  `minLowReactive`, `maxLowReactive`, `minUpReactive`, `maxUpReactive`;
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
macro power(active::Symbol = :pu, reactive::Symbol = :pu, apparent::Symbol = :pu)
    quote
        unitList.activePowerLive = string($(QuoteNode(active)))
        local suffix = parseSuffix(unitList.activePowerLive, unitList.activePower, "active power")
        pfx.activePower = parsePrefix(unitList.activePowerLive, suffix)

        unitList.reactivePowerLive = string($(QuoteNode(reactive)))
        local suffix = parseSuffix(unitList.reactivePowerLive, unitList.reactivePower, "reactive power")
        pfx.reactivePower = parsePrefix(unitList.reactivePowerLive, suffix)

        unitList.apparentPowerLive = string($(QuoteNode(apparent)))
        local suffix = parseSuffix(unitList.apparentPowerLive, unitList.apparentPower, "apparent power")
        pfx.apparentPower = parsePrefix(unitList.apparentPowerLive, suffix)
    end
end

"""
    @voltage(magnitude, angle, base)

JuliaGrid stores all data related with voltages in per-units and radians, and these cannot be altered.
However, the voltage magnitude and angle units of the built-in functions used to add or modified power
system elements can be modified using the macro.

The macro modifies global JuliaGrid settings that remain active until changed again.

The prefixes must adhere to the [SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes) and
should be specified along with the unit of voltage, either `magnitude` (V) or `base` (V).
Alternatively, the unit of voltage `magnitude` can be expressed in per-unit (pu). The unit of voltage
`angle` should be in radians (rad) or degrees (deg).

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
macro voltage(magnitude::Symbol = :pu, angle::Symbol = :rad, base::Symbol = :V)
    quote
        unitList.voltageMagnitudeLive = string($(QuoteNode(magnitude)))
        local suffix = parseSuffix(unitList.voltageMagnitudeLive, unitList.voltageMagnitude, "voltage magnitude")
        pfx.voltageMagnitude = parsePrefix(unitList.voltageMagnitudeLive, suffix)

        unitList.voltageAngleLive = string($(QuoteNode(angle)))
        local suffix = parseSuffix(unitList.voltageAngleLive, unitList.voltageAngle, "voltage angle")
        pfx.voltageAngle = parsePrefix(unitList.voltageAngleLive, suffix)

        unitList.voltageBaseLive = string($(QuoteNode(base)))
        local suffix = parseSuffix(unitList.voltageBaseLive, unitList.baseVoltage, "base voltage")
        pfx.baseVoltage = parsePrefix(unitList.voltageBaseLive, suffix)
    end
end

"""
    @current(magnitude, angle)

JuliaGrid stores all data related with currents in per-units and radians, and these cannot be altered.
However, the current magnitude and angle units of the built-in functions used to add or modified
measurement devices can be modified using the macro.

The macro modifies global JuliaGrid settings that remain active until changed again.

The prefixes must adhere to the [SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes) and
should be specified along with the unit of current `magnitude` (V). Alternatively, the unit of current
`magnitude` can be expressed in per-unit (pu). The unit of current angle should be in radians (rad)
or degrees (deg).

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
macro current(magnitude::Symbol = :pu, angle::Symbol = :rad)
    quote
        unitList.currentMagnitudeLive = string($(QuoteNode(magnitude)))
        local suffix = parseSuffix(unitList.currentMagnitudeLive, unitList.currentMagnitude, "current magnitude")
        pfx.currentMagnitude = parsePrefix(unitList.currentMagnitudeLive, suffix)

        unitList.currentAngleLive = string($(QuoteNode(angle)))
        suffix = parseSuffix(unitList.currentAngleLive, unitList.currentAngle, "current angle")
        pfx.currentAngle = parsePrefix(unitList.currentAngleLive, suffix)
    end
end

"""
    @parameter(impedance, admittance)

JuliaGrid stores all data related with impedances and admittancies in per-units, and these cannot be
altered. However, units of impedance and admittance of the built-in functions used to add or modified
power system elements can be modified using the macro.

The macro modifies global JuliaGrid settings that remain active until changed again.

Prefixes must be specified according to the [SI prefixes](https://www.nist.gov/pml/owm/metric-si-prefixes)
and should be included with the unit of `impedance` (Ω) or unit of `admittance` (S). The second option
is to define the units in per-unit (pu).

In the case where impedance and admittance are being used in SI units (Ω and S) and these units are
related to the transformer, the assignment must be based on the primary side of the transformer.

Changing the units of `impedance` is reflected in the following quantities in specific functions:
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
macro parameter(impedance::Symbol = :pu, admittance::Symbol = :pu)
    quote
        unitList.impedanceLive = string($(QuoteNode(impedance)))
        local suffix = parseSuffix(unitList.impedanceLive, unitList.impedance, "impedance")
        pfx.impedance = parsePrefix(unitList.impedanceLive, suffix)

        unitList.admittanceLive = string($(QuoteNode(admittance)))
        local suffix = parseSuffix(unitList.admittanceLive, unitList.admittance, "admittance")
        pfx.admittance = parsePrefix(unitList.admittanceLive, suffix)
    end
end

function setConfigTemplate!(parameter::Symbol, value)
    if parameter == :label
        datatype = value in (Integer, Int64, :Integer, :Int64) ? Int64 : String

        for container in (
            template.bus,
            template.branch,
            template.generator,
            template.voltmeter,
            template.ammeter,
            template.wattmeter,
            template.varmeter,
            template.pmu
        )
            setfield!(container, :key, datatype)
        end
    elseif parameter == :verbose
        setfield!(template.config, :verbose, Int64(value))
    end
end

"""
    @config(label, verbose)

The macro defines general configuration settings for JuliaGrid.

The macro modifies global JuliaGrid settings that remain active until changed again.

By default, JuliaGrid stores all labels as strings in ordered dictionaries. However, users can choose
to store labels as integers, which can be a more efficient option for large-scale systems.

Users can also adjust the level of printed information for the algorithms used in JuliaGrid.
The `verbose` setting is multilevel and can take the following values:
  * `verbose = 0`: Silent mode (default).
  * `verbose = 1`: Prints exit messages.
  * `verbose = 2`: Prints algorithm solver progress data.
  * `verbose = 3`: Prints detailed data.

# Examples
Set labels as integers and print only basic data:
```jldoctest
@config(label = Integer, verbose = 1)
```

Set labels as strings and enable detailed data printing:
```jldoctest
@config(label = String, verbose = 3)
```
"""
macro config(kwargs...)
    exprs = map(kwargs) do kwarg
        if !(kwarg isa Expr) || kwarg.head != :(=)
            return :(nothing)
        end

        parameter = kwarg.args[1]
        value = kwarg.args[2]

        :(setConfigTemplate!($(QuoteNode(parameter)), $(esc(value))))
    end

    return Expr(:block, exprs...)
end

##### Parse Suffix (Unit) #####
function parseSuffix(input::String, unitList, type::String)
    suffix = ""
    @inbounds for i in unitList
        if endswith(input, i) && length(i) > length(suffix)
            suffix = i
        end
    end
    if isempty(suffix) || (suffix ∈ ("pu", "rad", "deg") && suffix != input)
        throw(ErrorException("The unit " * input * " of " * type * " is illegal."))
    end

    return suffix
end

##### Parse Prefix #####
function parsePrefix(input::String, suffix::String)
    if suffix in ("pu", "rad")
        scale = 0.0
    elseif suffix == "deg"
        scale = pi / 180
    else
        scale = 1.0
        if suffix != input
            prefix = input[1:(end - length(suffix))]
            if prefix ∉ keys(prefixList)
                throw(ErrorException("The unit prefix " * prefix * " is illegal."))
            else
                scale = prefixList[prefix]
            end
        end
    end

    return scale
end

function resetPowerUnit!()
    pfx.activePower = 0.0
    pfx.reactivePower = 0.0
    pfx.apparentPower = 0.0
    unitList.activePowerLive = "pu"
    unitList.reactivePowerLive = "pu"
    unitList.apparentPowerLive = "pu"
end

function resetVoltageUnit!()
    pfx.voltageMagnitude = 0.0
    pfx.voltageAngle = 0.0
    pfx.baseVoltage = 1.0
    unitList.voltageMagnitudeLive = "pu"
    unitList.voltageAngleLive = "rad"
    unitList.voltageBaseLive = "V"
end

function resetCurrentUnit!()
    pfx.currentMagnitude = 0.0
    pfx.currentAngle = 0.0
    unitList.currentMagnitudeLive = "pu"
    unitList.currentAngleLive = "rad"
end

function resetParameterUnit!()
    pfx.impedance = 0.0
    pfx.admittance = 0.0
    unitList.impedanceLive = "pu"
    unitList.admittanceLive = "pu"
end

function copyTemplate!(dst::ContainerTemplate, src::ContainerTemplate)
    dst.value = src.value
    dst.pu = src.pu
end

function copyTemplate!(dst, src)
    for field in fieldnames(typeof(src))
        srcValue = getfield(src, field)
        dstValue = getfield(dst, field)

        if srcValue isa ContainerTemplate && dstValue isa ContainerTemplate
            copyTemplate!(dstValue, srcValue)
        else
            setfield!(dst, field, srcValue)
        end
    end
end

function resetBusTemplate!()
    copyTemplate!(template.bus, BusTemplate(; area = 1, lossZone = 1))
end

function resetBranchTemplate!()
    copyTemplate!(template.branch, BranchTemplate())
end

function resetGeneratorTemplate!()
    copyTemplate!(template.generator, GeneratorTemplate())
end

function resetVoltmeterTemplate!()
    copyTemplate!(template.voltmeter, VoltmeterTemplate())
end

function resetAmmeterTemplate!()
    copyTemplate!(template.ammeter, AmmeterTemplate())
end

function resetWattmeterTemplate!()
    copyTemplate!(template.wattmeter, WattmeterTemplate())
end

function resetVarmeterTemplate!()
    copyTemplate!(template.varmeter, VarmeterTemplate())
end

function resetPmuTemplate!()
    copyTemplate!(template.pmu, PmuTemplate())
end

function resetConfigTemplate!()
    copyTemplate!(template.config, ConfigTemplate())
end

"""
    @default(mode)

The macro is designed to reset various settings to their default values.

The macro modifies global JuliaGrid settings that remain active until changed again.

The `mode` argument can take on the following values:
* `unit`: Restores all units to their default settings.
* `power`: Converts active, reactive, and apparent power to per-unit values.
* `voltage`: Expresses voltage magnitude in per-unit and voltage angle in radians.
* `current`: Expresses current magnitude in per-unit and current angle in radians.
* `parameter`: Converts impedance and admittance to per-unit values.
* `bus`: Resets the bus template to its default configuration.
* `branch`: Resets the branch template to its default configuration.
* `generator`: Resets the generator template to its default configuration.
* `voltmeter`: Resets the voltmeter template to its default configuration.
* `ammeter`: Resets the ammeter template to its default configuration.
* `wattmeter`: Resets the wattmeter template to its default configuration.
* `varmeter`: Resets the varmeter template to its default configuration.
* `pmu`: Resets the PMU template to its default configuration.
* `template`: Restores all templates and configurations to their default settings.

# Example
```jldoctest
@default(template)
```
"""
macro default(mode::Symbol)
    quote
        local mode = $(QuoteNode(mode))

        if mode == :unit || mode == :power
            resetPowerUnit!()
        end

        if mode == :unit || mode == :voltage
            resetVoltageUnit!()
        end

        if mode == :unit || mode == :current
            resetCurrentUnit!()
        end

        if mode == :unit || mode == :parameter
            resetParameterUnit!()
        end

        if mode == :template || mode == :bus
            resetBusTemplate!()
        end

        if mode == :template || mode == :branch
            resetBranchTemplate!()
        end

        if mode == :template || mode == :generator
            resetGeneratorTemplate!()
        end

        if mode == :template || mode == :voltmeter
            resetVoltmeterTemplate!()
        end

        if mode == :template || mode == :ammeter
            resetAmmeterTemplate!()
        end

        if mode == :template || mode == :wattmeter
            resetWattmeterTemplate!()
        end

        if mode == :template || mode == :varmeter
            resetVarmeterTemplate!()
        end

        if mode == :template || mode == :pmu
            resetPmuTemplate!()
        end

        if mode == :template
            resetConfigTemplate!()
        end
    end
end