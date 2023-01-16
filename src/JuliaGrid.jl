module JuliaGridTest

using SparseArrays, LinearAlgebra, SuiteSparse
using HDF5
using JuliaGrid

######### Utility ##########
include("utility/routine.jl")

######## Power System ##########
include("powerSystem/load.jl")
export powerSystem

include("powerSystem/save.jl")
export savePowerSystem

# include("powerSystem/assemble.jl")
# export addBus!, slackBus!, shuntBus!
# export addBranch!, statusBranch!, parameterBranch!
# export addGenerator!, statusGenerator!, outputGenerator!
# export dcModel!, acModel!

# ######## Power Flow ##########
# include("powerFlow/solution.jl")
# export gaussSeidel, newtonRaphson, fastNewtonRaphsonBX, fastNewtonRaphsonXB
# export gaussSeidel!, newtonRaphson!, fastNewtonRaphson!, dcPowerFlow

# include("powerFlow/analysis.jl")
# export bus!, branch!, generator!

# include("powerFlow/reactiveLimits.jl")
# export reactivePowerLimit!, adjustVoltageAngle!

######### Unit ##########
include("utility/unit.jl")
unit = defaultUnit()

# ######## Optimal Power Flow ##########
# include("optimalPowerFlow/solution.jl")
# export dcOptimalPowerFlow

# 

@unit(base, MVA, kV)

# @unit(power, pu, pu)

# @unit(voltage, kV, deg)
systema = powerSystem()


system = powerSystem("D:/My Drive/16. GitHub/JuliaGrid.jl/src/data/case5.h5")
# savePowerSystem(system; path = "D:/case5.h5")

# @base(systema, MVA, MV)
# @voltage(kV, deg)
# @current(kV, deg)


# addBus!(system, label = 8, active = 25.0, reactive = 34.0, magnitude = 110.0, angle = 10.0, base = 110.0)

# shuntBus!(system; label = 8, conductance = 30.0, susceptance = 20.0)

# @time addBus!(systema, label = 9, active = 0.25)
# @time addBus!(systema, label = 10, active = 0.25)
# @time @unit(system, base, MVA, MV)
# @unit(system, power, kW, pu)
# @unit(system, parameter, kΩ, S)
# @unit(system, base, kVA, kV)
# @unit(system, base, VA, kV)
# systemc = powerSystem("D:/My Drive/16. GitHub/JuliaGrid.jl/src/data/case5.m")
# @unit(systemc, base, VA, kV)
# @unit voltage kV deg



end # JuliaGrid

