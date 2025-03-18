function testCurrent(system::PowerSystem, analysis::AC)
    power = analysis.power
    voltage = analysis.voltage
    current = analysis.current
    branch = system.branch
    to = branch.layout.to
    from = branch.layout.from

    Si = complex.(power.injection.active, power.injection.reactive)
    Vi = voltage.magnitude .* cis.(voltage.angle)
    @test current.injection.magnitude .* cis.(-current.injection.angle) ≈ Si ./ Vi

    Sij = complex.(power.from.active, power.from.reactive)
    Vi = voltage.magnitude[from] .* cis.(voltage.angle[from])
    @test current.from.magnitude .* cis.(-current.from.angle) ≈ Sij ./ Vi

    Sji = complex.(power.to.active, power.to.reactive)
    Vj = voltage.magnitude[to] .* cis.(voltage.angle[to])
    @test current.to.magnitude .* cis.(-current.to.angle) ≈ Sji ./ Vj

    ratio = (1 ./ branch.parameter.turnsRatio) .* cis.(-branch.parameter.shiftAngle)
    Sijb = complex.(power.series.active, power.series.reactive)
    @test current.series.magnitude .* cis.(-current.series.angle) ≈ Sijb ./ (ratio .* Vi - Vj)
end

function testBus(system::PowerSystem, analysis::AC)
    for (key, value) in system.bus.label
        active, reactive = injectionPower(system, analysis; label = key)
        @test active ≈ analysis.power.injection.active[value] atol = 1e-14
        @test reactive ≈ analysis.power.injection.reactive[value]

        active, reactive = supplyPower(system, analysis; label = key)
        @test active ≈ analysis.power.supply.active[value]
        @test reactive ≈ analysis.power.supply.reactive[value]

        active, reactive = shuntPower(system, analysis; label = key)
        @test active ≈ analysis.power.shunt.active[value]
        @test reactive ≈ analysis.power.shunt.reactive[value]

        magnitude, angle = injectionCurrent(system, analysis; label = key)
        @test magnitude ≈ analysis.current.injection.magnitude[value]
        @test angle ≈ analysis.current.injection.angle[value]
    end
end

function testBus(system::PowerSystem, analysis::DC)
    for (key, value) in system.bus.label
        injection = injectionPower(system, analysis; label = key)
        supply = supplyPower(system, analysis; label = key)

        @test injection ≈ analysis.power.injection.active[value]
        @test supply ≈ analysis.power.supply.active[value]
    end
end

function testBranch(system::PowerSystem, analysis::AC)
    for (key, value) in system.branch.label
        active, reactive = fromPower(system, analysis; label = key)
        @test active ≈ analysis.power.from.active[value]
        @test reactive ≈ analysis.power.from.reactive[value]

        active, reactive = toPower(system, analysis; label = key)
        @test active ≈ analysis.power.to.active[value]
        @test reactive ≈ analysis.power.to.reactive[value]

        active, reactive = chargingPower(system, analysis; label = key)
        @test active ≈ analysis.power.charging.active[value]
        @test reactive ≈ analysis.power.charging.reactive[value]

        active, reactive = seriesPower(system, analysis; label = key)
        @test active ≈ analysis.power.series.active[value]
        @test reactive ≈ analysis.power.series.reactive[value]

        magnitude, angle = fromCurrent(system, analysis; label = key)
        @test magnitude ≈ analysis.current.from.magnitude[value]
        @test angle ≈ analysis.current.from.angle[value]

        magnitude, angle = toCurrent(system, analysis; label = key)
        @test magnitude ≈ analysis.current.to.magnitude[value]
        @test angle ≈ analysis.current.to.angle[value]

        magnitude, angle = seriesCurrent(system, analysis; label = key)
        @test magnitude ≈ analysis.current.series.magnitude[value]
        @test angle ≈ analysis.current.series.angle[value]
    end
end

function testBranch(system::PowerSystem, analysis::DC)
    for (key, value) in system.branch.label
        from = fromPower(system, analysis; label = key)
        to = toPower(system, analysis; label = key)

        @test from ≈ analysis.power.from.active[value]
        @test to ≈ analysis.power.to.active[value]
    end
end

function testGenerator(system::PowerSystem, analysis::AC)
    for (key, value) in system.generator.label
        active, reactive = generatorPower(system, analysis; label = key)
        @test active ≈ analysis.power.generator.active[value]
        @test reactive ≈ analysis.power.generator.reactive[value]
    end
end

function testGenerator(system::PowerSystem, analysis::DC)
    for (key, value) in system.generator.label
        generator = generatorPower(system, analysis; label = key)
        @test generator ≈ analysis.power.generator.active[value]
    end
end

function testVoltageMatpower(matpower::Dict{String, Any}, analysis::AC; atol = 0)
    if haskey(matpower, "iteration")
        @test analysis.method.iteration == matpower["iteration"][1]
    end
    @test analysis.voltage.magnitude ≈ matpower["voltageMagnitude"] atol = atol
    @test analysis.voltage.angle ≈ matpower["voltageAngle"] atol = atol
end

function testGeneratorMatpower(matpower::Dict{String, Any}, analysis::AC; atol = 0)
    @test analysis.power.generator.active ≈ matpower["generatorActive"] atol = atol
    @test analysis.power.generator.reactive ≈ matpower["generatorReactive"] atol = atol
end

function testPowerMatpower(matpower::Dict{String, Any}, analysis::AC; atol = 0)
    @test analysis.power.injection.active ≈ matpower["injectionActive"] atol = atol
    @test analysis.power.injection.reactive ≈ matpower["injectionReactive"] atol = atol
    @test analysis.power.supply.active ≈ matpower["supplyActive"] atol = atol
    @test analysis.power.supply.reactive ≈ matpower["supplyReactive"] atol = atol
    @test analysis.power.shunt.active ≈ matpower["shuntActive"] atol = atol
    @test analysis.power.shunt.reactive ≈ matpower["shuntReactive"] atol = atol
    @test analysis.power.from.active ≈ matpower["fromActive"] atol = atol
    @test analysis.power.from.reactive ≈ matpower["fromReactive"] atol = atol
    @test analysis.power.to.active ≈ matpower["toActive"] atol = atol
    @test analysis.power.to.reactive ≈ matpower["toReactive"] atol = atol
    @test analysis.power.charging.reactive ≈ matpower["chargingFrom"] + matpower["chargingTo"] atol = atol
    @test analysis.power.series.active ≈ matpower["lossActive"] atol = atol
    @test analysis.power.series.reactive ≈ matpower["lossReactive"] atol = atol
    @test analysis.power.generator.active ≈ matpower["generatorActive"] atol = atol
    @test analysis.power.generator.reactive ≈ matpower["generatorReactive"] atol = atol
end

function testPowerMatpower(matpower::Dict{String, Any}, analysis::DC; atol = 0)
    @test analysis.power.injection.active ≈ matpower["injection"] atol = atol
    @test analysis.power.supply.active ≈ matpower["supply"] atol = atol
    @test analysis.power.from.active ≈ matpower["from"] atol = atol
    @test analysis.power.to.active ≈ -matpower["from"] atol = atol
    @test analysis.power.generator.active ≈ matpower["generator"] atol = atol
end

function testDevice(meter::GaussMeter, fully::GaussMeter, idx::Int64, status::Int64)
    @test meter.mean[end] ≈ fully.mean[idx] atol = 1e-14
    @test meter.status[end] == status
end

function testEstimation(system::PowerSystem, device::Measurement, analysis::ACPowerFlow; warm = false)
    gn = gaussNewton(system, device)
    if warm
       setInitialPoint!(analysis, gn)
    end
    stateEstimation!(system, gn; iteration = 200, tolerance = 1e-12)
    compstruct(gn.voltage, analysis.voltage; atol = 1e-10)

    lav = acLavStateEstimation(system, device, Ipopt.Optimizer)
    solve!(system, lav)
    compstruct(lav.voltage, analysis.voltage; atol = 1e-8)
end

function testPmuEstimation(system::PowerSystem, device::Measurement, analysis::ACPowerFlow)
    pmu = pmuStateEstimation(system, device)
    stateEstimation!(system, pmu)
    compstruct(pmu.voltage, analysis.voltage; atol = 1e-10)

    lav = pmuLavStateEstimation(system, device, Ipopt.Optimizer)
    solve!(system, lav)
    compstruct(lav.voltage, analysis.voltage; atol = 1e-8)
end

function testDCEstimation(system::PowerSystem, device::Measurement, analysis::DCPowerFlow)
    dc = dcStateEstimation(system, device)
    stateEstimation!(system, dc)
    @test dc.voltage.angle ≈ analysis.voltage.angle

    lav = dcLavStateEstimation(system, device, Ipopt.Optimizer)
    solve!(system, lav)
    @test lav.voltage.angle ≈ analysis.voltage.angle
end

function addPmuBus(system::PowerSystem, device::Measurement, analysis::ACPowerFlow)
    for (key, idx) in system.bus.label
        addPmu!(
            system, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], polar = true
        )
    end
end