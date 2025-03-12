using JuliaGrid, Ipopt

##### System of Units #####
@power(MW, pu)
@voltage(pu, deg)

##### Power System Model #####
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", active = 20.2)
addBus!(system; label = "Bus 3", conductance = 0.1)
addBus!(system; label = "Bus 4", active = 50.8)

@branch(reactance = 0.2, minDiffAngle = -4.2, maxDiffAngle = 4.2)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 3")
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2")
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3")
addBranch!(system; label = "Branch 4", from = "Bus 3", to = "Bus 4", shiftAngle = -2.3)

@generator(label = "Generator ?")
addGenerator!(system; bus = "Bus 1", active = 63.1, minActive = 10.0, maxActive = 65.5)
addGenerator!(system; bus = "Bus 2", active = 3.0, minActive = 7.0, maxActive = 20.5)
addGenerator!(system; bus = "Bus 2", active = 4.1, minActive = 7.0, maxActive = 22.4)

cost!(system; generator = "Generator 1", active = 2, polynomial = [0.04; 20.0; 0.0])
cost!(system; generator = "Generator 2", active = 2, polynomial = [1.00; 20.0; 0.0])
cost!(system; generator = "Generator 3", active = 2, polynomial = [1.00; 20.0; 0.0])

dcModel!(system)

##### Display Data Settings #####
fmt = Dict("From-Bus Power" => "%.2f", "To-Bus Power" => "%.2f", "Power Output" => "%.2f")

##### Base Case Analysis #####
analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer; angle = "θ", active = "Pg")
print(analysis.method.jump)

powerFlow!(system, analysis, power = true, verbose = 1)

printBusData(system, analysis)
printBranchConstraint(system, analysis; label = "Branch 1", header = true, footer = true)
printGeneratorData(system, analysis; fmt)
printGeneratorConstraint(system, analysis)
printBranchData(system, analysis; fmt)

##### Modifying Demands #####
updateBus!(system, analysis; label = "Bus 2", active = 25.2)
updateBus!(system, analysis; label = "Bus 4", active = 43.3)

powerFlow!(system, analysis, power = true, verbose = 1)

printGeneratorData(system, analysis; fmt)
printBranchConstraint(system, analysis)
printBranchData(system, analysis; fmt)

##### Modifying Generator Costs #####
cost!(system, analysis; generator = "Generator 1", active = 2, polynomial = [2.0; 40.0; 0.0])
cost!(system, analysis; generator = "Generator 3", active = 2, polynomial = [0.5; 10.0; 0.0])

powerFlow!(system, analysis, power = true, verbose = 1)

printGeneratorData(system, analysis; fmt)
printBranchData(system, analysis; fmt)

##### Adding Branch Flow Constraints #####
updateBranch!(system, analysis; label = "Branch 2", type = 1, maxFromBus = 15.0)
updateBranch!(system, analysis; label = "Branch 3", type = 1, maxFromBus = 15.0)

powerFlow!(system, analysis, power = true, verbose = 1)

printGeneratorData(system, analysis; fmt)
printBranchData(system, analysis; fmt)

##### Modifying Network Topology #####
updateBranch!(system, analysis; label = "Branch 2", status = 0)

powerFlow!(system, analysis, power = true, verbose = 1)

printGeneratorData(system, analysis; fmt)
printBranchData(system, analysis; fmt)