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
        prefix.activePower = 0.0
        prefix.reactivePower = 0.0
        prefix.apparentPower = 0.0
    end

    if mode == :unit || mode == :voltage
        prefix.voltageMagnitude = 0.0
        prefix.voltageAngle = 1.0
    end

    if mode == :unit || mode == :current
        prefix.currentMagnitude = 0.0
        prefix.currentAngle = 1.0
    end

    if mode == :unit || mode == :parameter
        prefix.impedance = 0.0
        prefix.admittance = 0.0
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
        template.bus.minMagnitude.value = 0.0
        template.bus.minMagnitude.pu = true
        template.bus.maxMagnitude.value = 0.0
        template.bus.maxMagnitude.pu = true

        template.bus.base = 138e3
        template.bus.angle = 0.0
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

        template.branch.longTerm.value = 0.0
        template.branch.longTerm.pu = true
        template.branch.shortTerm.value = 0.0
        template.branch.shortTerm.pu = true
        template.branch.emergency.value = 0.0
        template.branch.emergency.pu = true

        template.branch.turnsRatio = 1.0
        template.branch.shiftAngle = 0.0
        template.branch.minDiffAngle = 0.0
        template.branch.maxDiffAngle = 0.0
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
        template.generator.reactiveTimescale.value = 0.0
        template.generator.reactiveTimescale.pu = true
        template.generator.reserve10min.value = 0.0
        template.generator.reserve10min.pu = true
        template.generator.reserve30min.value = 0.0
        template.generator.reserve30min.pu = true

        template.generator.status = Int8(1)
        template.generator.area = 0
    end
end