system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "Newton-Raphson Method" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/newtonRaphson")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/newtonRaphson")

    ################ Modified IEEE 14-bus Test Case ################
    acModel!(system14)
    analysis = newtonRaphson(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, analysis)
    end
    power!(system14, analysis)
    current!(system14, analysis)

    power = analysis.power
    voltage = analysis.voltage
    current = analysis.current

    ####### Compare Voltages and Powers #######
    @test voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test voltage.angle ≈ matpower14["voltageAngle"]
    @test power.injection.active ≈ matpower14["injectionActive"]
    @test power.injection.reactive ≈ matpower14["injectionReactive"]
    @test power.supply.active ≈ matpower14["supplyActive"]
    @test power.supply.reactive ≈ matpower14["supplyReactive"]
    @test power.shunt.active ≈ matpower14["shuntActive"]
    @test power.shunt.reactive ≈ matpower14["shuntReactive"]
    @test power.from.active ≈ matpower14["fromActive"]
    @test power.from.reactive ≈ matpower14["fromReactive"]
    @test power.to.active ≈ matpower14["toActive"]
    @test power.to.reactive ≈ matpower14["toReactive"]
    @test power.charging.reactive ≈ matpower14["chargingFrom"] + matpower14["chargingTo"]
    @test power.series.active ≈ matpower14["lossActive"]
    @test power.series.reactive ≈ matpower14["lossReactive"]
    @test power.generator.active ≈ matpower14["generatorActive"]
    @test power.generator.reactive ≈ matpower14["generatorReactive"]

    ####### Compare Currents #######
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

    ####### Compare Bus Powers and Currents #######
    for (key, value) in system14.bus.label
        active, reactive = injectionPower(system14, analysis; label = key)
        @test active ≈ power.injection.active[value]
        @test reactive ≈ power.injection.reactive[value]

        active, reactive = supplyPower(system14, analysis; label = key)
        @test active ≈ power.supply.active[value]
        @test reactive ≈ power.supply.reactive[value]

        active, reactive = shuntPower(system14, analysis; label = key)
        @test active ≈ power.shunt.active[value]
        @test reactive ≈ power.shunt.reactive[value]

        magnitude, angle = injectionCurrent(system14, analysis; label = key)
        @test magnitude ≈ current.injection.magnitude[value]
        @test angle ≈ current.injection.angle[value]
    end

    ####### Compare Branch Powers and Currents #######
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

    ####### Compare Generator Powers #######
    for (key, value) in system14.generator.label
        active, reactive = generatorPower(system14, analysis; label = key)
        @test active ≈ power.generator.active[value]
        @test reactive ≈ power.generator.reactive[value]
    end

    ################ Modified IEEE 30-bus Test Case ################
    acModel!(system30)
    analysis = newtonRaphson(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
    end
    power!(system30, analysis)
    current!(system30, analysis)

    power = analysis.power
    voltage = analysis.voltage
    current = analysis.current

    ####### Compare Voltages and Powers #######
    @test voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test voltage.angle ≈ matpower30["voltageAngle"]
    @test power.injection.active ≈ matpower30["injectionActive"]
    @test power.injection.reactive ≈ matpower30["injectionReactive"]
    @test power.supply.active ≈ matpower30["supplyActive"]
    @test power.supply.reactive ≈ matpower30["supplyReactive"]
    @test power.shunt.active ≈ matpower30["shuntActive"]
    @test power.shunt.reactive ≈ matpower30["shuntReactive"]
    @test power.from.active ≈ matpower30["fromActive"]
    @test power.from.reactive ≈ matpower30["fromReactive"]
    @test power.to.active ≈ matpower30["toActive"]
    @test power.to.reactive ≈ matpower30["toReactive"]
    @test power.charging.reactive ≈ matpower30["chargingFrom"] + matpower30["chargingTo"]
    @test power.series.active ≈ matpower30["lossActive"]
    @test power.series.reactive ≈ matpower30["lossReactive"]
    @test power.generator.active ≈ matpower30["generatorActive"]
    @test power.generator.reactive ≈ matpower30["generatorReactive"]

    ####### Compare Currents #######
    to = system30.branch.layout.to
    from = system30.branch.layout.from

    Si = (complex.(power.injection.active, power.injection.reactive))
    Vi = voltage.magnitude .* exp.(im * voltage.angle)
    @test current.injection.magnitude .* exp.(-im * current.injection.angle) ≈ Si ./ Vi

    Sij = (complex.(power.from.active, power.from.reactive))
    Vi = voltage.magnitude[from] .* exp.(im * voltage.angle[from])
    @test current.from.magnitude .* exp.(-im * current.from.angle) ≈ Sij ./ Vi

    Sji = (complex.(power.to.active, power.to.reactive))
    Vj = (voltage.magnitude[to] .* exp.(im * voltage.angle[to]))
    @test current.to.magnitude .* exp.(-im * current.to.angle) ≈ Sji ./ Vj

    ratio = (1 ./ system30.branch.parameter.turnsRatio) .* exp.(-im * system30.branch.parameter.shiftAngle)
    Sijb = complex.(power.series.active, power.series.reactive)
    @test current.series.magnitude .* exp.(-im * current.series.angle) ≈ Sijb ./ (ratio .* Vi - Vj)

    ####### Compare Bus Powers and Currents #######
    for (key, value) in system30.bus.label
        active, reactive = injectionPower(system30, analysis; label = key)
        @test active ≈ power.injection.active[value]
        @test reactive ≈ power.injection.reactive[value]

        active, reactive = supplyPower(system30, analysis; label = key)
        @test active ≈ power.supply.active[value]
        @test reactive ≈ power.supply.reactive[value]

        active, reactive = shuntPower(system30, analysis; label = key)
        @test active ≈ power.shunt.active[value]
        @test reactive ≈ power.shunt.reactive[value]

        magnitude, angle = injectionCurrent(system30, analysis; label = key)
        @test magnitude ≈ current.injection.magnitude[value]
        @test angle ≈ current.injection.angle[value]
    end

    ####### Compare Branch Powers and Currents #######
    for (key, value) in system30.branch.label
        active, reactive = fromPower(system30, analysis; label = key)
        @test active ≈ power.from.active[value]
        @test reactive ≈ power.from.reactive[value]

        active, reactive = toPower(system30, analysis; label = key)
        @test active ≈ power.to.active[value]
        @test reactive ≈ power.to.reactive[value]

        active, reactive = chargingPower(system30, analysis; label = key)
        @test active ≈ power.charging.active[value]
        @test reactive ≈ power.charging.reactive[value]

        active, reactive = seriesPower(system30, analysis; label = key)
        @test active ≈ power.series.active[value]
        @test reactive ≈ power.series.reactive[value]

        magnitude, angle = fromCurrent(system30, analysis; label = key)
        @test magnitude ≈ current.from.magnitude[value]
        @test angle ≈ current.from.angle[value]

        magnitude, angle = toCurrent(system30, analysis; label = key)
        @test magnitude ≈ current.to.magnitude[value]
        @test angle ≈ current.to.angle[value]

        magnitude, angle = seriesCurrent(system30, analysis; label = key)
        @test magnitude ≈ current.series.magnitude[value]
        @test angle ≈ current.series.angle[value]
    end
    
    ####### Compare Currents #######
    for (key, value) in system30.generator.label
        active, reactive = generatorPower(system30, analysis; label = key)
        @test active ≈ power.generator.active[value]
        @test reactive ≈ power.generator.reactive[value]
    end
end


@testset "Fast Newton-Raphson BX Method" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/fastNewtonRaphsonBX")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/fastNewtonRaphsonBX")

    ################ Modified IEEE 14-bus Test Case ################
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

    ####### Compare Voltages and Iterations #######
    @test analysis.voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower14["voltageAngle"]
    @test iteration == matpower14["iteration"][1]

    ################ Modified IEEE 30-bus Test Case ################
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

    ####### Compare Voltages and Iterations #######
    @test analysis.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower30["voltageAngle"]
    @test iteration == matpower30["iteration"][1]
end

@testset "Fast Newton-Raphson XB Method" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/fastNewtonRaphsonXB")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/fastNewtonRaphsonXB")

    ################ Modified IEEE 14-bus Test Case ################
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

    ####### Compare Voltages and Iterations #######
    @test analysis.voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower14["voltageAngle"]
    @test iteration == matpower14["iteration"][1]

    ################ Modified IEEE 30-bus Test Case ################
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

    ####### Compare Voltages and Iterations #######
    @test analysis.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower30["voltageAngle"]
    @test iteration == matpower30["iteration"][1]
end

@testset "Gauss-Seidel Method" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/gaussSeidel")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/gaussSeidel")

    ################ Modified IEEE 14-bus Test Case ################
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

    ####### Compare Voltages and Iterations #######
    @test analysis.voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower14["voltageAngle"]
    @test iteration == matpower14["iteration"][1]

    ################ Modified IEEE 30-bus Test Case ################
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

    ####### Compare Voltages and Iterations #######
    @test analysis.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower30["voltageAngle"]
    @test iteration == matpower30["iteration"][1]
end

@testset "Compare AC Methods" begin
    system14.branch.parameter.conductance[14] = 0.052
    system14.branch.parameter.conductance[7] = 0.083
    system14.branch.parameter.conductance[1] = 0.58

    ################ Modified IEEE 14-bus Test Case ################
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

    ####### Compare Voltages #######
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

    ################ Modified IEEE 14-bus Test Case ################
    dcModel!(system14)
    analysis = dcPowerFlow(system14)
    solve!(system14, analysis)
    power!(system14, analysis)

    ####### Compare Voltages and Powers #######
    @test analysis.voltage.angle ≈ matpower14["voltage"]
    @test analysis.power.injection.active ≈ matpower14["injection"]
    @test analysis.power.supply.active ≈ matpower14["supply"]
    @test analysis.power.from.active ≈ matpower14["from"]
    @test analysis.power.to.active ≈ -matpower14["from"]
    @test analysis.power.generator.active ≈ matpower14["generator"]

    ####### Compare Bus Powers #######
    for (key, value) in system14.bus.label
        @test injectionPower(system14, analysis; label = key) ≈ matpower14["injection"][value] atol = 1e-14
        @test supplyPower(system14, analysis; label = key) ≈ matpower14["supply"][value] atol = 1e-14
    end

    ####### Compare Branch Powers #######
    for (key, value) in system14.branch.label
        @test fromPower(system14, analysis; label = key) ≈ matpower14["from"][value] atol = 1e-14
        @test toPower(system14, analysis; label = key) ≈ -matpower14["from"][value] atol = 1e-14
    end

    ####### Compare Generator Powers #######
    for (key, value) in system14.generator.label
        @test generatorPower(system14, analysis; label = key) ≈ matpower14["generator"][value] atol = 1e-14
    end

    ################ Modified IEEE 30-bus Test Case ################
    dcModel!(system30)
    analysis = dcPowerFlow(system30)
    solve!(system30, analysis)
    power!(system30, analysis)

    ####### Compare Bus Powers and Currents #######
    @test analysis.voltage.angle ≈ matpower30["voltage"]
    @test analysis.power.injection.active ≈ matpower30["injection"]
    @test analysis.power.supply.active ≈ matpower30["supply"]
    @test analysis.power.from.active ≈ matpower30["from"]
    @test analysis.power.to.active ≈ -matpower30["from"]
    @test analysis.power.generator.active ≈ matpower30["generator"]

    ####### Compare Bus Powers #######
    for (key, value) in system30.bus.label
        @test injectionPower(system30, analysis; label = key) ≈ matpower30["injection"][value] atol = 1e-14
        @test supplyPower(system30, analysis; label = key) ≈ matpower30["supply"][value] atol = 1e-14
    end

    ####### Compare Branch Powers #######
    for (key, value) in system30.branch.label
        @test fromPower(system30, analysis; label = key) ≈ matpower30["from"][value] atol = 1e-14
        @test toPower(system30, analysis; label = key) ≈ -matpower30["from"][value] atol = 1e-14
    end

    ####### Compare Generator Powers #######
    for (key, value) in system30.generator.label
        @test generatorPower(system30, analysis; label = key) ≈ matpower30["generator"][value] atol = 1e-14
    end
end