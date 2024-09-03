using JuliaGrid
using HDF5
using Test
using JuMP, HiGHS, Ipopt, GLPK
using Suppressor

######## Path to Test Data ##########
pathData = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/data/")

######## Compare Structs ##########
function compstruct(obj1::S, obj2::S; atol = 0.0) where S
    for name in fieldnames(typeof(obj1))
        field = getfield(obj1, name)

        if isa(field, Vector) || isa(field, Number)
            if atol == 0.0
                @test ==(field, getfield(obj2, name))
            else
                if !isempty(field)
                    @test ≈(field, getfield(obj2, name), atol = atol)
                end
            end
        elseif isa(field, AbstractDict) || isa(field, String)
            @test ==(field, getfield(obj2, name))
        else
            compstruct(field, getfield(obj2, name); atol)
        end
    end
end

######## Power System ##########
include("powerSystem/loadSave.jl")
include("powerSystem/buildUpdate.jl")

######## Power flow ##########
include("powerFlow/analysis.jl")
include("powerFlow/reusing.jl")
include("powerFlow/limits.jl")

######## Optimal Power flow ##########
include("optimalPowerFlow/analysis.jl")
include("optimalPowerFlow/reusing.jl")

######## Measurement ##########
include("measurement/loadSave.jl")
include("measurement/buildUpdate.jl")

######## State Estimation ##########
include("stateEstimation/analysis.jl")
include("stateEstimation/reusing.jl")
include("stateEstimation/badData.jl")
include("stateEstimation/observability.jl")
include("stateEstimation/pmuPlacement.jl")