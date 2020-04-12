module JuliaGrid

export runpf
export runmg

using SparseArrays
using HDF5
using Printf
using PrettyTables
using CSV, DataFrames, XLSX
using Dates
using LinearAlgebra
using Random
using JuMP, GLPK, Gurobi

##############
#  Includes  #
##############
include("system/input.jl")
include("system/routine.jl")
include("system/results.jl")
include("system/service.jl")

include("flow/flowdc.jl")
include("flow/flowac.jl")
include("flow/flowalgorithms.jl")
include("flow/measurements.jl")

include("estimation/estimationdc.jl")


function runpf(args...; max::Int64 = 100, stop::Float64 = 1.0e-8, reactive::Int64 = 0, solve::String = "", save::String = "")
    system = loadsystem(args)
    settings = pfsettings(args, max, stop, reactive, solve, save, system)

    if settings.algorithm == "dc"
        bus, branch, generator, iterations = rundcpf(settings, system)
    else
        bus, branch, generator, iterations = runacpf(settings, system)
    end

    return bus, branch, generator, iterations
end

function runmg(args...; max::Int64 = 100, stop::Float64 = 1.0e-8, reactive::Int64 = 0, solve::String = "", save::String = "", pmuset = "all", pmuvariance = ["all" 1e-5], legacyset = "all", legacyvariance = ["all" 1e-4])
    system = loadsystem(args)
    settings = gesettings(args, max, stop, reactive, solve, save, pmuset, pmuvariance, legacyset, legacyvariance)
    bus, branch, generator = runacpf(settings, system)

    rungenerator(system, settings, bus, branch)

    return settings, system
end
bus, branch, generator, iterations = runpf("fnrxb", "case14.h5"; max = 1000)
end # JuliaGrid
