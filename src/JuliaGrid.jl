module JuliaGrid

using SparseArrays, LinearAlgebra, SuiteSparse
using HDF5
using JuMP

######### Setting Variables ##########
include("utility/setting.jl")

######### Utility ##########
include("utility/routine.jl")
export @enable, @disable, @default

######## Power System ##########
include("powerSystem/load.jl")
export powerSystem

include("powerSystem/save.jl")
export savePowerSystem


include("powerSystem/assemble.jl")
export addBus!, shuntBus!
export addBranch!, statusBranch!, parameterBranch!
export addGenerator!, addActiveCost!, addReactiveCost!, statusGenerator!, outputGenerator!
export dcModel!, acModel!
export @bus, @branch, @generator

# ######## Power Flow ##########
include("powerFlow/solution.jl")
export newtonRaphson, fastNewtonRaphsonBX, fastNewtonRaphsonXB, gaussSeidel, dcPowerFlow
export mismatch!, solve!
export reactiveLimit!, adjustAngle!
export PowerFlow

include("powerFlow/analysis.jl")
export analysisBus, analysisBranch, analysisGenerator

######## Optimal Power Flow ##########
# include("optimalPowerFlow/solution.jl")
# export dcOptimalPowerFlow!, optimizePowerFlow!

####### Unit ##########
include("utility/unit.jl")
export @base, @power, @voltage, @parameter


system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.5, magnitude = 0.9, angle = 0.0)
addBus!(system; label = 2, type = 1, reactive = 0.05, magnitude = 1.1, angle = -0.1)
addBus!(system; label = 3, type = 1, active = 0.5, magnitude = 1.0, angle = -0.2)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.01, reactance = 0.05)
addBranch!(system; label = 2, from = 1, to = 3, resistance = 0.02, reactance = 0.01)
addBranch!(system; label = 3, from = 2, to = 3, resistance = 0.01, reactance = 0.20)

addGenerator!(system; label = 1, bus = 2, active = 3.2, magnitude = 1.2)

acModel!(system)

model = newtonRaphson(system)

for iteration = 1:100
    mismatch!(system, model)
    solve!(system, model)
end

end # JuliaGrid

