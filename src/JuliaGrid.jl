module JuliaGrid

export runpf
export runmg

using SparseArrays
using HDF5
using Printf
using PrettyTables
using CSV, XLSX
using LinearAlgebra
using Random
using JuMP, GLPK


##############
#  Includes  #
##############
include("system/input.jl")
include("system/routine.jl")
include("system/results.jl")

include("flow/flowdc.jl")
include("flow/flowac.jl")
include("flow/flowalgorithms.jl")
include("flow/measurements.jl")


################
#  Power Flow  #
################
function runpf(
    args...;
    max::Int64 = 100,
    stop::Float64 = 1.0e-8,
    reactive::Int64 = 0,
    solve::String = "",
    save::String = "",
)
    system = loadsystem(args)
    settings = pfsettings(args, max, stop, reactive, solve, save, system)

    if settings.algorithm == "dc"
        results = rundcpf(settings, system)
    else
        results = runacpf(settings, system)
    end

    return results
end


###########################
#  Measurement Generator  #
###########################
function runmg(
    args...;
    runflow::Int64 = 1,
    max::Int64 = 100,
    stop::Float64 = 1.0e-8,
    reactive::Int64 = 0,
    solve::String = "",
    save::String = "",
    pmuset = "",
    pmuvariance = "",
    legacyset = "",
    legacyvariance = "",
)
    system = loadsystem(args)
    measurement = loadmeasurement(system, pmuvariance, legacyvariance; runflow = runflow)
    settings = gesettings(pmuset, pmuvariance, legacyset, legacyvariance, measurement; runflow = runflow, save = save)

    if settings.runflow == 1
        pfsettings = gepfsettings(max, stop, reactive, solve)
        flow = runacpf(pfsettings, system)
        results = rungenerator(system, settings, measurement; flow = flow)
    else
        results = rungenerator(system, settings, measurement)
    end

    return results
end


######################
#  State Estimation  #
#####################
function runse(
    args...;
    max::Int64 = 100,
    stop::Float64 = 1.0e-8,
    start::String = "flat",
    bad::Int64 = 0,
    lav::Int64 = 0,
    solve::String = "",
    save::String = "",
    pmuset = "",
    pmuvariance = "",
    legacyset = "",
    legacyvariance = "",
)

    system = loadsystem(args)
    measurement = loadmeasurement(system, pmuvariance, legacyvariance)
    settings = sesettings(args, max, stop, start, bad, lav, solve, save)

    if !isempty(pmuset) || !isempty(pmuvariance) || !isempty(legacyset) || !isempty(legacyvariance)
        gensettings = gesettings(pmuset, pmuvariance, legacyset, legacyvariance, measurement)
        rungenerator(system, gensettings, measurement)
    end
    measurement = loadestimation(measurement)

    return measurement, settings
end

end # JuliaGrid
