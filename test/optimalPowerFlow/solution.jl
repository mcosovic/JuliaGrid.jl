system14 = powerSystem(string(pathData, "case14optimal.m"))

@testset "AC Optimal Power Flow" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14optimal/acOptimalPowerFlow")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
    solve!(system14, analysis)
    power!(system14, analysis)
    current!(system14, analysis)

    power = analysis.power
    voltage = analysis.voltage
    current = analysis.current

    @test voltage.magnitude ≈ matpower14["voltageMagnitude"] atol = 1e-6
    @test voltage.angle ≈ matpower14["voltageAngle"] atol = 1e-6
    @test power.injection.active ≈ matpower14["injectionActive"] atol = 1e-6
    @test power.injection.reactive ≈ matpower14["injectionReactive"] atol = 1e-6
    @test power.supply.active ≈ matpower14["supplyActive"] atol = 1e-6
    @test power.supply.reactive ≈ matpower14["supplyReactive"] atol = 1e-6
    @test power.shunt.active ≈ matpower14["shuntActive"] atol = 1e-6
    @test power.shunt.reactive ≈ matpower14["shuntReactive"] atol = 1e-6
    @test power.from.active ≈ matpower14["fromActive"] atol = 1e-6
    @test power.from.reactive ≈ matpower14["fromReactive"] atol = 1e-6
    @test power.to.active ≈ matpower14["toActive"] atol = 1e-6
    @test power.to.reactive ≈ matpower14["toReactive"] atol = 1e-6
    @test power.charging.reactive ≈ matpower14["chargingFrom"] + matpower14["chargingTo"] atol = 1e-6
    @test power.series.active ≈ matpower14["lossActive"] atol = 1e-6
    @test power.series.reactive ≈ matpower14["lossReactive"] atol = 1e-6
    @test power.generator.active ≈ matpower14["generatorActive"] atol = 1e-6
    @test power.generator.reactive ≈ matpower14["generatorReactive"] atol = 1e-6

    to = system14.branch.layout.to
    from = system14.branch.layout.from

    Si = (complex.(power.injection.active, power.injection.reactive))
    Vi = voltage.magnitude .* exp.(im * voltage.angle)
    @test current.injection.magnitude .* exp.(-im * current.injection.angle) ≈ Si ./ Vi

    Sij = (complex.(power.from.active, power.from.reactive))
    Vi = voltage.magnitude[from] .* exp.(im * voltage.angle[from])
    @test current.from.magnitude .* exp.(-im * current.from.angle) ≈ Sij ./ Vi

    Sji = (complex.(power.to.active, power.to.reactive))
    Vj = (voltage.magnitude[to] .* exp.(im * voltage.angle[to]))
    @test current.to.magnitude .* exp.(-im * current.to.angle) ≈ Sji ./ Vj

    ratio = (1 ./ system14.branch.parameter.turnsRatio) .* exp.(-im * system14.branch.parameter.shiftAngle)
    Sijb = complex.(power.series.active, power.series.reactive)
    @test current.series.magnitude .* exp.(-im * current.series.angle) ≈ Sijb ./ (ratio .* Vi - Vj)

    for (key, value) in system14.bus.label
        active, reactive = injectionPower(system14, analysis; label = key)
        @test active ≈ power.injection.active[value]
        @test reactive ≈ power.injection.reactive[value]

        active, reactive = supplyPower(system14, analysis; label = key)
        @test active ≈ power.supply.active[value]
        @test reactive ≈ power.supply.reactive[value]

        active, reactive = shuntPower(system14, analysis; label = key)
        @test active ≈ power.shunt.active[value] atol = 1e-15
        @test reactive ≈ power.shunt.reactive[value] atol = 1e-15

        magnitude, angle = injectionCurrent(system14, analysis; label = key)
        @test magnitude ≈ current.injection.magnitude[value]
        @test angle ≈ current.injection.angle[value]
    end

    for (key, value) in system14.branch.label
        active, reactive = fromPower(system14, analysis; label = key)
        @test active ≈ power.from.active[value]
        @test reactive ≈ power.from.reactive[value]

        active, reactive = toPower(system14, analysis; label = key)
        @test active ≈ power.to.active[value]
        @test reactive ≈ power.to.reactive[value]

        active, reactive = chargingPower(system14, analysis; label = key)
        @test active ≈ power.charging.active[value]
        @test reactive ≈ power.charging.reactive[value]

        active, reactive = seriesPower(system14, analysis; label = key)
        @test active ≈ power.series.active[value]
        @test reactive ≈ power.series.reactive[value]

        magnitude, angle = fromCurrent(system14, analysis; label = key)
        @test magnitude ≈ current.from.magnitude[value]
        @test angle ≈ current.from.angle[value]

        magnitude, angle = toCurrent(system14, analysis; label = key)
        @test magnitude ≈ current.to.magnitude[value]
        @test angle ≈ current.to.angle[value]

        magnitude, angle = seriesCurrent(system14, analysis; label = key)
        @test magnitude ≈ current.series.magnitude[value]
        @test angle ≈ current.series.angle[value]
    end

    for (key, value) in system14.generator.label
        active, reactive = generatorPower(system14, analysis; label = key)
        @test active ≈ power.generator.active[value]
        @test reactive ≈ power.generator.reactive[value]
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
        @test injectionPower(system14, analysis; label = key) ≈ analysis.power.injection.active[value]
        @test supplyPower(system14, analysis; label = key) ≈ analysis.power.supply.active[value]
    end

    for (key, value) in system14.branch.label
        @test fromPower(system14, analysis; label = key) ≈ analysis.power.from.active[value]
        @test toPower(system14, analysis; label = key) ≈ analysis.power.to.active[value]
    end

    for (key, value) in system14.generator.label
        @test generatorPower(system14, analysis; label = key) ≈ analysis.power.generator.active[value]
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
        @test injectionPower(system30, analysis; label = key) ≈ analysis.power.injection.active[value]
        @test supplyPower(system30, analysis; label = key) ≈ analysis.power.supply.active[value]
    end

    for (key, value) in system30.branch.label
        @test fromPower(system30, analysis; label = key) ≈ analysis.power.from.active[value]
        @test toPower(system30, analysis; label = key) ≈ analysis.power.to.active[value]
    end

    for (key, value) in system30.generator.label
        @test generatorPower(system30, analysis; label = key) ≈ analysis.power.generator.active[value]
    end
end
