module JuliaGrid

export runpf
export runmg
export runse

using SparseArrays, LinearAlgebra, SuiteSparse
using PrettyTables, Printf
using HDF5, CSV, XLSX
using Random
using JuMP, Ipopt, GLPK
using LightGraphs, SimpleWeightedGraphs


### Includes
include("system/input.jl")
include("system/routine.jl")
include("system/results.jl")
include("system/headers.jl")

include("flow/flowdc.jl")
include("flow/flowac.jl")
include("flow/flowfunctions.jl")
include("flow/measurements.jl")

include("estimation/estimatedc.jl")
include("estimation/estimatepmu.jl")
include("estimation/estimatefunctions.jl")


### Power Flow
function runpf(
    args...;
    max::Int64 = 100,
    stop::Float64 = 1.0e-8,
    reactive::Int64 = 0,
    solve::String = "",
    save::String = "",
)
    path = loadpath(args)
    system, num, info = loadsystem(path)
    settings = pfsettings(args, max, stop, reactive, solve, save, system, num)

    if settings.algorithm == "dc"
        results = rundcpf(system, num, settings, info)
    else
        results = runacpf(system, num, settings, info)
    end

    return results, system, info
end


### Measurement Generator
function runmg(
    args...;
    runflow::Int64 = 1,
    max::Int64 = 100,
    stop::Float64 = 1.0e-8,
    reactive::Int64 = 0,
    solve::String = "",
    save::String = "",
    pmuset = [],
    pmuvariance = [],
    legacyset = [],
    legacyvariance = [],
)

    path = loadpath(args)
    system, numsys, info = loadsystem(path)
    measurements, num = loadmeasurement(path, system, numsys; pmuvar = pmuvariance, legvar = legacyvariance, runflow = runflow)
    settings = gesettings(num, pmuset, pmuvariance, legacyset, legacyvariance, runflow, save)

    if settings.runflow == 1
        pfsettings = gepfsettings(max, stop, reactive, solve)
        acflow = runacpf(system, numsys, pfsettings, info)
        info = rungenerator(system, measurements, num, numsys, settings, info; flow = acflow)
    else
        info = rungenerator(system, measurements, num, numsys, settings, info)
    end

    return measurements, system, info
end

### State Estimation
function runse(
    args...;
    max::Int64 = 100,
    stop::Float64 = 1.0e-8,
    start::String = "flat",
    bad = [],
    lav = [],
    observe = [],
    covariance::Int64 = 0,
    solve::String = "",
    save::String = "",
)

    if loadse(args)
        path = loadpath(args)
        system, numsys, info = loadsystem(path)
        measurements, num = loadmeasurement(path, system, numsys)
    else
        system, numsys, measurements, num, info = loadsedirect(args)
    end
    settings = sesettings(args, system, max, stop, start, bad, lav, observe, covariance, solve, save)

    if settings.algorithm == "dc"
        results = rundcse(system, measurements, num, numsys, settings, info)
    elseif settings.algorithm == "pmu"
        results = runpmuse(system, measurements, num, numsys, settings, info)
    end

    return results, measurements, system, info
end

end # JuliaGrid
