using JuliaGrid

##### Wrapper Function #####
function acPowerFlow!(system::PowerSystem, analysis::ACPowerFlow)
    for iteration = 1:20
        stopping = mismatch!(system, analysis)
        if all(stopping .< 1e-8)
            println("The algorithm converged in $(iteration - 1) iterations.")
            break
        end
        solve!(system, analysis)
    end
    power!(system, analysis)
end

##### Power System Model #####
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, magnitude = 0.91, angle = -0.01)
addBus!(system; label = "Bus 3", type = 2, active = 0.2, reactive = 0.1)
addBus!(system; label = "Bus 4", type = 1, active = 0.5, reactive = 0.2)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.06, resistance = 0.02, susceptance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.22, resistance = 0.05, susceptance = 0.04)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.19, resistance = 0.04, susceptance = 0.04)
addBranch!(system; label = "Branch 4", from = "Bus 2", to = "Bus 4", reactance = 0.32, turnsRatio = 0.98)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 2.3, reactive = 0.4)
addGenerator!(system; label = "Generator 2", bus = "Bus 3", active = 0.4, magnitude = 1.1)

acModel!(system)

##### Base Case Analysis #####
fnr = fastNewtonRaphsonXB(system)
acPowerFlow!(system, fnr)

show = Dict("Shunt Power" => false, "Series Power" => false)
printBusData(system, fnr; show)
printBranchData(system, fnr; show)

##### Modifying Generators and Demands #####
updateBus!(system, fnr; label = "Bus 3", type = 2, active = 0.3, reactive = 0.0)
updateBus!(system, fnr; label = "Bus 4", type = 1, active = 0.1, reactive = 0.1)

updateGenerator!(system, fnr; label = "Generator 1", active = 2.0, reactive = 0.2)
updateGenerator!(system, fnr; label = "Generator 2", active = 1.2, reactive = 0.2)

acPowerFlow!(system, fnr)

printBranchData(system, fnr; show)

##### Modifying Power System Topology #####
updateBranch!(system; label = "Branch 3", status = 0)

nr = newtonRaphson(system)
transferVoltage!(fnr, nr)
acPowerFlow!(system, nr)

printBranchData(system, nr; show)