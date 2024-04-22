module JuliaGridTest

using JuliaGrid

using SparseArrays, LinearAlgebra, SuiteSparse
using HDF5
using JuMP
using Random, OrderedCollections

using Test, Ipopt, HiGHS, GLPK

######### Types and Constants ##########
include("definition/internal.jl")
include("definition/system.jl")
include("definition/analysis.jl")

######### Utility ##########
include("utility/routine.jl")
include("utility/internal.jl")
export @base, @power, @voltage, @current, @parameter, @default

########## Power System ##########
include("powerSystem/load.jl")
include("powerSystem/save.jl")
include("powerSystem/model.jl")
export powerSystem, savePowerSystem
export acModel!, dcModel!, dropZeros!

########## Power System Components ##########
include("powerSystem/bus.jl")
include("powerSystem/branch.jl")
include("powerSystem/generator.jl")
export addBus!, updateBus!, @bus
export addBranch!, updateBranch!, @branch
export addGenerator!, updateGenerator!, cost!, @generator

########## Power Flow ##########
include("powerFlow/acPowerFlow.jl")
include("powerFlow/dcPowerFlow.jl")
export newtonRaphson, fastNewtonRaphsonBX, fastNewtonRaphsonXB, gaussSeidel
export mismatch!, solve!
export reactiveLimit!, adjustAngle!, startingVoltage!
export dcPowerFlow

######### Optimal Power Flow ##########
include("optimalPowerFlow/acOptimalPowerFlow.jl")
include("optimalPowerFlow/dcOptimalPowerFlow.jl")
export acOptimalPowerFlow, startingPrimal!
export dcOptimalPowerFlow

######### Measurement ##########
include("measurement/load.jl")
include("measurement/save.jl")
export measurement, saveMeasurement

########## Measurement Devices ##########
include("measurement/voltmeter.jl")
include("measurement/ammeter.jl")
include("measurement/powermeter.jl")
include("measurement/pmu.jl")
include("measurement/configuration.jl")
export addVoltmeter!, updateVoltmeter!, statusVoltmeter!, @voltmeter
export addAmmeter!, updateAmmeter!, statusAmmeter!, @ammeter
export addWattmeter!, updateWattmeter!, statusWattmeter!, @wattmeter
export addVarmeter!, updateVarmeter!, statusVarmeter!, @varmeter
export addPmu!, updatePmu!, statusPmu!, @pmu
export status!

######### State Estimation ##########
include("stateEstimation/acStateEstimation.jl")
include("stateEstimation/pmuStateEstimation.jl")
include("stateEstimation/dcStateEstimation.jl")
include("stateEstimation/badData.jl")
include("stateEstimation/observability.jl")
export gaussNewton, acLavStateEstimation
export pmuWlsStateEstimation, pmuLavStateEstimation, pmuPlacement
export dcWlsStateEstimation, dcLavStateEstimation, residualTest!
export islandTopologicalFlow, islandTopological, restorationGram!

########## Postprocessing ##########
include("postprocessing/acAnalysis.jl")
include("postprocessing/dcAnalysis.jl")
export power!, current!
export injectionPower, supplyPower, shuntPower, fromPower, toPower, chargingPower, seriesPower, generatorPower
export injectionCurrent, fromCurrent, toCurrent, seriesCurrent


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

pathData = "D:/My Drive/16. GitHub/JuliaGrid.jl/test/data/"

######## Power System ##########
include("D:/My Drive/16. GitHub/JuliaGrid.jl/test/powerSystem/loadSave.jl")
include("D:/My Drive/16. GitHub/JuliaGrid.jl/test/powerSystem/buildUpdate.jl")

# ######## Power flow ##########
include("D:/My Drive/16. GitHub/JuliaGrid.jl/test/powerFlow/analysis.jl")
include("D:/My Drive/16. GitHub/JuliaGrid.jl/test/powerFlow/reusing.jl")
include("D:/My Drive/16. GitHub/JuliaGrid.jl/test/powerFlow/limits.jl")

######## Optimal Power flow ##########
include("D:/My Drive/16. GitHub/JuliaGrid.jl/test/optimalPowerFlow/analysis.jl")
include("D:/My Drive/16. GitHub/JuliaGrid.jl/test/optimalPowerFlow/reusing.jl")

######## Measurement ##########
include("D:/My Drive/16. GitHub/JuliaGrid.jl/test/measurement/loadSave.jl")
include("D:/My Drive/16. GitHub/JuliaGrid.jl/test/measurement/buildUpdate.jl")

######## State Estimation ##########
include("D:/My Drive/16. GitHub/JuliaGrid.jl/test/stateEstimation/analysis.jl")
include("D:/My Drive/16. GitHub/JuliaGrid.jl/test/stateEstimation/reusing.jl")
include("D:/My Drive/16. GitHub/JuliaGrid.jl/test/stateEstimation/badData.jl")
include("D:/My Drive/16. GitHub/JuliaGrid.jl/test/stateEstimation/observability.jl")
include("D:/My Drive/16. GitHub/JuliaGrid.jl/test/stateEstimation/pmuPlacement.jl")

end

