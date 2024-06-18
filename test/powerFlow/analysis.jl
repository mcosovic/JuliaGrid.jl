@testset "Newton-Raphson Method" begin
    @default(unit)
    @default(template)

    ################ Modified IEEE 14-bus Test Case ################
    system14 = powerSystem(string(pathData, "case14test.m"))
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/newtonRaphson")

    acModel!(system14)
    analysis = newtonRaphson(system14, QR)
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

    power = analysis.power
    voltage = analysis.voltage
    current = analysis.current

    ####### Test Iteration Number #######
    @test iteration == matpower14["iteration"][1]

    ####### Test Voltages #######
    @test voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test voltage.angle ≈ matpower14["voltageAngle"]

    ####### Test Powers #######
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

    ####### Test Currents #######
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

    ####### Test Specific Bus Powers and Currents #######
    for (key, value) in system14.bus.label
        active, reactive = injectionPower(system14, analysis; label = key)
        @test active ≈ power.injection.active[value] atol = 1e-14
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

    ####### Test Specific Branch Powers and Currents #######
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

    ####### Test Specific Generator Powers #######
    for (key, value) in system14.generator.label
        active, reactive = generatorPower(system14, analysis; label = key)
        @test active ≈ power.generator.active[value]
        @test reactive ≈ power.generator.reactive[value]
    end

    ####### Test Print Data #######
    @capture_out printBusData(system14, analysis)
    @capture_out printBranchData(system14, analysis)
    @capture_out printGeneratorData(system14, analysis)
    @capture_out printBusSummary(system14, analysis)
    @capture_out printBranchSummary(system14, analysis)
    @capture_out printGeneratorSummary(system14, analysis)

    ################ Modified IEEE 30-bus Test Case ################
    system30 = powerSystem(string(pathData, "case30test.m"))
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/newtonRaphson")

    analysis = newtonRaphson(system30)
    startMagnitude = copy(analysis.voltage.magnitude)
    startAngle = copy(analysis.voltage.angle)
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

    power = analysis.power
    voltage = analysis.voltage
    current = analysis.current

    ####### Test Iteration Number #######
    @test iteration == matpower30["iteration"][1]

    ####### Test Voltages #######
    @test voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test voltage.angle ≈ matpower30["voltageAngle"]

    ####### Test Powers #######
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

    ####### Test Currents #######
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

    ####### Test Specific Bus Powers and Currents #######
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

    ####### Test Specific Branch Powers and Currents #######
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

    ####### Test Specific Generator Powers #######
    for (key, value) in system30.generator.label
        active, reactive = generatorPower(system30, analysis; label = key)
        @test active ≈ power.generator.active[value]
        @test reactive ≈ power.generator.reactive[value]
    end

    ####### Test Starting Voltages #######
    startingVoltage!(system30, analysis)
    @test analysis.voltage.magnitude == startMagnitude
    @test analysis.voltage.angle == startAngle

    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
        iteration += 1
    end
    @test iteration == matpower30["iteration"][1]

    ####### Test Slack Bus Changes #######
    updateBus!(system30; label = 1, type = 2)
    updateBus!(system30; label = 3, type = 3)

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

    @test voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test voltage.angle ≈ matpower30["voltageAngle"]
    @test iteration == matpower30["iteration"][1]
end

@testset "Fast Newton-Raphson BX Method" begin
    ################ Modified IEEE 14-bus Test Case ################
    system14 = powerSystem(string(pathData, "case14test.m"))
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/fastNewtonRaphsonBX")

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

    ####### Test Iteration Number #######
    @test iteration == matpower14["iteration"][1]

    ####### Test Voltages #######
    @test analysis.voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower14["voltageAngle"]

    ################ Modified IEEE 30-bus Test Case ################
    system30 = powerSystem(string(pathData, "case30test.m"))
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/fastNewtonRaphsonBX")

    analysis = fastNewtonRaphsonBX(system30, QR)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
        iteration += 1
    end

    ####### Test Iteration Number #######
    @test iteration == matpower30["iteration"][1]

    ####### Test Voltages #######
    @test analysis.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower30["voltageAngle"]

    ####### Test Pattern Changes #######
    updateBranch!(system30, analysis; label = 5, status = 0)
    dropZeros!(system30.model.ac)
    updateBranch!(system30, analysis; label = 5, status = 1)

    startingVoltage!(system30, analysis)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
        iteration += 1
    end

    @test iteration == matpower30["iteration"][1]
    @test analysis.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower30["voltageAngle"]
end

@testset "Fast Newton-Raphson XB Method" begin
    ################ Modified IEEE 14-bus Test Case ################
    system14 = powerSystem(string(pathData, "case14test.m"))
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/fastNewtonRaphsonXB")

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

    ####### Test Iteration Number #######
    @test iteration == matpower14["iteration"][1]

    ####### Test Voltages #######
    @test analysis.voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower14["voltageAngle"]

    ################ Modified IEEE 30-bus Test Case ################
    system30 = powerSystem(string(pathData, "case30test.m"))
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/fastNewtonRaphsonXB")

    analysis = fastNewtonRaphsonXB(system30, QR)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
        iteration += 1
    end

    ####### Test Iteration Number #######
    @test iteration == matpower30["iteration"][1]

    ####### Test Voltages #######
    @test analysis.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower30["voltageAngle"]
end



@testset "Gauss-Seidel Method" begin
    ################ Modified IEEE 14-bus Test Case ################
    system14 = powerSystem(string(pathData, "case14test.m"))
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/gaussSeidel")

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

    ####### Test Iteration Number #######
    @test iteration == matpower14["iteration"][1]

    ####### Test Voltages #######
    @test analysis.voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower14["voltageAngle"]

    ################ Modified IEEE 30-bus Test Case ################
    system30 = powerSystem(string(pathData, "case30test.m"))
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/gaussSeidel")

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

    ####### Test Iteration Number #######
    @test iteration == matpower30["iteration"][1]

    ####### Test Voltages #######
    @test analysis.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test analysis.voltage.angle ≈ matpower30["voltageAngle"]
end

@testset "Compare AC Power Flows Methods" begin
    @default(unit)
    @default(template)

    ################ Modified IEEE 14-bus Test Case ################
    system14 = powerSystem(string(pathData, "case14test.m"))

    updateBranch!(system14; label = 1, conductance = 0.58)
    updateBranch!(system14; label = 7, conductance = 0.083)
    updateBranch!(system14; label = 14, conductance = 0.052)

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

    ####### Test Voltages #######
    @test nr.voltage.magnitude ≈ fnrBX.voltage.magnitude
    @test nr.voltage.angle ≈ fnrBX.voltage.angle
    @test nr.voltage.magnitude ≈ fnrXB.voltage.magnitude
    @test nr.voltage.angle ≈ fnrXB.voltage.angle
    @test nr.voltage.magnitude ≈ gs.voltage.magnitude
    @test nr.voltage.angle ≈ gs.voltage.angle

    ################ Modified IEEE 30-bus Test Case ################
    system30 = powerSystem(string(pathData, "case30test.m"))

    updateBranch!(system30; label = 2, conductance = 0.01)
    updateBranch!(system30; label = 5, conductance = 1e-4)
    updateBranch!(system30; label = 18, conductance = 0.5)

    acModel!(system30)
    nr = newtonRaphson(system30)
    for i = 1:1000
        stopping = mismatch!(system30, nr)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, nr)
    end

    fnrBX = fastNewtonRaphsonBX(system30)
    for i = 1:1000
        stopping = mismatch!(system30, fnrBX)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, fnrBX)
    end

    fnrXB = fastNewtonRaphsonXB(system30)
    for i = 1:1000
        stopping = mismatch!(system30, fnrXB)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, fnrXB)
    end

    gs = gaussSeidel(system30)
    for i = 1:3000
        stopping = mismatch!(system30, gs)
        if all(stopping .< 1e-9)
            break
        end
        solve!(system30, gs)
    end

    ####### Test Voltages #######
    @test nr.voltage.magnitude ≈ fnrBX.voltage.magnitude
    @test nr.voltage.angle ≈ fnrBX.voltage.angle
    @test nr.voltage.magnitude ≈ fnrXB.voltage.magnitude
    @test nr.voltage.angle ≈ fnrXB.voltage.angle
    @test nr.voltage.magnitude ≈ gs.voltage.magnitude
    @test nr.voltage.angle ≈ gs.voltage.angle
end

@testset "DC Power Flow" begin
    ################ Modified IEEE 14-bus Test Case ################
    system14 = powerSystem(string(pathData, "case14test.m"))
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/dcPowerFlow")

    dcModel!(system14)
    analysis = dcPowerFlow(system14)
    solve!(system14, analysis)
    power!(system14, analysis)

    ####### Test Voltage Angles #######
    @test analysis.voltage.angle ≈ matpower14["voltage"]

    ####### Test Active Powers #######
    @test analysis.power.injection.active ≈ matpower14["injection"]
    @test analysis.power.supply.active ≈ matpower14["supply"]
    @test analysis.power.from.active ≈ matpower14["from"]
    @test analysis.power.to.active ≈ -matpower14["from"]
    @test analysis.power.generator.active ≈ matpower14["generator"]

    ####### Test Specific Bus Active Powers #######
    for (key, value) in system14.bus.label
        @test injectionPower(system14, analysis; label = key) ≈ matpower14["injection"][value] atol = 1e-14
        @test supplyPower(system14, analysis; label = key) ≈ matpower14["supply"][value] atol = 1e-14
    end

    ####### Test Specific Branch Active Powers #######
    for (key, value) in system14.branch.label
        @test fromPower(system14, analysis; label = key) ≈ matpower14["from"][value] atol = 1e-14
        @test toPower(system14, analysis; label = key) ≈ -matpower14["from"][value] atol = 1e-14
    end

    ####### Test Specific Generator Active Powers #######
    for (key, value) in system14.generator.label
        @test generatorPower(system14, analysis; label = key) ≈ matpower14["generator"][value] atol = 1e-14
    end

    ####### Test Print Data #######
    @capture_out printBusData(system14, analysis)
    @capture_out printBranchData(system14, analysis)
    @capture_out printGeneratorData(system14, analysis)
    @capture_out printBusSummary(system14, analysis)
    @capture_out printBranchSummary(system14, analysis)
    @capture_out printGeneratorSummary(system14, analysis)

    ################ Modified IEEE 30-bus Test Case ################
    system30 = powerSystem(string(pathData, "case30test.m"))
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/dcPowerFlow")

    analysis = dcPowerFlow(system30, LDLt)
    solve!(system30, analysis)
    power!(system30, analysis)

    ####### Test Voltage Angles #######
    @test analysis.voltage.angle ≈ matpower30["voltage"]

    ####### Test Active Powers #######
    @test analysis.power.injection.active ≈ matpower30["injection"]
    @test analysis.power.supply.active ≈ matpower30["supply"]
    @test analysis.power.from.active ≈ matpower30["from"]
    @test analysis.power.to.active ≈ -matpower30["from"]
    @test analysis.power.generator.active ≈ matpower30["generator"]

    ####### Test Specific Bus Active Powers #######
    for (key, value) in system30.bus.label
        @test injectionPower(system30, analysis; label = key) ≈ matpower30["injection"][value] atol = 1e-14
        @test supplyPower(system30, analysis; label = key) ≈ matpower30["supply"][value] atol = 1e-14
    end

    ####### Test Specific Branch Active Powers #######
    for (key, value) in system30.branch.label
        @test fromPower(system30, analysis; label = key) ≈ matpower30["from"][value] atol = 1e-14
        @test toPower(system30, analysis; label = key) ≈ -matpower30["from"][value] atol = 1e-14
    end

    ####### Test Specific Generator Active Powers #######
    for (key, value) in system30.generator.label
        @test generatorPower(system30, analysis; label = key) ≈ matpower30["generator"][value] atol = 1e-14
    end
end

