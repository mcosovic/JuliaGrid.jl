using JuliaGrid

##### Power System Model #####
system = powerSystem()

addBus!(system; label = "Bus 1", magnitude = 1.01, angle = 0.0, type = 3)
addBus!(system; label = "Bus 2", magnitude = 0.92, angle = -0.04)
addBus!(system; label = "Bus 3", magnitude = 0.93, angle = -0.05)

@branch(reactance = 0.03)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 3", resistance = 0.02)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2", resistance = 0.05)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", resistance = 0.04)

addGenerator!(system; label = "Generator 1", bus = "Bus 1")

##### Display Data Settings #####
@config(verbose = 1)

show = Dict("Shunt Power" => false, "Status" => false)

##### Measurement Model #####
monitoring = measurement(system)

updateBus!(system; label = "Bus 2", type = 1, active = 1.1, reactive = 0.3)
updateBus!(system; label = "Bus 3", type = 1, active = 2.3, reactive = 0.2)

updateGenerator!(system; label = "Generator 1", active = 3.3, reactive = 2.1)

acModel!(system)

powerFlow = newtonRaphson(system)
powerFlow!(powerFlow)

printBusData(powerFlow)

@voltmeter(label = "Meter ?")
addVoltmeter!(monitoring, powerFlow; variance = 1e-4, noise = true)

printVoltmeterData(monitoring)

@wattmeter(label = "Meter ?")
@varmeter(label = "Meter ?")
for (label, idx) in system.bus.label
    Pᵢ, Qᵢ = injectionPower(powerFlow; label)
    addWattmeter!(monitoring; bus = label, active = Pᵢ, variance = 1e-3, noise = true)
    addVarmeter!(monitoring; bus = label, reactive = Qᵢ, variance = 1e-4, noise = true)
end

Pᵢⱼ, Qᵢⱼ = fromPower(powerFlow; label = "Branch 1")
addWattmeter!(monitoring; label = "Meter 4", from = "Branch 1", active = Pᵢⱼ)
addVarmeter!(monitoring; label = "Meter 4", from = "Branch 1", reactive = Qᵢⱼ)

Pⱼᵢ, Qⱼᵢ = toPower(powerFlow; label = "Branch 1")
addWattmeter!(monitoring; label = "Meter 5", to = "Branch 1", active = Pⱼᵢ)
addVarmeter!(monitoring; label = "Meter 5", to = "Branch 1", reactive = Qⱼᵢ)

printWattmeterData(monitoring)
printVarmeterData(monitoring)

@ammeter(statusFrom = 0, statusTo = 0)
addAmmeter!(monitoring; label = "Meter 4", from = "Branch 1", magnitude = 1.36)
addAmmeter!(monitoring; label = "Meter 5", to = "Branch 1", magnitude = 2.37)

printAmmeterData(monitoring)

##### Base Case Analysis #####
analysis = gaussNewton(monitoring)
stateEstimation!(analysis; power = true, verbose = 2)

printBusData(analysis; show)
printBranchData(analysis; show)
printWattmeterData(analysis)

##### Modifying Measurement Data #####
updateVoltmeter!(analysis; label = "Meter 1", magnitude = 1.0, noise = false)
updateWattmeter!(analysis; label = "Meter 2", active = -1.1, variance = 1e-6)
updateVarmeter!(analysis; label = "Meter 3", variance = 1e-1)

stateEstimation!(analysis; power = true)
printBusData(analysis; show)

##### Modifying Measurement Set #####
updateAmmeter!(analysis; label = "Meter 4", status = 1)
updateAmmeter!(analysis; label = "Meter 5", status = 1)

stateEstimation!(analysis; power = true)
printBusData(analysis; show)

outlier = residualTest!(analysis; threshold = 4.0)

setInitialPoint!(analysis)
stateEstimation!(analysis; power = true)
printBusData(analysis; show)