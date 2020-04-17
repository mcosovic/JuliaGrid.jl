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

function runmg(args...; max::Int64 = 100, stop::Float64 = 1.0e-8, reactive::Int64 = 0, solve::String = "", save::String = "", pmuset = "", pmuvariance = ["all" 1e-8], legacyset = "", legacyvariance = ["all" 1e-8])
    system = loadsystem(args)
    settings = gesettings(args, max, stop, reactive, solve, save, pmuset, pmuvariance, legacyset, legacyvariance)
    bus, branch, generator = runacpf(settings, system)

    rungenerator(system, settings, bus, branch)
end

end # JuliaGrid
