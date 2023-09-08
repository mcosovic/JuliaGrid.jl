using JuliaGrid
using HDF5
using Test
using Ipopt, HiGHS

######## Path to Test Data ##########
pathData = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/data/")

######## Equality of Structs ##########
function equalStruct(a::S, b::S) where S
    for name in fieldnames(S)
        @test getfield(a, name) == getfield(b, name)
    end
end

function approxStruct(a::S, b::S) where S
    for name in fieldnames(S)
        @test getfield(a, name) ≈ getfield(b, name)
    end
end

function approxStruct(a::S, b::S, atol::Float64) where S
    for name in fieldnames(S)
        @test getfield(a, name) ≈ getfield(b, name) atol = atol
    end
end

######## Power System ##########
include("powerSystem/loadSave.jl")
include("powerSystem/buildUpdate.jl")

######## Power flow ##########
include("powerFlow/analysis.jl")
include("powerFlow/reusing.jl")
include("powerFlow/limits.jl")






