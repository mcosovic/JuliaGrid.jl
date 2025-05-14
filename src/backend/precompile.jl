import PrecompileTools

PrecompileTools.@setup_workload begin
    system = powerSystem()
    monitoring = measurement(system)
    pseudo = measurement(system)

    addBus!(system; label = 1, type = 3, active = 0.1)
    addBus!(system; label = 2, type = 1, reactive = 0.05)
    addBranch!(system; from = 1, to = 2, reactance = 0.05)
    addGenerator!(system; bus = 1, active = 0.5, reactive = 0.1)
    cost!(system; generator = 1, active = 2, polynomial = [0.11; 5.0; 150.0])

    addPmu!(monitoring; bus = 1, magnitude = 1.0, angle = 0.0)
    addPmu!(monitoring; bus = 2, magnitude = 1.0, angle = 0.0)
    addWattmeter!(pseudo; bus = 1, active = -0.1)

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
        measurement(system, "monitoring.h5")
        ems("case14.h5", "monitoring.h5")

        ########## Update ###########
        updateBus!(system; label = 1)

        ########## AC Power Flow ###########
        analysis = newtonRaphson(system)
        setInitialPoint!(analysis)
        solve!(analysis)
        power!(analysis)
        current!(analysis)
        reactiveLimit!(analysis)
        for (name, func) in accompile
            func(analysis; label = 1)
        end

        analysis = fastNewtonRaphsonBX(system)
        solve!(analysis)
        power!(analysis)
        current!(analysis)
        for (name, func) in accompile
            func(analysis; label = 1)
        end

        analysis = gaussSeidel(system)
        solve!(analysis)
        power!(analysis)
        current!(analysis)
        reactiveLimit!(analysis)
        for (name, func) in accompile
            func(analysis; label = 1)
        end

        ########## DC Power Flow ###########
        analysis = dcPowerFlow(system)
        solve!(analysis)
        power!(analysis)
        for (name, func) in dccompile
            func(analysis; label = 1)
        end

        analysis = dcPowerFlow(system, QR)
        solve!(analysis)

        analysis = dcPowerFlow(system, LDLt)
        solve!(analysis)

        ########## AC Optimal Power Flow ###########
        analysis = acOptimalPowerFlow(system, @nospecialize)
        power!(analysis)
        current!(analysis)
        for (name, func) in accompile
            func(analysis; label = 1)
        end

        ########## DC Optimal Power Flow ###########
        analysis = dcOptimalPowerFlow(system, @nospecialize)
        power!(analysis)
        for (name, func) in dccompile
            func(analysis; label = 1)
        end

        ########### Observability Analysis ###########
        islands = islandTopologicalFlow(monitoring)
        restorationGram!(monitoring, pseudo, islands)
        delete!(accompile, :generatorPower)
        delete!(dccompile, :generatorPower)

        ########## AC State Estimation ###########
        analysis = gaussNewton(monitoring)
        increment!(analysis)
        solve!(analysis)
        residualTest!(analysis)
        power!(analysis)
        current!(analysis)
        for (name, func) in accompile
            func(analysis; label = 1)
        end

        analysis = gaussNewton(monitoring, Orthogonal)
        increment!(analysis)
        solve!(analysis)

        analysis = gaussNewton(monitoring, PetersWilkinson)
        increment!(analysis)
        solve!(analysis)

        ########## PMU State Estimation ###########
        analysis = pmuStateEstimation(monitoring)
        solve!(analysis)
        residualTest!(analysis)
        power!(analysis)
        current!(analysis)
        for (name, func) in accompile
            func(analysis; label = 1)
        end

        analysis = pmuStateEstimation(monitoring, Orthogonal)
        solve!(analysis)

        analysis = pmuStateEstimation(monitoring, PetersWilkinson)
        solve!(analysis)

        ########### DC State Estimation ###########
        analysis = dcStateEstimation(monitoring)
        solve!(analysis)
        residualTest!(analysis)
        power!(analysis)
        for (name, func) in dccompile
            func(analysis; label = 1)
        end

        analysis = dcStateEstimation(monitoring, Orthogonal)
        solve!(analysis)

        analysis = dcStateEstimation(monitoring, PetersWilkinson)
        solve!(analysis)
    end
end