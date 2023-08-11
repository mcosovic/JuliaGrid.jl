system14 = powerSystem(string(pathData, "case14optimal.m"))

@testset "AC Optimal Power Flow" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14optimal/acOptimalPowerFlow")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
    solve!(system14, analysis)
    power!(system14, analysis)
    current!(system14, analysis)

    @test analysis.voltage.magnitude ≈ matpower14["voltageMagnitude"] atol = 1e-6
    @test analysis.voltage.angle ≈ matpower14["voltageAngle"] atol = 1e-6
    @test analysis.power.injection.active ≈ matpower14["injectionActive"] atol = 1e-6
    @test analysis.power.injection.reactive ≈ matpower14["injectionReactive"] atol = 1e-6
    @test analysis.power.supply.active ≈ matpower14["supplyActive"] atol = 1e-6
    @test analysis.power.supply.reactive ≈ matpower14["supplyReactive"] atol = 1e-6
    @test analysis.power.shunt.active ≈ matpower14["shuntActive"] atol = 1e-6
    @test analysis.power.shunt.reactive ≈ matpower14["shuntReactive"] atol = 1e-6
    @test analysis.power.from.active ≈ matpower14["fromActive"] atol = 1e-6
    @test analysis.power.from.reactive ≈ matpower14["fromReactive"] atol = 1e-6
    @test analysis.power.to.active ≈ matpower14["toActive"] atol = 1e-6
    @test analysis.power.to.reactive ≈ matpower14["toReactive"] atol = 1e-6
    @test analysis.power.charging.from.reactive ≈ matpower14["chargingFrom"] atol = 1e-6
    @test analysis.power.charging.to.reactive ≈ matpower14["chargingTo"] atol = 1e-6
    @test analysis.power.series.active ≈ matpower14["lossActive"] atol = 1e-6
    @test analysis.power.series.reactive ≈ matpower14["lossReactive"] atol = 1e-6
    @test analysis.power.generator.active ≈ matpower14["generatorActive"] atol = 1e-6
    @test analysis.power.generator.reactive ≈ matpower14["generatorReactive"] atol = 1e-6

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
        @test shunt.active ≈ analysis.power.shunt.active[value] atol = 1e-10
        @test shunt.reactive ≈ analysis.power.shunt.reactive[value] atol = 1e-10

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
end

system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "DC Optimal Power Flow" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/dcOptimalPowerFlow")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/dcOptimalPowerFlow")

    ######## Modified IEEE 14-bus Test Case ##########
    dcModel!(system14)
    analysis = dcOptimalPowerFlow(system14, Ipopt.Optimizer)
    solve!(system14, analysis)
    power!(system14, analysis)

    @test analysis.voltage.angle ≈ matpower14["voltage"] atol = 1e-6
    @test analysis.power.injection.active ≈ matpower14["injection"] atol = 1e-6
    @test analysis.power.supply.active ≈ matpower14["supply"] atol = 1e-6
    @test analysis.power.from.active ≈ matpower14["from"] atol = 1e-6
    @test analysis.power.to.active ≈ -matpower14["from"] atol = 1e-6
    @test analysis.power.generator.active ≈ matpower14["generator"] atol = 1e-6

    for (key, value) in system14.bus.label
        @test powerInjection(system14, analysis; label = key) ≈ analysis.power.injection.active[value]
        @test powerSupply(system14, analysis; label = key) ≈ analysis.power.supply.active[value]
    end

    for (key, value) in system14.branch.label
        @test powerFrom(system14, analysis; label = key) ≈ analysis.power.from.active[value]
        @test powerTo(system14, analysis; label = key) ≈ analysis.power.to.active[value]
    end

    for (key, value) in system14.generator.label
        @test powerGenerator(system14, analysis; label = key) ≈ analysis.power.generator.active[value]
    end

    ######## Modified IEEE 30-bus Test Case ##########
    dcModel!(system30)
    analysis = dcOptimalPowerFlow(system30, HiGHS.Optimizer)
    solve!(system30, analysis)
    power!(system30, analysis)

    @test analysis.voltage.angle ≈ matpower30["voltage"] atol = 1e-10
    @test analysis.power.injection.active ≈ matpower30["injection"] atol = 1e-6
    @test analysis.power.supply.active ≈ matpower30["supply"] atol = 1e-10
    @test analysis.power.from.active ≈ matpower30["from"] atol = 1e-10
    @test analysis.power.to.active ≈ -matpower30["from"] atol = 1e-10
    @test analysis.power.generator.active ≈ matpower30["generator"] atol = 1e-10

    for (key, value) in system30.bus.label
        @test powerInjection(system30, analysis; label = key) ≈ analysis.power.injection.active[value]
        @test powerSupply(system30, analysis; label = key) ≈ analysis.power.supply.active[value]
    end

    for (key, value) in system30.branch.label
        @test powerFrom(system30, analysis; label = key) ≈ analysis.power.from.active[value]
        @test powerTo(system30, analysis; label = key) ≈ analysis.power.to.active[value]
    end

    for (key, value) in system30.generator.label
        @test powerGenerator(system30, analysis; label = key) ≈ analysis.power.generator.active[value]
    end
end