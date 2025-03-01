using JuliaGrid, Ipopt

##### System of Units #####
@power(MW, MVAr)
@voltage(pu, deg)


##### Power System Model #####
system = powerSystem()

@bus(minMagnitude = 0.95, maxMagnitude = 1.05)
addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", active = 20.2, reactive = 10.5)
addBus!(system; label = "Bus 3", conductance = 0.1, susceptance = 8.2)
addBus!(system; label = "Bus 4", active = 50.8, reactive = 23.1)

@branch(label = "Branch ?", reactance = 0.22)
addBranch!(system; from = "Bus 1", to = "Bus 3", resistance = 0.02, susceptance = 0.05)
addBranch!(system; from = "Bus 1", to = "Bus 2", resistance = 0.05, susceptance = 0.04)
addBranch!(system; from = "Bus 2", to = "Bus 3", resistance = 0.04, susceptance = 0.04)
addBranch!(system; from = "Bus 3", to = "Bus 4", turnsRatio = 0.98)

@generator(label = "Generator ?", minActive = 2.0, minReactive = -15.5, maxReactive = 15.5)
addGenerator!(system; bus = "Bus 1", active = 63.1, reactive = 8.2, maxActive = 65.5)
addGenerator!(system; bus = "Bus 2", active = 3.0, reactive = 6.2, maxActive = 20.5)
addGenerator!(system; bus = "Bus 2", active = 4.1, reactive = 8.5, maxActive = 22.4)

cost!(system; generator = "Generator 1", active = 2, polynomial = [0.04; 20.0; 0.0])
cost!(system; generator = "Generator 2", active = 2, polynomial = [1.00; 20.0; 0.0])
cost!(system; generator = "Generator 3", active = 2, polynomial = [1.00; 20.0; 0.0])

acModel!(system)


##### Display Data Settings #####
show1 = Dict("Power Injection" => false)
fmt1 = Dict("Power Generation" => "%.2f", "Power Demand" => "%.2f", "Shunt Power" => "%.2f")

show2 = Dict("Shunt Power" => false, "Status" => false)
fmt2 = Dict("From-Bus Power" => "%.2f", "To-Bus Power" => "%.2f", "Series Power" => "%.2f")

show3 = Dict("Reactive Power Capability" => false)
fmt3 = Dict("Power Output" => "%.2f")


##### Base Case Analysis #####
analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
power!(system, analysis)

printBusData(system, analysis; show = show1, fmt = fmt1)
printGeneratorData(system, analysis; fmt = fmt3)
printGeneratorConstraint(system, analysis; show = show3)
printBranchData(system, analysis; show = show2, fmt = fmt2)


##### Modifying Demands #####
updateBus!(system, analysis; label = "Bus 2", active = 25.2, reactive = 13.5)
updateBus!(system, analysis; label = "Bus 4", active = 43.3, reactive = 18.6)

solve!(system, analysis)
power!(system, analysis)

printGeneratorData(system, analysis; fmt = fmt3)
printBranchData(system, analysis; show = show2, fmt = fmt2)


##### Modifying Generator Costs #####
cost!(system, analysis; generator = "Generator 1", active = 2, polynomial = [2.0; 20.0; 0.0])
cost!(system, analysis; generator = "Generator 2", active = 2, polynomial = [0.8; 20.0; 0.0])
cost!(system, analysis; generator = "Generator 3", active = 2, polynomial = [0.8; 20.0; 0.0])

solve!(system, analysis)
power!(system, analysis)

printGeneratorData(system, analysis; fmt = fmt3)
printBranchData(system, analysis; show = show2, fmt = fmt2)


##### Adding Branch Flow Constraints #####
updateBranch!(system, analysis; label = "Branch 2", type = 1, maxFromBus = 15.0)
updateBranch!(system, analysis; label = "Branch 3", type = 1, maxFromBus = 15.0)

solve!(system, analysis)
power!(system, analysis)

printGeneratorData(system, analysis; fmt = fmt3)
printBranchConstraint(system, analysis)
printBranchData(system, analysis; show = show2, fmt = fmt2)


##### Modifying Network Topology #####
updateBranch!(system, analysis; label = "Branch 2", status = 0)

solve!(system, analysis)
power!(system, analysis)

printGeneratorData(system, analysis; fmt = fmt3)
printBranchData(system, analysis; show = show2, fmt = fmt2)