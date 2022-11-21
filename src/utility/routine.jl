######### Check Package Path ##########
@inline function checkPackagePath()
    pathtoJuliaGrid = pathof(JuliaGridTest)
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