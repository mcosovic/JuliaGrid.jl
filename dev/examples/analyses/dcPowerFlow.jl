using JuliaGrid

##### System of Units #####
@power(MW, pu)
@voltage(pu, deg)

##### Power System Model #####
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, angle = 0.0)
addBus!(system; label = "Bus 2", active = 20.2)
addBus!(system; label = "Bus 3", conductance = 0.1)
addBus!(system; label = "Bus 4", active = 50.8)

@branch(reactance = 0.22)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 3")
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2")
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3")
addBranch!(system; label = "Branch 4", from = "Bus 3", to = "Bus 4", shiftAngle = -2.3)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 60.1)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 18.2)

dcModel!(system)

##### Display Data Settings #####
@config(verbose = 1)

##### Base Case Analysis #####
analysis = dcPowerFlow(system)
powerFlow!(analysis; power = true)

printBusData(analysis)
printBranchData(analysis)

##### Modifying Supplies and Demands #####
updateBus!(analysis; label = "Bus 2", active = 25.5)
updateBus!(analysis; label = "Bus 4", active = 42.0)

updateGenerator!(analysis; label = "Generator 1", active = 58.0)
updateGenerator!(analysis; label = "Generator 2", active = 23.0)

powerFlow!(analysis; power = true)

printBranchData(analysis)

##### Modifying Network Topology #####
updateBranch!(analysis; label = "Branch 3", status = 0)

powerFlow!(analysis; power = true)

printBranchData(analysis)