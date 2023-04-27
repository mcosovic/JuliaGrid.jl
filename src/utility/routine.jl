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
