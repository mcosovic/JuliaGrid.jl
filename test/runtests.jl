using JuliaGrid
using HDF5
using Test
using JuMP, HiGHS, Ipopt, GLPK
using Suppressor
using OrderedCollections

##### Path to Test Data #####
path = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/data/")

##### Compare Structs #####
function compstruct(obj1::S, obj2::S; atol = 0.0) where S
    for name in fieldnames(typeof(obj1))
        field1 = getfield(obj1, name)
        field2 = getfield(obj2, name)

        if isa(field1, Vector) || isa(field1, Number)
            if atol == 0.0
                @test ==(field1, field2)
            else
                if !isempty(field1)
                    @test ≈(field1, field2, atol = atol)
                end
            end
        elseif isa(field1, OrderedDict{Int64, Vector{Float64}}) ||
               isa(field1, OrderedDict{Int64, Matrix{Float64}})
            @test ==(keys(field1), keys(field2))
            for (idx, value) in field1
                if atol == 0.0
                    @test ==(value, field2[idx])
                else
                    @test ≈(value, field2[idx], atol = atol)
                end
            end
        elseif isa(field1, AbstractDict) || isa(field1, String)
            @test ==(field1, field2)
        else
            compstruct(field1, field2; atol)
        end
    end
end

##### Utility #####
include("utility/utility.jl")

##### Power System #####
include("powerSystem/loadSave.jl")
include("powerSystem/buildUpdate.jl")

##### Power flow #####
include("powerFlow/analysis.jl")
include("powerFlow/reusing.jl")
include("powerFlow/limits.jl")

##### Optimal Power flow #####
include("optimalPowerFlow/analysis.jl")
include("optimalPowerFlow/reusing.jl")

##### Measurement #####
include("measurement/loadSave.jl")
include("measurement/buildUpdate.jl")

##### State Estimation #####
include("stateEstimation/analysis.jl")
include("stateEstimation/reusing.jl")
include("stateEstimation/badData.jl")
include("stateEstimation/observability.jl")
include("stateEstimation/pmuPlacement.jl")