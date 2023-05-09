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
        for key in keys(template[:bus])
            template[:bus][key] = 0.0
        end
        template[:bus][:type] = 1
        template[:bus][:magnitude] = 1.0
        template[:bus][:base] = 138e3
        template[:bus][:voltageAngle] = 1.0
        template[:bus][:currentAngle] = 1.0
        template[:bus][:baseVoltage] = 1.0
    end

    if mode == :template || mode == :branch
        for key in keys(template[:branch])
            template[:branch][key] = 0.0
        end
        template[:branch][:status] = 1
        template[:branch][:type] = 1
        template[:branch][:voltageAngle] = 1.0
        template[:branch][:currentAngle] = 1.0
    end

    if mode == :template || mode == :generator
        for key in keys(template[:generator])
           template[:generator][key] = 0.0
        end
       template[:generator][:status] = 1
       template[:generator][:magnitude] = 1.0
       template[:generator][:voltageAngle] = 1.0
       template[:generator][:currentAngle] = 1.0
    end
end