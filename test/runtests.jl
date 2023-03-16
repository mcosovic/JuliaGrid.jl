import Pkg; Pkg.add("Ipopt"); Pkg.add("HiGHS")

using JuliaGrid
using HDF5
using Test
using JuMP, Ipopt, HiGHS

# ######## Path to Test Data ##########
pathData = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/data/")

######## Power System ##########
include("powerSystem/loadSave.jl")
include("powerSystem/assemble.jl")
include("powerSystem/manipulation.jl")

# ######## Power flow ##########
include("powerFlow/solutionAnalaysis.jl")
include("powerFlow/reactiveLimits.jl")