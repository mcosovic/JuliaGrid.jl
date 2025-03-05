using JuliaGrid

##### System of Units #####
@power(MW, MVAr)
@voltage(pu, deg)

##### Power System Model #####
system = powerSystem()

@bus(magnitude = 1.1, angle = -5.7)
addBus!(system; label = "Bus 1", type = 3, angle = 0.0)
addBus!(system; label = "Bus 2", type = 2, active = 20.2, reactive = 10.5)
addBus!(system; label = "Bus 3", type = 1, conductance = 0.1, susceptance = 8.2)
addBus!(system; label = "Bus 4", type = 1, active = 50.8, reactive = 23.1)

@branch(label = "Branch ?", reactance = 0.22)
addBranch!(system; from = "Bus 1", to = "Bus 3", resistance = 0.02, susceptance = 0.05)
addBranch!(system; from = "Bus 1", to = "Bus 2", resistance = 0.05, susceptance = 0.04)
addBranch!(system; from = "Bus 2", to = "Bus 3", resistance = 0.04, susceptance = 0.04)
addBranch!(system; from = "Bus 3", to = "Bus 4", turnsRatio = 0.98)

@generator(label = "Generator ?")
addGenerator!(system; bus = "Bus 1", active = 60.1, reactive = 40.2, magnitude = 0.98)
addGenerator!(system; bus = "Bus 2", active = 18.2, magnitude = 1.01)

acModel!(system)

##### Display Data Settings #####
show1 = Dict("Power Injection" => false)
fmt1 = Dict("Power Generation" => "%.2f", "Power Demand" => "%.2f", "Shunt Power" => "%.2f")

show2 = Dict("Shunt Power" => false, "Status" => false)
fmt2 = Dict("From-Bus Power" => "%.2f", "To-Bus Power" => "%.2f", "Series Power" => "%.2f")

##### Base Case Analysis #####
fnr = fastNewtonRaphsonXB(system)
acPowerFlow!(system, fnr; power = true, verbose = 2)

printBusData(system, fnr; show = show1, fmt = fmt1)
printBranchData(system, fnr; show = show2, fmt = fmt2)

##### Modifying Supplies and Demands #####
updateBus!(system, fnr; label = "Bus 2", active = 25.5, reactive = 15.0)
updateBus!(system, fnr; label = "Bus 4", active = 42.0, reactive = 20.0)

updateGenerator!(system, fnr; label = "Generator 1", active = 58.0, reactive = 20.0)
updateGenerator!(system, fnr; label = "Generator 2", active = 23.1, reactive = 20.0)

acPowerFlow!(system, fnr; power = true, verbose = 1)

printBranchData(system, fnr; show = show2, fmt = fmt2)

##### Modifying Network Topology #####
updateBranch!(system; label = "Branch 3", status = 0)

nr = newtonRaphson(system)
setInitialPoint!(fnr, nr)
acPowerFlow!(system, nr; power = true, verbose = 1)

printBranchData(system, nr; show = show2, fmt = fmt2)