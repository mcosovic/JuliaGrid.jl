using JuliaGrid, HiGHS

##### Power System Model #####
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 3")
addBus!(system; label = "Bus 4")
addBus!(system; label = "Bus 5")
addBus!(system; label = "Bus 6")

@branch(reactance = 0.22)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2")
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3")
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 4")
addBranch!(system; label = "Branch 4", from = "Bus 3", to = "Bus 5")
addBranch!(system; label = "Branch 5", from = "Bus 3", to = "Bus 4")
addBranch!(system; label = "Branch 6", from = "Bus 4", to = "Bus 6")

addGenerator!(system; label = "Generator 1", bus = "Bus 1")


##### Measurement Model #####
device = measurement()

addWattmeter!(system, device; label = "Meter 1", from = "Branch 1", active = 1.1)
addVarmeter!(system, device; label = "Meter 1", from = "Branch 1", reactive = -0.5)

addWattmeter!(system, device; label = "Meter 2", bus = "Bus 2", active = -0.1)
addVarmeter!(system, device; label = "Meter 2", bus = "Bus 2", reactive = -0.1)

addWattmeter!(system, device; label = "Meter 3", bus = "Bus 4", active = -0.3)
addVarmeter!(system, device; label = "Meter 3", bus = "Bus 4", reactive = 0.6)

addWattmeter!(system, device; label = "Meter 4", to = "Branch 6", active = 0.2)
addVarmeter!(system, device; label = "Meter 4", to = "Branch 6", reactive = 0.3)


##### Identification of Observable Islands #####
islands = islandTopologicalFlow(system, device)
islands = islandTopological(system, device)


##### Observability Restoration #####
pseudo = measurement()

addWattmeter!(system, pseudo; label = "Pseudo 1", from = "Branch 5", active = 0.3)
addVarmeter!(system, pseudo; label = "Pseudo 1", from = "Branch 5", reactive = 0.1)

addWattmeter!(system, pseudo; label = "Pseudo 2", bus = "Bus 5", active = 0.3)
addVarmeter!(system, pseudo; label = "Pseudo 2", bus = "Bus 5", reactive = -0.2)

restorationGram!(system, device, pseudo, islands)

printWattmeterData(system, device)
printVarmeterData(system, device)

islands = islandTopological(system, device)

addVoltmeter!(system, device; label = "Pseudo 3", bus = "Bus 1", magnitude = 1.0)


##### Optimal PMU Placement #####
placement = pmuPlacement(system, HiGHS.Optimizer)

pmu = measurement()

addPmu!(system, pmu; label = "PMU 1: 1", bus = "Bus 2", magnitude = 1.1, angle = -0.2)
addPmu!(system, pmu; label = "PMU 1: 2", to = "Branch 1", magnitude = 1.2, angle = -2.7)
addPmu!(system, pmu; label = "PMU 1: 3", from = "Branch 2", magnitude = 0.6, angle = 0.3)
addPmu!(system, pmu; label = "PMU 1: 4", from = "Branch 3", magnitude = 0.6, angle = 0.7)

addPmu!(system, pmu; label = "PMU 2: 1", bus = "Bus 3", magnitude = 1.2, angle = -0.3)
addPmu!(system, pmu; label = "PMU 2: 2", to = "Branch 2", magnitude = 0.6, angle = -2.8)
addPmu!(system, pmu; label = "PMU 2: 3", from = "Branch 4", magnitude = 0.3, angle = -2.8)

addPmu!(system, pmu; label = "PMU 3: 1", bus = "Bus 4", magnitude = 1.2, angle = -0.3)
addPmu!(system, pmu; label = "PMU 3: 2", to = "Branch 3", magnitude = 0.6, angle = -2.3)
addPmu!(system, pmu; label = "PMU 3: 3", to = "Branch 4", magnitude = 0.3, angle = 0.3)
addPmu!(system, pmu; label = "PMU 3: 4", from = "Branch 6", magnitude = 0.2, angle = 1.9)