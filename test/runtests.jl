using JuliaGrid
using HDF5
using Test
using Ipopt, HiGHS

######## Path to Test Data ##########
pathData = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/data/")
torad = pi / 180

######## Power System ##########
include("powerSystem/loadSave.jl")
include("powerSystem/assemble.jl")
include("powerSystem/manipulation.jl")

# ######## Power flow ##########
include("powerFlow/analysis.jl")
include("powerFlow/limits.jl")
include("optimalPowerFlow/solution.jl")