import PrecompileTools

PrecompileTools.@setup_workload begin
    system = powerSystem()
    device = measurement()
    pseudo = measurement()

    addBus!(system; label = 1, type = 3, active = 0.1)
    addBus!(system; label = 2, type = 1, reactive = 0.05)
    addBranch!(system; from = 1, to = 2, reactance = 0.05)
    addGenerator!(system; bus = 1, active = 0.5, reactive = 0.1)
    cost!(system; generator = 1, active = 2, polynomial = [0.11; 5.0; 150.0])

    addPmu!(system, device; bus = 1, magnitude = 1.0, angle = 0.0)
    addPmu!(system, device; bus = 2, magnitude = 1.0, angle = 0.0)
    addWattmeter!(system, pseudo; bus = 1, active = -0.1)

    accompile = Dict(
        :injectionPower => injectionPower,
        :supplyPower => supplyPower,
        :shuntPower => shuntPower,
        :fromPower => fromPower,
        :toPower => toPower,
        :chargingPower => chargingPower,
        :seriesPower => seriesPower,
        :generatorPower => generatorPower,
        :injectionCurrent => injectionCurrent,
        :fromCurrent => fromCurrent,
        :toCurrent => toCurrent,
        :seriesCurrent => seriesCurrent,
    )

    dccompile = Dict(
        :injectionPower => injectionPower,
        :supplyPower => supplyPower,
        :fromPower => fromPower,
        :toPower => toPower,
        :generatorPower => generatorPower,
    )

    PrecompileTools.@compile_workload begin
        ########## HDF5 Files ###########
        powerSystem("case14.h5")
        measurement("measurement14.h5")

        ########## AC Power Flow ###########
        analysis = newtonRaphson(system)
        setInitialPoint!(system, analysis)
        solve!(system, analysis)
        power!(system, analysis)
        current!(system, analysis)
        for (name, func) in accompile
            func(system, analysis; label = 1)
        end

        analysis = fastNewtonRaphsonBX(system)
        solve!(system, analysis)
        power!(system, analysis)
        current!(system, analysis)
        for (name, func) in accompile
            func(system, analysis; label = 1)
        end

        analysis = gaussSeidel(system)
        solve!(system, analysis)
        power!(system, analysis)
        current!(system, analysis)
        for (name, func) in accompile
            func(system, analysis; label = 1)
        end

        ########## DC Power Flow ###########
        analysis = dcPowerFlow(system)
        solve!(system, analysis)
        power!(system, analysis)
        for (name, func) in dccompile
            func(system, analysis; label = 1)
        end

        analysis = dcPowerFlow(system, QR)
        solve!(system, analysis)

        analysis = dcPowerFlow(system, LDLt)
        solve!(system, analysis)

        ########## AC Optimal Power Flow ###########
        analysis = acOptimalPowerFlow(system, @nospecialize)
        power!(system, analysis)
        current!(system, analysis)
        for (name, func) in accompile
            func(system, analysis; label = 1)
        end

        ########## DC Optimal Power Flow ###########
        analysis = dcOptimalPowerFlow(system, @nospecialize)
        power!(system, analysis)
        for (name, func) in dccompile
            func(system, analysis; label = 1)
        end

        ########### Observability Analysis ###########
        islands = islandTopologicalFlow(system, device)
        restorationGram!(system, device, pseudo, islands)
        delete!(accompile, :generatorPower)
        delete!(dccompile, :generatorPower)

        ########## AC State Estimation ###########
        analysis = gaussNewton(system, device)
        solve!(system, analysis)
        residualTest!(system, device, analysis)
        power!(system, analysis)
        current!(system, analysis)
        for (name, func) in accompile
            func(system, analysis; label = 1)
        end

        ########## PMU State Estimation ###########
        analysis = pmuStateEstimation(system, device)
        solve!(system, analysis)
        residualTest!(system, device, analysis)
        power!(system, analysis)
        current!(system, analysis)
        for (name, func) in accompile
            func(system, analysis; label = 1)
        end

        ########### DC State Estimation ###########
        analysis = dcStateEstimation(system, device)
        solve!(system, analysis)
        residualTest!(system, device, analysis)
        power!(system, analysis)
        for (name, func) in dccompile
            func(system, analysis; label = 1)
        end
    end
end