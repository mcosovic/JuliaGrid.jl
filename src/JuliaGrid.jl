# module JuliaGrid
#
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
using Suppressor


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
    measurement = loadmeasurement(system, runflow)
    settings = gesettings(runflow, max, stop, reactive, solve, save, pmuset, pmuvariance, legacyset, legacyvariance, measurement)

    if settings.runflow == 1
        flow = runacpf(settings, system)
        results = rungenerator(system, settings, measurement; flow = flow)
    else
        results = rungenerator(system, settings, measurement)
    end

    return results
end

# results = runpf("case14.h5", "nr"; max = 10, save = "D:/Dropbox/test.xlsx")
results = runmg("case14.h5"; runflow = 1, legacyset = ["redundancy" 8], save = "D:/Dropbox/test.xlsx")
######################
#  State Estimation  #
######################

# end # JuliaGrid
