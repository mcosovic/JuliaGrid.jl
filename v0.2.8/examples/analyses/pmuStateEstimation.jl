using JuliaGrid, HiGHS

##### Power System Model #####
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 3")
addBus!(system; label = "Bus 4")
addBus!(system; label = "Bus 5")
addBus!(system; label = "Bus 6")

@branch(resistance = 0.02)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3", reactance = 0.23)
addBranch!(system; label = "Branch 3", from = "Bus 3", to = "Bus 4", reactance = 0.19)
addBranch!(system; label = "Branch 4", from = "Bus 4", to = "Bus 5", reactance = 0.17)
addBranch!(system; label = "Branch 5", from = "Bus 5", to = "Bus 6", reactance = 0.04)
addBranch!(system; label = "Branch 6", from = "Bus 1", to = "Bus 6", reactance = 0.21)
addBranch!(system; label = "Branch 7", from = "Bus 2", to = "Bus 6", reactance = 0.13)
addBranch!(system; label = "Branch 8", from = "Bus 5", to = "Bus 2", reactance = 0.34)

addGenerator!(system; label = "Generator 1", bus = "Bus 1")

##### Display Data Settings #####
show = Dict("Shunt Power" => false, "Status" => false, "Series Power" => false)

##### Optimal PMU Placement #####
placement = pmuPlacement(system, HiGHS.Optimizer; verbose = 1)

##### Measurement Model #####
device = measurement()

updateBus!(system; label = "Bus 2", type = 1, active = 0.217, reactive = 0.127)
updateBus!(system; label = "Bus 3", type = 1, active = 0.478, reactive = -0.039)
updateBus!(system; label = "Bus 4", type = 2, active = 0.076, reactive = 0.016)
updateBus!(system; label = "Bus 5", type = 1, active = 0.112, reactive = 0.075)
updateBus!(system; label = "Bus 6", type = 1, active = 0.295, reactive = 0.166)

updateGenerator!(system; label = "Generator 1", active = 2.324, reactive = -0.169)
addGenerator!(system; label = "Generator 2", bus = "Bus 4", active = 0.412, reactive = 0.234)

acModel!(system)
powerFlow = newtonRaphson(system)
acPowerFlow!(system, powerFlow; verbose = 1)

@pmu(label = "!")
for (bus, idx) in placement.bus
    Vᵢ, θᵢ = powerFlow.voltage.magnitude[idx], powerFlow.voltage.angle[idx]
    addPmu!(system, device; bus = bus, magnitude = Vᵢ, angle = θᵢ, noise = true)
end

for branch in keys(placement.from)
    Iᵢⱼ, ψᵢⱼ = fromCurrent(system, powerFlow; label = branch)
    addPmu!(system, device; from = branch, magnitude = Iᵢⱼ, angle = ψᵢⱼ)
end
for branch in keys(placement.to)
    Iⱼᵢ, ψⱼᵢ = toCurrent(system, powerFlow; label = branch)
    addPmu!(system, device; to = branch, magnitude = Iⱼᵢ, angle = ψⱼᵢ)
end

printPmuData(system, device; width = Dict("Label" => 15))

##### Base Case Analysis #####
analysis = pmuStateEstimation(system, device)
solve!(system, analysis)
power!(system, analysis)

power!(system, powerFlow)
printBusData(system, analysis; show)
printBusData(system, powerFlow; show)
printBranchData(system, analysis; show)

##### Modifying Measurement Data #####
updatePmu!(system, device, analysis; label = "From Branch 8", magnitude = 1.1)
updatePmu!(system, device, analysis; label = "From Branch 2", angle = 0.2, noise = true)

solve!(system, analysis)
power!(system, analysis)

printBusData(system, analysis; show)

##### Modifying Measurement Set #####
updatePmu!(system, device; label = "From Branch 2", status = 0)
updatePmu!(system, device; label = "From Branch 8", status = 0)

addPmu!(system, device; to = "Branch 2", magnitude = 0.2282, angle = -2.9587)
addPmu!(system, device; to = "Branch 8", magnitude = 0.0414, angle = -0.2424)

analysis = pmuStateEstimation(system, device)
solve!(system, analysis)
power!(system, analysis)

printBusData(system, analysis; show)