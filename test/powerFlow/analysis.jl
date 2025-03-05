@testset "Newton-Raphson Method" begin
    @default(unit)
    @default(template)

    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")
    matpwr14 = h5read(path * "results.h5", "case14test/newtonRaphson")

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
    branch = system14.branch
    to = branch.layout.to
    from = branch.layout.from

    @testset "IEEE 14: Iteration Number and Voltages" begin
        @test iteration == matpwr14["iteration"][1]
        @test voltage.magnitude ≈ matpwr14["voltageMagnitude"]
        @test voltage.angle ≈ matpwr14["voltageAngle"]
    end

    @testset "IEEE 14: Powers" begin
        @test power.injection.active ≈ matpwr14["injectionActive"]
        @test power.injection.reactive ≈ matpwr14["injectionReactive"]
        @test power.supply.active ≈ matpwr14["supplyActive"]
        @test power.supply.reactive ≈ matpwr14["supplyReactive"]
        @test power.shunt.active ≈ matpwr14["shuntActive"]
        @test power.shunt.reactive ≈ matpwr14["shuntReactive"]
        @test power.from.active ≈ matpwr14["fromActive"]
        @test power.from.reactive ≈ matpwr14["fromReactive"]
        @test power.to.active ≈ matpwr14["toActive"]
        @test power.to.reactive ≈ matpwr14["toReactive"]
        @test power.charging.reactive ≈ matpwr14["chargingFrom"] + matpwr14["chargingTo"]
        @test power.series.active ≈ matpwr14["lossActive"]
        @test power.series.reactive ≈ matpwr14["lossReactive"]
        @test power.generator.active ≈ matpwr14["generatorActive"]
        @test power.generator.reactive ≈ matpwr14["generatorReactive"]
    end

    @testset "IEEE 14: Currents" begin
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

    @testset "IEEE 14: Specific Bus Powers and Currents" begin
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
    end

    @testset "IEEE 14: Specific Branch Powers and Currents" begin
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
    end

    @testset "IEEE 14: Specific Generator Powers" begin
        for (key, value) in system14.generator.label
            active, reactive = generatorPower(system14, analysis; label = key)
            @test active ≈ power.generator.active[value]
            @test reactive ≈ power.generator.reactive[value]
        end
    end

    @testset "IEEE 14: Wrapper Function" begin
        analysis = newtonRaphson(system14)
        acPowerFlow!(system14, analysis)
        @test analysis.voltage.magnitude ≈ matpwr14["voltageMagnitude"]
        @test analysis.voltage.angle ≈ matpwr14["voltageAngle"]
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")
    matpwr30 = h5read(path * "results.h5", "case30test/newtonRaphson")

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
    branch = system30.branch
    to = branch.layout.to
    from = branch.layout.from

    @testset "IEEE 30: Iteration Number and Voltages" begin
        @test iteration == matpwr30["iteration"][1]
        @test voltage.magnitude ≈ matpwr30["voltageMagnitude"]
        @test voltage.angle ≈ matpwr30["voltageAngle"]
    end

    @testset "IEEE 30: Powers" begin
        @test power.injection.active ≈ matpwr30["injectionActive"]
        @test power.injection.reactive ≈ matpwr30["injectionReactive"]
        @test power.supply.active ≈ matpwr30["supplyActive"]
        @test power.supply.reactive ≈ matpwr30["supplyReactive"]
        @test power.shunt.active ≈ matpwr30["shuntActive"]
        @test power.shunt.reactive ≈ matpwr30["shuntReactive"]
        @test power.from.active ≈ matpwr30["fromActive"]
        @test power.from.reactive ≈ matpwr30["fromReactive"]
        @test power.to.active ≈ matpwr30["toActive"]
        @test power.to.reactive ≈ matpwr30["toReactive"]
        @test power.charging.reactive ≈ matpwr30["chargingFrom"] + matpwr30["chargingTo"]
        @test power.series.active ≈ matpwr30["lossActive"]
        @test power.series.reactive ≈ matpwr30["lossReactive"]
        @test power.generator.active ≈ matpwr30["generatorActive"]
        @test power.generator.reactive ≈ matpwr30["generatorReactive"]
    end

    @testset "IEEE 30: Currents" begin
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

    @testset "IEEE 30: Specific Bus Powers and Currents" begin
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
    end

    @testset "IEEE 30: Specific Branch Powers and Currents" begin
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
    end

    @testset "IEEE 30: Specific Generator Powers" begin
        for (key, value) in system30.generator.label
            active, reactive = generatorPower(system30, analysis; label = key)
            @test active ≈ power.generator.active[value]
            @test reactive ≈ power.generator.reactive[value]
        end
    end

    @testset "IEEE 30: Starting Voltages" begin
        setInitialPoint!(system30, analysis)
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
        @test iteration == matpwr30["iteration"][1]
    end

    @testset "IEEE 30: Change of the Slack Bus" begin
        updateBus!(system30; label = 1, type = 2)
        updateBus!(system30; label = 3, type = 3)

        @suppress analysis = newtonRaphson(system30)
        iteration = 0
        for i = 1:1000
            stopping = mismatch!(system30, analysis)
            if all(stopping .< 1e-8)
                break
            end
            solve!(system30, analysis)
            iteration += 1
        end

        @test voltage.magnitude ≈ matpwr30["voltageMagnitude"]
        @test voltage.angle ≈ matpwr30["voltageAngle"]
        @test iteration == matpwr30["iteration"][1]
    end
end

@testset "Fast Newton-Raphson BX Method" begin
    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")
    matpwr14 = h5read(path * "results.h5", "case14test/fastNewtonRaphsonBX")

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

    @testset "IEEE 14: Iteration Number and Voltages" begin
        @test iteration == matpwr14["iteration"][1]
        @test analysis.voltage.magnitude ≈ matpwr14["voltageMagnitude"]
        @test analysis.voltage.angle ≈ matpwr14["voltageAngle"]
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")
    matpwr30 = h5read(path * "results.h5", "case30test/fastNewtonRaphsonBX")

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

    @testset "IEEE 30: Iteration Number and Voltages" begin
        @test iteration == matpwr30["iteration"][1]
        @test analysis.voltage.magnitude ≈ matpwr30["voltageMagnitude"]
        @test analysis.voltage.angle ≈ matpwr30["voltageAngle"]
    end

    @testset "IEEE 30: Change of the Jacobian Pattern" begin
        updateBranch!(system30, analysis; label = 5, status = 0)
        dropZeros!(system30.model.ac)
        updateBranch!(system30, analysis; label = 5, status = 1)

        setInitialPoint!(system30, analysis)
        iteration = 0
        for i = 1:1000
            stopping = mismatch!(system30, analysis)
            if all(stopping .< 1e-8)
                break
            end
            solve!(system30, analysis)
            iteration += 1
        end

        @test iteration == matpwr30["iteration"][1]
        @test analysis.voltage.magnitude ≈ matpwr30["voltageMagnitude"]
        @test analysis.voltage.angle ≈ matpwr30["voltageAngle"]
    end
end

@testset "Fast Newton-Raphson XB Method" begin
    @config(label = Integer)

    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")
    matpwr14 = h5read(path * "results.h5", "case14test/fastNewtonRaphsonXB")

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

    @testset "IEEE 14: Iteration Number and Voltages" begin
        @test iteration == matpwr14["iteration"][1]
        @test analysis.voltage.magnitude ≈ matpwr14["voltageMagnitude"]
        @test analysis.voltage.angle ≈ matpwr14["voltageAngle"]
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")
    matpwr30 = h5read(path * "results.h5", "case30test/fastNewtonRaphsonXB")

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

    @testset "IEEE 30: Iteration Number and Voltages" begin
        @test iteration == matpwr30["iteration"][1]
        @test analysis.voltage.magnitude ≈ matpwr30["voltageMagnitude"]
        @test analysis.voltage.angle ≈ matpwr30["voltageAngle"]
    end
end

@testset "Gauss-Seidel Method" begin
    @default(template)

    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")
    matpwr14 = h5read(path * "results.h5", "case14test/gaussSeidel")

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

    @testset "IEEE 14: Iteration Number and Voltages" begin
        @test iteration == matpwr14["iteration"][1]
        @test analysis.voltage.magnitude ≈ matpwr14["voltageMagnitude"]
        @test analysis.voltage.angle ≈ matpwr14["voltageAngle"]
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")
    matpwr30 = h5read(path * "results.h5", "case30test/gaussSeidel")

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

    @testset "IEEE 30: Iteration Number and Voltages" begin
        @test iteration == matpwr30["iteration"][1]
        @test analysis.voltage.magnitude ≈ matpwr30["voltageMagnitude"]
        @test analysis.voltage.angle ≈ matpwr30["voltageAngle"]
    end
end

@testset "Compare AC Power Flows Methods" begin
    @default(unit)
    @default(template)

    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")

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

    @testset "IEEE 14: Voltages" begin
        @test nr.voltage.magnitude ≈ fnrBX.voltage.magnitude
        @test nr.voltage.angle ≈ fnrBX.voltage.angle
        @test nr.voltage.magnitude ≈ fnrXB.voltage.magnitude
        @test nr.voltage.angle ≈ fnrXB.voltage.angle
        @test nr.voltage.magnitude ≈ gs.voltage.magnitude
        @test nr.voltage.angle ≈ gs.voltage.angle
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")

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

    @testset "IEEE 30: Voltages" begin
        @test nr.voltage.magnitude ≈ fnrBX.voltage.magnitude
        @test nr.voltage.angle ≈ fnrBX.voltage.angle
        @test nr.voltage.magnitude ≈ fnrXB.voltage.magnitude
        @test nr.voltage.angle ≈ fnrXB.voltage.angle
        @test nr.voltage.magnitude ≈ gs.voltage.magnitude
        @test nr.voltage.angle ≈ gs.voltage.angle
    end
end

@testset "DC Power Flow" begin
    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")
    matpwr14 = h5read(path * "results.h5", "case14test/dcPowerFlow")

    dcModel!(system14)
    analysis = dcPowerFlow(system14)
    solve!(system14, analysis)
    power!(system14, analysis)

    @testset "IEEE 14: Voltage Angles" begin
        @test analysis.voltage.angle ≈ matpwr14["voltage"]
    end

    @testset "IEEE 14: Active Powers" begin
        @test analysis.power.injection.active ≈ matpwr14["injection"]
        @test analysis.power.supply.active ≈ matpwr14["supply"]
        @test analysis.power.from.active ≈ matpwr14["from"]
        @test analysis.power.to.active ≈ -matpwr14["from"]
        @test analysis.power.generator.active ≈ matpwr14["generator"]
    end

    @testset "IEEE 14: Specific Bus Active Powers" begin
        for (key, value) in system14.bus.label
            injection = injectionPower(system14, analysis; label = key)
            supply = supplyPower(system14, analysis; label = key)

            @test injection ≈ matpwr14["injection"][value] atol = 1e-14
            @test supply ≈ matpwr14["supply"][value] atol = 1e-14
        end
    end

    @testset "IEEE 14: Specific Branch Active Powers" begin
        for (key, value) in system14.branch.label
            from = fromPower(system14, analysis; label = key)
            to = toPower(system14, analysis; label = key)

            @test from ≈ matpwr14["from"][value] atol = 1e-14
            @test to ≈ -matpwr14["from"][value] atol = 1e-14
        end
    end

    @testset "IEEE 14: Specific Generator Active Powers" begin
        for (key, value) in system14.generator.label
            generator = generatorPower(system14, analysis; label = key)
            @test generator ≈ matpwr14["generator"][value] atol = 1e-14
        end
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")
    matpwr30 = h5read(path * "results.h5", "case30test/dcPowerFlow")

    analysis = dcPowerFlow(system30, LDLt)
    solve!(system30, analysis)
    power!(system30, analysis)

    @testset "IEEE 30: Voltage Angles" begin
        @test analysis.voltage.angle ≈ matpwr30["voltage"]
    end

    @testset "IEEE 30: Active Powers" begin
        @test analysis.power.injection.active ≈ matpwr30["injection"]
        @test analysis.power.supply.active ≈ matpwr30["supply"]
        @test analysis.power.from.active ≈ matpwr30["from"]
        @test analysis.power.to.active ≈ -matpwr30["from"]
        @test analysis.power.generator.active ≈ matpwr30["generator"]
    end

    @testset "IEEE 30: Specific Bus Active Powers" begin
        for (key, value) in system30.bus.label
            injection = injectionPower(system30, analysis; label = key)
            supply = supplyPower(system30, analysis; label = key)

            @test injection ≈ matpwr30["injection"][value] atol = 1e-14
            @test supply ≈ matpwr30["supply"][value] atol = 1e-14
        end
    end

    @testset "IEEE 30: Specific Branch Active Powers" begin
        for (key, value) in system30.branch.label
            from = fromPower(system30, analysis; label = key)
            to = toPower(system30, analysis; label = key)

            @test from ≈ matpwr30["from"][value] atol = 1e-14
            @test to ≈ -matpwr30["from"][value] atol = 1e-14
        end
    end

    @testset "IEEE 30: Specific Generator Active Powers" begin
        for (key, value) in system30.generator.label
            generator = generatorPower(system30, analysis; label = key)
            @test generator ≈ matpwr30["generator"][value] atol = 1e-14
        end
    end
end

@testset "Print Data in Per-Units" begin
    system14 = powerSystem(path * "case14test.m")

    ########## Print AC Data ##########
    analysis = newtonRaphson(system14)
    mismatch!(system14, analysis)
    solve!(system14, analysis)
    power!(system14, analysis)
    current!(system14, analysis)

    @capture_out @testset "Print AC Bus Data" begin
        width = Dict("Voltage" => 10, "Power Demand Active" => 9)
        show = Dict("Current Injection" => false, "Power Demand Reactive" => false)
        fmt = Dict("Shunt Power" => "%.6f", "Voltage" => "%.2f")
        printBusData(system14, analysis; width, show, fmt, repeat = 10)
        printBusData(system14, analysis; width, show, fmt, repeat = 10, style = false)

        width = Dict("Voltage Angle" => 10, "Power Injection Active" => 9)
        delimiter = ""
        printBusData(system14, analysis; label = 1, width, delimiter, header = true)
        printBusData(system14, analysis; label = 2, width, delimiter)
        printBusData(system14, analysis; label = 4, width, delimiter, footer = true)
        printBusData(system14, analysis; label = 1, width, delimiter, style = false)

        width = Dict("In-Use" => 10)
        show = Dict("Minimum" => false)
        fmt = Dict("Maximum Value" => "%.6f")
        printBusSummary(system14, analysis; width, show, fmt)
        printBusSummary(system14, analysis; width, show, fmt, style = false)
    end

    @capture_out @testset "Print AC Branch Data" begin
        width = Dict("To-Bus Power" => 10)
        show = Dict("Label" => false, "Series Current Angle" => false)
        fmt = Dict("From-Bus Power" => "%.2f", "To-Bus Power Reactive" => "%.2e")
        printBranchData(system14, analysis; width, show, fmt, repeat = 10)
        printBranchData(system14, analysis; width, show, fmt, style = false)

        width = Dict("To-Bus Power" => 10)
        delimiter = ""
        printBranchData(system14, analysis; label = 1, width, delimiter, header = true)
        printBranchData(system14, analysis; label = 2, width, delimiter)
        printBranchData(system14, analysis; label = 4, width, delimiter, footer = true)
        printBranchData(system14, analysis; label = 4, width, style = false)

        width = Dict("In-Use" => 10)
        show = Dict("Minimum" => false)
        fmt = Dict("Maximum Value" => "%.2f")
        printBranchSummary(system14, analysis; width, show, fmt, title = false)
        printBranchSummary(system14, analysis; width, show, fmt, style = false)
    end

    @capture_out @testset "Print AC Generator Data" begin
        width = Dict("Power Output" => 10)
        show = Dict("Label Bus" => false, "Status" => true)
        printGeneratorData(system14, analysis; width, show)
        printGeneratorData(system14, analysis; width, show, style = false)

        printGeneratorData(system14, analysis; label = 1, header = true, footer = true)
        printGeneratorData(system14, analysis; label = 1, style = false)

        printGeneratorSummary(system14, analysis; title = false)
        printGeneratorSummary(system14, analysis; style = false)
    end

    ########## Print DC Data ##########
    analysis = dcPowerFlow(system14)
    solve!(system14, analysis)
    power!(system14, analysis)

    @capture_out @testset "Print DC Bus Data" begin
        printBusData(system14, analysis, repeat = 10)
        printBusData(system14, analysis, repeat = 10; label = 1)
        printBusSummary(system14, analysis)
    end

    @capture_out @testset "Print DC Branch Data" begin
        printBranchData(system14, analysis)
        printBranchData(system14, analysis; label = 1)
        printBranchSummary(system14, analysis)
    end

    @capture_out @testset "Print DC Generator Data" begin
        printGeneratorData(system14, analysis)
        printGeneratorData(system14, analysis; label = 1)
        printGeneratorSummary(system14, analysis)
    end
end

@testset "Print Data in SI Units" begin
    system14 = powerSystem(path * "case14test.m")

    @power(GW, MVAr, MVA)
    @voltage(kV, deg, V)
    @current(MA, deg)

    ########## Print AC Data ##########
    analysis = newtonRaphson(system14)
    mismatch!(system14, analysis)
    solve!(system14, analysis)

    power!(system14, analysis)
    current!(system14, analysis)

    @capture_out @testset "Wrapper Function" begin
        analysis = newtonRaphson(system14)
        acPowerFlow!(system14, analysis; verbose = 3)
    end

    @capture_out @testset "Print AC Bus Data" begin
        printBusData(system14, analysis)
        printBusData(system14, analysis; label = 1, header = true)
        printBusSummary(system14, analysis)
    end

    @capture_out @testset "Print AC Branch Data" begin
        printBranchData(system14, analysis)
        printBranchData(system14, analysis; label = 1, header = true)
        printBranchSummary(system14, analysis)
    end

    @capture_out @testset "Print AC Generator Data" begin
        printGeneratorData(system14, analysis)
        printGeneratorData(system14, analysis; label = 1, header = true)
        printGeneratorSummary(system14, analysis)
    end

    ########## Print DC Data ##########
    analysis = dcPowerFlow(system14)
    solve!(system14, analysis)
    power!(system14, analysis)

    @capture_out @testset "Print DC Bus Data" begin
        printBusData(system14, analysis, repeat = 10)
        printBusData(system14, analysis, repeat = 10; label = 1)
        printBusSummary(system14, analysis)
    end

    @capture_out @testset "Print DC Branch Data" begin
        printBranchData(system14, analysis)
        printBranchData(system14, analysis; label = 1)
        printBranchSummary(system14, analysis)
    end

    @capture_out @testset "Print DC Generator Data" begin
        printGeneratorData(system14, analysis)
        printGeneratorData(system14, analysis; label = 1)
        printGeneratorSummary(system14, analysis)
    end
end