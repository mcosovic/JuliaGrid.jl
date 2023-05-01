######### Check Package Path ##########
@inline function checkPackagePath()
    pathtoJuliaGrid = pathof(JuliaGrid)
    if pathtoJuliaGrid === nothing
        throw(ErrorException("JuliaGrid not found in install packages."))
    end
    packagePath = abspath(joinpath(dirname(pathtoJuliaGrid), ".."))

    return packagePath
end

######### Check File Format ##########
@inline function checkFileFormat(inputFile::String, packagePath::String)
    extension = ""; path = ""; dataname = ""; fullpath = ""
    try
        extension = string(match(r"\.[A-Za-z0-9]+$", inputFile).match)
    catch
        extension = ""
    end
    if extension == ".h5" || extension == ".m"
        fullpath = inputFile
        path = dirname(inputFile)
        dataname = basename(inputFile)
    end

    if isempty(extension)
        throw(ErrorException("The extension is missing."))
    elseif extension != ".h5" && extension != ".m"
        throw(DomainError(extension, "The extension $extension is not supported."))
    end

    if path == ""
        path = joinpath(packagePath, "src/data/")
        fullpath = joinpath(packagePath, "src/data/", dataname)
    end

    if !(dataname in cd(readdir, path))
        throw(DomainError(dataname, "The input data $dataname is not found."))
    end

    return fullpath, extension
end

######### Renumbering #########
@inline function runRenumbering(newIndex::Array{Int64,1}, indexNumber::Int64, lookup::Dict{Int64,Int64})
    @inbounds for i = 1:indexNumber
        newIndex[i] = lookup[newIndex[i]]
    end

    return newIndex
end

######### Check Minimal Data Structure for Power System ##########
@inline function dataStructure(Ncol::Int64, max::Int64; var::String = "", name::String = "")
    if Ncol < max
        throw(DomainError(var, "The minimum input data structure contained in $name is not satisfied."))
    end
end

######### Error Voltage ##########
@inline function errorVoltage(voltage)
    if isempty(voltage)
        error("The voltage values are missing.")
    end
end

"""
The macro is designed to reset various settings to their default values.

    @default(mode)

The `mode` argument can take on the following values:
* `unit`: resets all units to their default settings
* `power`: sets active, reactive, and apparent power to per-units
* `voltage`: sets voltage magnitude to per-unit and voltage angle to radian
* `parameter`: sets impedance and admittance to per-units
* `template`: resets bus, branch and generator templates to their default settings
* `bus`: resets the bus template to its default settings
* `branch`: resets the branch template to its default settings
* `generator`: resets the generator template to its default settings.

# Example
```jldoctest
@default(unit)
```
"""
macro default(mode::Symbol)
    if mode == :unit || mode == :power
        factor[:activePower] = 0.0
        factor[:reactivePower] = 0.0
        factor[:apparentPower] = 0.0
    end

    if mode == :unit || mode == :voltage
        factor[:voltageMagnitude] = 0.0
        factor[:voltageAngle] = 1.0
    end

    if mode == :unit || mode == :current
        factor[:currentMagnitude] = 0.0
        factor[:currentAngle] = 1.0
    end

    if mode == :unit || mode == :parameter
        factor[:impedance] = 0.0
        factor[:admittance] = 0.0
    end

    if mode == :template || mode == :bus
        for key in keys(bus[:default])
            bus[:default][key] = 0.0
        end
        bus[:default][:type] = 1
        bus[:default][:magnitude] = 1.0
        bus[:default][:base] = 138e3

        for key in keys(bus[:factor])
            bus[:factor][key] = 0.0
        end
        bus[:factor][:voltageAngle] = 1.0
        bus[:factor][:currentAngle] = 1.0
        bus[:factor][:baseVoltage] = 1.0
    end

    if mode == :template || mode == :branch
        for key in keys(branch[:default])
            branch[:default][key] = 0.0
        end
        branch[:default][:status] = 1
        branch[:default][:type] = 1

        for key in keys(branch[:factor])
            branch[:factor][key] = 0.0
        end
        branch[:factor][:voltageAngle] = 1.0
        branch[:factor][:currentAngle] = 1.0
    end

    if mode == :template || mode == :generator
        for key in keys(generator[:default])
            generator[:default][key] = 0.0
        end
        generator[:default][:status] = 1
        generator[:default][:magnitude] = 1.0

        for key in keys(generator[:factor])
            generator[:factor][key] = 0.0
        end
        generator[:factor][:voltageAngle] = 1.0
        generator[:factor][:currentAngle] = 1.0
    end
end

"""
The macro allows for the activation of various features that are relevant to the analysis
performed.

    @enable(feature)

These features are associated with different aspects of the analysis, and can be specified
using the feature parameter:
* `generatorVoltage`: includes generator magnitude setpoints that are used during voltage initialization
* `piecewiseObjective`: incorporates linear piecewise costs into the optimal power flow objective.

# Examples
To activate a single feature, the macro can be called as follows:
```jldoctest
@enable(generatorVoltage)
```

To activate multiple features, the macro can be called as follows:
```jldoctest
@enable(generatorVoltage, piecewiseObjective)
```
"""
macro enable(args...)
    @inbounds for key in args
        if haskey(settings, key)
            settings[key] = true
        end
    end
end

"""
The macro allows for the deactivation of various features that are relevant to the analysis
performed.

    @disable(feature)

These features are associated with different aspects of the analysis, and can be specified
using the feature parameter:
* `generatorVoltage`: excludes generator magnitude setpoints that are used during voltage initialization
* `piecewiseObjective`: excludes linear piecewise costs from the optimal power flow objective.

# Examples
To deactivate a single feature, the macro can be called as follows:
```jldoctest
@disable(generatorVoltage)
```

To deactivate multiple features, the macro can be called as follows:
```jldoctest
@disable(generatorVoltage, piecewiseObjective)
```
"""
macro disable(args...)
    @inbounds for key in args
        if haskey(settings, key)
            settings[key] = false
        end
    end
end
