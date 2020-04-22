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
        bus, branch, generator, iterations = rundcpf(settings, system)
    else
        bus, branch, generator, iterations = runacpf(settings, system)
    end

    return bus, branch, generator, iterations
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
        bus, branch = runacpf(settings, system)
        measurement, system, info = rungenerator(system, settings, measurement; bus = bus, branch = branch)
    else
        measurement, system, info = rungenerator(system, settings, measurement)
    end

    return measurement, system, info
end

measurement, system, info = runmg("case14.h5"; runflow = 1, save = "D:/Dropbox/test.xlsx", pmuset = ["Vi" "all"], pmuvariance = ["Vi" 2 "Ti" 4 "all" 8], legacyset = ["all"])
######################
#  State Estimation  #
######################

end # JuliaGrid
