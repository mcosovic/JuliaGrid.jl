system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "Newton-Raphson Method" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/newtonRaphson")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/newtonRaphson")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    analysis = newtonRaphson(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, analysis)
        iteration += 1
    end
    power!(system14, analysis)
    current!(system14, analysis)

    @test analysis.voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower14["voltageAngle"]
    @test iteration == matpower14["iteration"][1]
    @test analysis.power.injection.active ≈ matpower14["injectionActive"]
    @test analysis.power.injection.reactive ≈ matpower14["injectionReactive"]
    @test analysis.power.supply.active ≈ matpower14["supplyActive"]
    @test analysis.power.supply.reactive ≈ matpower14["supplyReactive"]
    @test analysis.power.shunt.active ≈ matpower14["shuntActive"]
    @test analysis.power.shunt.reactive ≈ matpower14["shuntReactive"]
    @test analysis.power.from.active ≈ matpower14["fromActive"]
    @test analysis.power.from.reactive ≈ matpower14["fromReactive"]
    @test analysis.power.to.active ≈ matpower14["toActive"]
    @test analysis.power.to.reactive ≈ matpower14["toReactive"]
    @test analysis.power.charging.from.reactive ≈ matpower14["chargingFrom"]
    @test analysis.power.charging.to.reactive ≈ matpower14["chargingTo"]
    @test analysis.power.series.active ≈ matpower14["lossActive"]
    @test analysis.power.series.reactive ≈ matpower14["lossReactive"]
    @test analysis.power.generator.active ≈ matpower14["generatorActive"]
    @test analysis.power.generator.reactive ≈ matpower14["generatorReactive"]

    injection = (complex.(analysis.power.injection.active, analysis.power.injection.reactive))
    voltage = (analysis.voltage.magnitude .* exp.(im * analysis.voltage.angle))
    @test analysis.current.injection.magnitude .* exp.(-im * analysis.current.injection.angle) ≈ injection ./ voltage

    from = (complex.(analysis.power.from.active, analysis.power.from.reactive))
    voltage = (analysis.voltage.magnitude[system14.branch.layout.from] .* exp.(im * analysis.voltage.angle[system14.branch.layout.from]))
    @test analysis.current.from.magnitude .* exp.(-im * analysis.current.from.angle) ≈ from ./ voltage

    to = (complex.(analysis.power.to.active, analysis.power.to.reactive))
    voltage = (analysis.voltage.magnitude[system14.branch.layout.to] .* exp.(im * analysis.voltage.angle[system14.branch.layout.to]))
    @test analysis.current.to.magnitude .* exp.(-im * analysis.current.to.angle) ≈ to ./ voltage

    transformerRatio = (1 ./ system14.branch.parameter.turnsRatio) .* exp.(-im * system14.branch.parameter.shiftAngle)
    voltageFrom = analysis.voltage.magnitude[system14.branch.layout.from] .* exp.(im * analysis.voltage.angle[system14.branch.layout.from])
    voltageTo = analysis.voltage.magnitude[system14.branch.layout.to] .* exp.(im * analysis.voltage.angle[system14.branch.layout.to])
    series = complex.(analysis.power.series.active, analysis.power.series.reactive)
    @test analysis.current.series.magnitude .* exp.(-im * analysis.current.series.angle) ≈ series ./ (transformerRatio .* voltageFrom - voltageTo)

    for (key, value) in system14.bus.label
        injection = powerInjection(system14, analysis; label = key)
        @test injection.active ≈ analysis.power.injection.active[value]
        @test injection.reactive ≈ analysis.power.injection.reactive[value]

        supply = powerSupply(system14, analysis; label = key)
        @test supply.active ≈ analysis.power.supply.active[value]
        @test supply.reactive ≈ analysis.power.supply.reactive[value]

        shunt = powerShunt(system14, analysis; label = key)
        @test shunt.active ≈ analysis.power.shunt.active[value]
        @test shunt.reactive ≈ analysis.power.shunt.reactive[value]

        injection = currentInjection(system14, analysis; label = key)
        @test injection.magnitude ≈ analysis.current.injection.magnitude[value]
        @test injection.angle ≈ analysis.current.injection.angle[value]
    end

    for (key, value) in system14.branch.label
        from = powerFrom(system14, analysis; label = key)
        @test from.active ≈ analysis.power.from.active[value]
        @test from.reactive ≈ analysis.power.from.reactive[value]

        to = powerTo(system14, analysis; label = key)
        @test to.active ≈ analysis.power.to.active[value]
        @test to.reactive ≈ analysis.power.to.reactive[value]

        charging = powerCharging(system14, analysis; label = key)
        @test charging.from.active ≈ analysis.power.charging.from.active[value]
        @test charging.from.reactive ≈ analysis.power.charging.from.reactive[value]
        @test charging.to.active ≈ analysis.power.charging.to.active[value]
        @test charging.to.reactive ≈ analysis.power.charging.to.reactive[value]

        series = powerSeries(system14, analysis; label = key)
        @test series.active ≈ analysis.power.series.active[value]
        @test series.reactive ≈ analysis.power.series.reactive[value]

        from = currentFrom(system14, analysis; label = key)
        @test from.magnitude ≈ analysis.current.from.magnitude[value]
        @test from.angle ≈ analysis.current.from.angle[value]

        to = currentTo(system14, analysis; label = key)
        @test to.magnitude ≈ analysis.current.to.magnitude[value]
        @test to.angle ≈ analysis.current.to.angle[value]

        series = currentSeries(system14, analysis; label = key)
        @test series.magnitude ≈ analysis.current.series.magnitude[value]
        @test series.angle ≈ analysis.current.series.angle[value]
    end

    for (key, value) in system14.generator.label
        output = powerGenerator(system14, analysis; label = key)
        @test output.active ≈ analysis.power.generator.active[value]
        @test output.reactive ≈ analysis.power.generator.reactive[value]
    end

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    analysis = newtonRaphson(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
        iteration += 1
    end
    power!(system30, analysis)
    current!(system30, analysis)

    @test analysis.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower30["voltageAngle"]
    @test iteration == matpower30["iteration"][1]
    @test analysis.power.injection.active ≈ matpower30["injectionActive"]
    @test analysis.power.injection.reactive ≈ matpower30["injectionReactive"]
    @test analysis.power.supply.active ≈ matpower30["supplyActive"]
    @test analysis.power.supply.reactive ≈ matpower30["supplyReactive"]
    @test analysis.power.shunt.active ≈ matpower30["shuntActive"]
    @test analysis.power.shunt.reactive ≈ matpower30["shuntReactive"]
    @test analysis.power.from.active ≈ matpower30["fromActive"]
    @test analysis.power.from.reactive ≈ matpower30["fromReactive"]
    @test analysis.power.to.active ≈ matpower30["toActive"]
    @test analysis.power.to.reactive ≈ matpower30["toReactive"]
    @test analysis.power.charging.from.reactive ≈ matpower30["chargingFrom"]
    @test analysis.power.charging.to.reactive ≈ matpower30["chargingTo"]
    @test analysis.power.series.active ≈ matpower30["lossActive"]
    @test analysis.power.series.reactive ≈ matpower30["lossReactive"]
    @test analysis.power.generator.active ≈ matpower30["generatorActive"]
    @test analysis.power.generator.reactive ≈ matpower30["generatorReactive"]

    injection = (complex.(analysis.power.injection.active, analysis.power.injection.reactive))
    voltage = (analysis.voltage.magnitude .* exp.(im * analysis.voltage.angle))
    @test analysis.current.injection.magnitude .* exp.(-im * analysis.current.injection.angle) ≈ injection ./ voltage

    from = (complex.(analysis.power.from.active, analysis.power.from.reactive))
    voltage = (analysis.voltage.magnitude[system30.branch.layout.from] .* exp.(im * analysis.voltage.angle[system30.branch.layout.from]))
    @test analysis.current.from.magnitude .* exp.(-im * analysis.current.from.angle) ≈ from ./ voltage

    to = (complex.(analysis.power.to.active, analysis.power.to.reactive))
    voltage = (analysis.voltage.magnitude[system30.branch.layout.to] .* exp.(im * analysis.voltage.angle[system30.branch.layout.to]))
    @test analysis.current.to.magnitude .* exp.(-im * analysis.current.to.angle) ≈ to ./ voltage

    transformerRatio = (1 ./ system30.branch.parameter.turnsRatio) .* exp.(-im * system30.branch.parameter.shiftAngle)
    voltageFrom = analysis.voltage.magnitude[system30.branch.layout.from] .* exp.(im * analysis.voltage.angle[system30.branch.layout.from])
    voltageTo = analysis.voltage.magnitude[system30.branch.layout.to] .* exp.(im * analysis.voltage.angle[system30.branch.layout.to])
    series = complex.(analysis.power.series.active, analysis.power.series.reactive)
    @test analysis.current.series.magnitude .* exp.(-im * analysis.current.series.angle) ≈ series ./ (transformerRatio .* voltageFrom - voltageTo)

    for (key, value) in system30.bus.label
        injection = powerInjection(system30, analysis; label = key)
        @test injection.active ≈ analysis.power.injection.active[value]
        @test injection.reactive ≈ analysis.power.injection.reactive[value]

        supply = powerSupply(system30, analysis; label = key)
        @test supply.active ≈ analysis.power.supply.active[value]
        @test supply.reactive ≈ analysis.power.supply.reactive[value]

        shunt = powerShunt(system30, analysis; label = key)
        @test shunt.active ≈ analysis.power.shunt.active[value]
        @test shunt.reactive ≈ analysis.power.shunt.reactive[value]

        injection = currentInjection(system30, analysis; label = key)
        @test injection.magnitude ≈ analysis.current.injection.magnitude[value]
        @test injection.angle ≈ analysis.current.injection.angle[value]
    end

    for (key, value) in system30.branch.label
        from = powerFrom(system30, analysis; label = key)
        @test from.active ≈ analysis.power.from.active[value]
        @test from.reactive ≈ analysis.power.from.reactive[value]

        to = powerTo(system30, analysis; label = key)
        @test to.active ≈ analysis.power.to.active[value]
        @test to.reactive ≈ analysis.power.to.reactive[value]

        charging = powerCharging(system30, analysis; label = key)
        @test charging.from.active ≈ analysis.power.charging.from.active[value]
        @test charging.from.reactive ≈ analysis.power.charging.from.reactive[value]
        @test charging.to.active ≈ analysis.power.charging.to.active[value]
        @test charging.to.reactive ≈ analysis.power.charging.to.reactive[value]

        series = powerSeries(system30, analysis; label = key)
        @test series.active ≈ analysis.power.series.active[value]
        @test series.reactive ≈ analysis.power.series.reactive[value]

        from = currentFrom(system30, analysis; label = key)
        @test from.magnitude ≈ analysis.current.from.magnitude[value]
        @test from.angle ≈ analysis.current.from.angle[value]

        to = currentTo(system30, analysis; label = key)
        @test to.magnitude ≈ analysis.current.to.magnitude[value]
        @test to.angle ≈ analysis.current.to.angle[value]

        series = currentSeries(system30, analysis; label = key)
        @test series.magnitude ≈ analysis.current.series.magnitude[value]
        @test series.angle ≈ analysis.current.series.angle[value]
    end

    for (key, value) in system30.generator.label
        output = powerGenerator(system30, analysis; label = key)
        @test output.active ≈ analysis.power.generator.active[value]
        @test output.reactive ≈ analysis.power.generator.reactive[value]
    end
end

@testset "Fast Newton-Raphson BX Method" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/fastNewtonRaphsonBX")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/fastNewtonRaphsonBX")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    analysis = fastNewtonRaphsonBX(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, analysis)
        iteration += 1
    end

    @test analysis.voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower14["voltageAngle"]
    @test iteration == matpower14["iteration"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    analysis = fastNewtonRaphsonBX(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
        iteration += 1
    end

    @test analysis.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower30["voltageAngle"]
    @test iteration == matpower30["iteration"][1]
end

@testset "Fast Newton-Raphson XB Method" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/fastNewtonRaphsonXB")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/fastNewtonRaphsonXB")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    analysis = fastNewtonRaphsonXB(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, analysis)
        iteration += 1
    end

    @test analysis.voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower14["voltageAngle"]
    @test iteration == matpower14["iteration"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    analysis = fastNewtonRaphsonXB(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
        iteration += 1
    end

    @test analysis.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower30["voltageAngle"]
    @test iteration == matpower30["iteration"][1]
end

@testset "Gauss-Seidel Method" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/gaussSeidel")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/gaussSeidel")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    analysis = gaussSeidel(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, analysis)
        iteration += 1
    end

    @test analysis.voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower14["voltageAngle"]
    @test iteration == matpower14["iteration"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    analysis = gaussSeidel(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
        iteration += 1
    end

    @test analysis.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower30["voltageAngle"]
    @test iteration == matpower30["iteration"][1]
end

@testset "AC Power Flow" begin
    system14.branch.parameter.conductance[14] = 0.052
    system14.branch.parameter.conductance[7] = 0.083
    system14.branch.parameter.conductance[1] = 0.58

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    nr = newtonRaphson(system14)
    for i = 1:1000
        stopping = mismatch!(system14, nr)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, nr)
    end

    fnrBX = fastNewtonRaphsonBX(system14)
    for i = 1:1000
        stopping = mismatch!(system14, fnrBX)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, fnrBX)
    end

    fnrXB = fastNewtonRaphsonXB(system14)
    for i = 1:1000
        stopping = mismatch!(system14, fnrXB)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, fnrXB)
    end

    gs = gaussSeidel(system14)
    for i = 1:3000
        stopping = mismatch!(system14, gs)
        if all(stopping .< 1e-9)
            break
        end
        solve!(system14, gs)
    end

    @test nr.voltage.magnitude ≈ fnrBX.voltage.magnitude
    @test nr.voltage.angle ≈ fnrBX.voltage.angle
    @test nr.voltage.magnitude ≈ fnrXB.voltage.magnitude
    @test nr.voltage.angle ≈ fnrXB.voltage.angle
    @test nr.voltage.magnitude ≈ gs.voltage.magnitude
    @test nr.voltage.angle ≈ gs.voltage.angle
end


@testset "DC Power Flow" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/dcPowerFlow")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/dcPowerFlow")

    ######## Modified IEEE 14-bus Test Case ##########
    dcModel!(system14)
    analysis = dcPowerFlow(system14)
    solve!(system14, analysis)
    power!(system14, analysis)

    @test analysis.voltage.angle ≈ matpower14["voltage"]
    @test analysis.power.injection.active ≈ matpower14["injection"]
    @test analysis.power.supply.active ≈ matpower14["supply"]
    @test analysis.power.from.active ≈ matpower14["from"]
    @test analysis.power.to.active ≈ -matpower14["from"]
    @test analysis.power.generator.active ≈ matpower14["generator"]

    for (key, value) in system14.bus.label
        @test powerInjection(system14, analysis; label = key) ≈ matpower14["injection"][value] atol = 1e-14
        @test powerSupply(system14, analysis; label = key) ≈ matpower14["supply"][value] atol = 1e-14
    end

    for (key, value) in system14.branch.label
        @test powerFrom(system14, analysis; label = key) ≈ matpower14["from"][value] atol = 1e-14
        @test powerTo(system14, analysis; label = key) ≈ -matpower14["from"][value] atol = 1e-14
    end

    for (key, value) in system14.generator.label
        @test powerGenerator(system14, analysis; label = key) ≈ matpower14["generator"][value] atol = 1e-14
    end

    ######## Modified IEEE 30-bus Test Case ##########
    dcModel!(system30)
    analysis = dcPowerFlow(system30)
    solve!(system30, analysis)
    power!(system30, analysis)

    @test analysis.voltage.angle ≈ matpower30["voltage"]
    @test analysis.power.injection.active ≈ matpower30["injection"]
    @test analysis.power.supply.active ≈ matpower30["supply"]
    @test analysis.power.from.active ≈ matpower30["from"]
    @test analysis.power.to.active ≈ -matpower30["from"]
    @test analysis.power.generator.active ≈ matpower30["generator"]

    for (key, value) in system30.bus.label
        @test powerInjection(system30, analysis; label = key) ≈ matpower30["injection"][value] atol = 1e-14
        @test powerSupply(system30, analysis; label = key) ≈ matpower30["supply"][value] atol = 1e-14
    end

    for (key, value) in system30.branch.label
        @test powerFrom(system30, analysis; label = key) ≈ matpower30["from"][value] atol = 1e-14
        @test powerTo(system30, analysis; label = key) ≈ -matpower30["from"][value] atol = 1e-14
    end

    for (key, value) in system30.generator.label
        @test powerGenerator(system30, analysis; label = key) ≈ matpower30["generator"][value] atol = 1e-14
    end
end