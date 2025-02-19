using JuliaGrid


##### Wrapper Function #####
function acStateEstimation!(system::PowerSystem, analysis::ACStateEstimation)
    for iteration = 1:20
        stopping = solve!(system, analysis)
        if stopping < 1e-8
            println("The algorithm converged in $iteration iterations.")
            break
        end
    end
    power!(system, analysis)
end


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
show = Dict("Shunt Power" => false, "Status" => false)


##### Measurement Model #####
device = measurement()

acModel!(system)
powerFlow = newtonRaphson(system)
for iteration = 1:20
    stopping = mismatch!(system, powerFlow)
    if all(stopping .< 1e-8)
        println("The algorithm converged in $(iteration - 1) iterations.")
        break
    end
    solve!(system, powerFlow)
end

printBusData(system, powerFlow)

@voltmeter(label = "Meter ?")
addVoltmeter!(system, device, powerFlow; variance = 1e-4, noise = true)

printVoltmeterData(system, device)

@wattmeter(label = "Meter ?")
@varmeter(label = "Meter ?")
for (label, idx) in system.bus.label
    Pᵢ, Qᵢ = injectionPower(system, powerFlow; label)
    addWattmeter!(system, device; bus = label, active = Pᵢ, variance = 1e-3, noise = true)
    addVarmeter!(system, device; bus = label, reactive = Qᵢ, variance = 1e-4, noise = true)
end

Pᵢⱼ, Qᵢⱼ = fromPower(system, powerFlow; label = "Branch 1")
addWattmeter!(system, device; label = "Meter 4", from = "Branch 1", active = Pᵢⱼ)
addVarmeter!(system, device; label = "Meter 4", from = "Branch 1", reactive = Qᵢⱼ)

Pⱼᵢ, Qⱼᵢ = toPower(system, powerFlow; label = "Branch 1")
addWattmeter!(system, device; label = "Meter 5", to = "Branch 1", active = Pⱼᵢ)
addVarmeter!(system, device; label = "Meter 5", to = "Branch 1", reactive = Qⱼᵢ)

printWattmeterData(system, device)
printVarmeterData(system, device)

@ammeter(statusFrom = 0, statusTo = 0)
addAmmeter!(system, device; label = "Meter 4", from = "Branch 1", magnitude = 1.36)
addAmmeter!(system, device; label = "Meter 5", to = "Branch 1", magnitude = 2.37)

printAmmeterData(system, device)


##### Base Case Analysis #####
analysis = gaussNewton(system, device)
acStateEstimation!(system, analysis)

printBusData(system, analysis; show)
printBranchData(system, analysis; show)
printWattmeterData(system, device, analysis)


##### Modifying Measurement Data #####
updateVoltmeter!(system, device, analysis; label = "Meter 1", magnitude = 1.0, noise = false)
updateWattmeter!(system, device, analysis; label = "Meter 2", active = -1.1, variance = 1e-6)
updateVarmeter!(system, device, analysis; label = "Meter 3", variance = 1e-1)

acStateEstimation!(system, analysis)
printBusData(system, analysis; show)


##### Modifying Measurement Set #####
updateAmmeter!(system, device, analysis; label = "Meter 4", status = 1)
updateAmmeter!(system, device, analysis; label = "Meter 5", status = 1)

acStateEstimation!(system, analysis)
printBusData(system, analysis; show)

outlier = residualTest!(system, device, analysis; threshold = 4.0)

setInitialPoint!(system, analysis)
acStateEstimation!(system, analysis)
printBusData(system, analysis; show)