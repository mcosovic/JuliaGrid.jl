module JuliaGrid

using SparseArrays, LinearAlgebra, SuiteSparse
using HDF5, UUIDs
using JuMP


########## Types and Constants ##########
include("definition/internal.jl")
include("definition/powerSystem.jl")
include("definition/analysis.jl")

######### Utility ##########
include("utility/routine.jl")
include("utility/internal.jl")
export @base, @power, @voltage, @current, @parameter, @default, @print

########## Power System ##########
include("powerSystem/load.jl")
include("powerSystem/save.jl")
include("powerSystem/model.jl")
export powerSystem, savePowerSystem
export acModel!, dcModel!

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
export acOptimalPowerFlow
export dcOptimalPowerFlow

########## Postprocessing ##########
include("postprocessing/dcAnalysis.jl")
include("postprocessing/acAnalysis.jl")
export power!, current!
export injectionPower, supplyPower, shuntPower, fromPower, toPower, chargingPower, seriesPower, generatorPower
export injectionCurrent, fromCurrent, toCurrent, seriesCurrent

end # JuliaGrid