module JuliaGridTest

# using BenchmarkTools
using SparseArrays, LinearAlgebra, SuiteSparse
using HDF5
using JuMP, HiGHS, Ipopt
using JuliaGrid
using Test
using InteractiveUtils
using BlockArrays


########## Setting Variables ##########
include("utility/setting.jl")

# ########## Utility ##########
include("utility/routine.jl")
export @default

# ########## Power System ##########
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

########## Power Flow ##########
include("powerFlow/acPowerFlow.jl")
export newtonRaphson, fastNewtonRaphsonBX, fastNewtonRaphsonXB, gaussSeidel
export mismatch!
export reactiveLimit!, adjustAngle!

include("powerFlow/dcPowerFlow.jl")
export dcPowerFlow

######### Optimal Power Flow ##########
include("optimalPowerFlow/acOptimalPowerFlow.jl")
export acOptimalPowerFlow

include("optimalPowerFlow/dcOptimalPowerFlow.jl")
export dcOptimalPowerFlow

########## Postprocessing ##########
include("postprocessing/dcAnalysis.jl")
include("postprocessing/acAnalysis.jl")
export power!, current!
export powerInjection, powerSupply, powerShunt, powerFrom, powerTo, powerCharging, powerSeries, powerGenerator
export currentInjection, currentFrom, currentTo, currentSeries

########## Unit ##########
include("utility/unit.jl")
export @base, @power, @voltage, @parameter

######### Solve Function ##########
export solve!


########## Unit ##########
include("measurement/load.jl")

pathData = "D:/Google Drive/16. GitHub/JuliaGrid.jl/test/data/"



system = powerSystem("case14.h5")

analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)
set_silent(analysis.jump)
solve!(system, analysis)

# addLegacyVoltage(measurments, analysis)

# addLegacyInjection

# measurments.legacy.voltage.magnitude.mean
# measurments.legacy.power.injection.active.mean
# measurments.legacy.power.from.active.mean
# measurments.legacy.power.to.active.mean
# measurments.legacy.current.from.magnitude.mean
# measurments.legacy.current.to.magnitude.mean


# measurments.phasor.voltage.magnitude.mean
# measurments.phasor.current.from.magnitude.mean

# system14 = powerSystem(string(pathData, "case14test.m"))
# system30 = powerSystem(string(pathData, "case30test.m"))

#     matpower14 = h5read(string(pathData, "results.h5"), "case14test/dcOptimalPowerFlow")
#     matpower30 = h5read(string(pathData, "results.h5"), "case30test/dcOptimalPowerFlow")

#     ######## Modified IEEE 14-bus Test Case ##########
#     dcModel!(system14)
#     analysis = dcOptimalPowerFlow(system14, HiGHS.Optimizer)
#     JuMP.set_silent(analysis.jump)
#     solve!(system14, analysis)
#     power!(system14, analysis)

#     @test analysis.voltage.angle ≈ matpower14["voltage"] atol = 1e-10
#     @test analysis.power.injection.active ≈ matpower14["injection"] atol = 1e-6
#     @test analysis.power.supply.active ≈ matpower14["supply"] atol = 1e-6
#     @test analysis.power.from.active ≈ matpower14["from"] atol = 1e-6
#     @test analysis.power.to.active ≈ -matpower14["from"] atol = 1e-6
#     @test analysis.power.generator.active ≈ matpower14["generator"] atol = 1e-6


# system14 = powerSystem(string(pathData, "case_ACTIVSg70k.m"))
# acModel!(system14)

# newtonRaphson(system14)
# analysis = dcOptimalPowerFlow(system14, Ipopt.Optimizer)
# display(JuMP.all_variables(analysis.jump))


# display(JuMP.objective_function(analysis.jump))
# solve!(system, analysis)

# display(JuMP.objective_value(analysis.jump))

# @code_warntype acModel!(system)


# @time a = BitVector(undef, 1000000)

# @time b = Array{Int8}(undef, 1000000)

# @time c = trunc.(b, Bit)

# @bus(minMagnitude = 0.9, maxMagnitude = 1.1)
# addBus!(system; label = 1, type = 3, magnitude = 1.05, angle = 0.17)
# addBus!(system; label = 2, active = 0.1, reactive = 0.01, conductance = 0.04)
# addBus!(system; label = 3, active = 0.05, reactive = 0.02)

# @branch(minDiffAngle = -pi, maxDiffAngle = pi, conductance = 1e-4, susceptance = 0.01)
# addBranch!(system; from = 1, to = 2, resistance = 0.5, reactance = 1.0, longTerm = 0.15)
# addBranch!(system; from = 1, to = 3, resistance = 0.5, reactance = 1.0, longTerm = 0.10)
# addBranch!(system; from = 2, to = 3, resistance = 0.5, reactance = 1.0, longTerm = 0.25)

# @generator(minActive = 0.0, minReactive = -0.1, maxReactive = 0.1)
# addGenerator!(system; label = 1, bus = 1, active = 3.2, reactive = 0.5, maxActive = 0.5)
# addGenerator!(system; label = 2, bus = 2, active = 0.2, reactive = 0.1, maxActive = 0.2)

# addActiveCost!(system; label = 1, model = 2, polynomial = [1100.2; 500; 80])
# addActiveCost!(system; label = 2, model = 1, piecewise =  [10.85 12.3; 14.77 16.8; 18 18.1])

# addReactiveCost!(system; label = 1, model = 2, polynomial = [30.2; 20; 5])
# addReactiveCost!(system; label = 2, model = 2, polynomial = [10.3; 5.1; 1.2])

# acModel!(system)

# model = acOptimalPowerFlow(system, Ipopt.Optimizer)
# JuMP.set_silent(model.jump)

# solve!(system, model)

# display(model.constraint.balance.active)

# delete!(system, model.constraint.limit.angle; label = 1)

# deleteBalanceReactive!(system, model; label = 1)

# print(model.jump, model.constraint.balance.active[i] for i = 1:system.bus.number if is_valid(model.jump, model.constraint.balance.active[i]))

# display(model.constraint.balance.active[2:3])

# system = powerSystem("C:/Users/User/Desktop/matpower7.1/data/case14.m")
# dcModel!(system)
# model = dcOptimalPowerFlow(system, Ipopt.Optimizer)

# deleteLimit!(system, model; label = 1)

# print(model.constraint.balance.active[1])
# solve!(system, model)

# @code_warntype dcModel!(system)


# pathData = "D:/My Drive/16. GitHub/JuliaGrid.jl/test/data/"
# torad = pi / 180

# display(@benchmark system14 = powerSystem(string(pathData, "case14test.m")))
# system30 = powerSystem(string(pathData, "case30test.m"))


# @testset "DC Optimal Power Flow" begin
#     field = "/dcOptimalPowerFlow"
    # matpower14 = h5read(string(pathData, "case14testResult.h5"), field)
#     matpower30 = h5read(string(pathData, "case30testResult.h5"), field)

#     ######## Modified IEEE 14-bus Test Case ##########
    # display(@benchmark dcModel!($system14))
#     model = dcOptimalPowerFlow(system14, Ipopt.Optimizer)
#     solve!(system14, model)

#     @test model.voltage.angle ≈ matpower14["Ti"] atol = 1e-6
#     @test model.power.active ≈ matpower14["Pgen"] atol = 1e-6

#     ######## Modified IEEE 30-bus Test Case ##########
#     dcModel!(system30)
#     model = dcOptimalPowerFlow(system30, HiGHS.Optimizer)
#     solve!(system30, model)

#     @test model.voltage.angle ≈ matpower30["Ti"] atol = 1e-10
#     @test model.power.active ≈ matpower30["Pgen"] atol = 1e-10
# end



# system = powerSystem("case14.h5")



# using Profile
# Profile.Allocs.clear()
# Profile.Allocs.@profile sample_rate = 1 dcModel!(system)

# using PProf
# PProf.Allocs.pprof(from_c = false)


# model = acOptimalPowerFlow(system, HiGHS.Optimizer)

end # JuliaGrid

