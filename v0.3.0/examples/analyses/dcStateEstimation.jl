using JuliaGrid, Ipopt

##### System of Units #####
@voltage(pu, deg)

##### Power System Model #####
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.217)
addBus!(system; label = "Bus 3", type = 1, active = 0.478)
addBus!(system; label = "Bus 4", type = 2, active = 0.076)
addBus!(system; label = "Bus 5", type = 1, active = 0.112)
addBus!(system; label = "Bus 6", type = 2, active = 0.295)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3", reactance = 0.23)
addBranch!(system; label = "Branch 3", from = "Bus 3", to = "Bus 4", reactance = 0.19)
addBranch!(system; label = "Branch 4", from = "Bus 4", to = "Bus 5", reactance = 0.17)
addBranch!(system; label = "Branch 5", from = "Bus 5", to = "Bus 6", reactance = 0.04)
addBranch!(system; label = "Branch 6", from = "Bus 1", to = "Bus 6", reactance = 0.21)
addBranch!(system; label = "Branch 7", from = "Bus 2", to = "Bus 6", reactance = 0.13)
addBranch!(system; label = "Branch 8", from = "Bus 5", to = "Bus 2", reactance = 0.34)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.8, maxActive = 2.3)
addGenerator!(system; label = "Generator 2", bus = "Bus 4", active = 0.4, maxActive = 2.3)

cost!(system; generator = "Generator 1", active = 2, polynomial = [1100.0; 500.0; 150.0])
cost!(system; generator = "Generator 2", active = 2, polynomial = [1500.0; 700.0; 140.0])

dcModel!(system)

##### Measurement Model #####
device = measurement()

powerFlow = dcOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(system, powerFlow; power = true, verbose = 1)

printBusData(system, powerFlow)
@wattmeter(label = "Wattmeter ?")
for (label, idx) in system.bus.label
    Pᵢ = powerFlow.power.injection.active[idx]
    addWattmeter!(system, device; bus = label, active = Pᵢ, variance = 1e-4, noise = true)
end

printBranchData(system, powerFlow)
addWattmeter!(system, device; from = "Branch 1", active = powerFlow.power.from.active[1])
addWattmeter!(system, device; from = "Branch 4", active = powerFlow.power.from.active[4])

printWattmeterData(system, device)

##### Base Case Analysis #####
analysis = dcStateEstimation(system, device)
stateEstimation!(system, analysis; power = true, verbose = 1)

printBusData(system, analysis)
printWattmeterData(system, device, analysis)

##### Modifying Measurement Data #####
updateWattmeter!(system, device, analysis; label = "Wattmeter 7", active = 1.1)
updateWattmeter!(system, device, analysis; label = "Wattmeter 8", active = 1.6)

stateEstimation!(system, analysis; power = true, verbose = 1)
printBusData(system, analysis)

analysis = dcLavStateEstimation(system, device, Ipopt.Optimizer)
stateEstimation!(system, analysis; power = true, verbose = 1)
printBusData(system, analysis)

##### Modifying Measurement Set #####
updateWattmeter!(system, device, analysis; label = "Wattmeter 1", status = 0)
updateWattmeter!(system, device, analysis; label = "Wattmeter 5", status = 0)

stateEstimation!(system, analysis; power = true, verbose = 1)
printBusData(system, analysis)