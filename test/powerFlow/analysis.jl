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

    for (key, value) in system14.bus.label
        injection = powerInjection(system14, analysis; label = key)
        @test injection.active ≈ matpower14["injectionActive"][value] atol = 1e-13
        @test injection.reactive ≈ matpower14["injectionReactive"][value] atol = 1e-13

        supply = powerSupply(system14, analysis; label = key)
        @test supply.active ≈ matpower14["supplyActive"][value] atol = 1e-13
        @test supply.reactive ≈ matpower14["supplyReactive"][value] atol = 1e-13

        shunt = powerShunt(system14, analysis; label = key)
        @test shunt.active ≈ matpower14["shuntActive"][value] atol = 1e-13
        @test shunt.reactive ≈ matpower14["shuntReactive"][value] atol = 1e-13
    end

    for (key, value) in system14.branch.label
        from = powerFrom(system14, analysis; label = key)
        @test from.active ≈ matpower14["fromActive"][value] atol = 1e-13
        @test from.reactive ≈ matpower14["fromReactive"][value] atol = 1e-13

        to = powerTo(system14, analysis; label = key)
        @test to.active ≈ matpower14["toActive"][value] atol = 1e-13
        @test to.reactive ≈ matpower14["toReactive"][value] atol = 1e-13

        charging = powerCharging(system14, analysis; label = key)
        @test charging.from.reactive ≈ matpower14["chargingFrom"][value] atol = 1e-13
        @test charging.to.reactive ≈ matpower14["chargingTo"][value] atol = 1e-13

        series = powerSeries(system14, analysis; label = key)
        @test series.active ≈ matpower14["lossActive"][value] atol = 1e-13
        @test series.reactive ≈ matpower14["lossReactive"][value] atol = 1e-13
    end

    for (key, value) in system14.generator.label
        output = powerGenerator(system14, analysis; label = key)
        @test output.active ≈ matpower14["generatorActive"][value] atol = 1e-13
        @test output.reactive ≈ matpower14["generatorReactive"][value] atol = 1e-13
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

    for (key, value) in system30.bus.label
        injection = powerInjection(system30, analysis; label = key)
        @test injection.active ≈ matpower30["injectionActive"][value] atol = 1e-13
        @test injection.reactive ≈ matpower30["injectionReactive"][value] atol = 1e-13

        supply = powerSupply(system30, analysis; label = key)
        @test supply.active ≈ matpower30["supplyActive"][value] atol = 1e-13
        @test supply.reactive ≈ matpower30["supplyReactive"][value] atol = 1e-13

        shunt = powerShunt(system30, analysis; label = key)
        @test shunt.active ≈ matpower30["shuntActive"][value] atol = 1e-13
        @test shunt.reactive ≈ matpower30["shuntReactive"][value] atol = 1e-13
    end

    for (key, value) in system30.branch.label
        from = powerFrom(system30, analysis; label = key)
        @test from.active ≈ matpower30["fromActive"][value] atol = 1e-13
        @test from.reactive ≈ matpower30["fromReactive"][value] atol = 1e-13

        to = powerTo(system30, analysis; label = key)
        @test to.active ≈ matpower30["toActive"][value] atol = 1e-13
        @test to.reactive ≈ matpower30["toReactive"][value] atol = 1e-13

        charging = powerCharging(system30, analysis; label = key)
        @test charging.from.reactive ≈ matpower30["chargingFrom"][value] atol = 1e-13
        @test charging.to.reactive ≈ matpower30["chargingTo"][value] atol = 1e-13

        series = powerSeries(system30, analysis; label = key)
        @test series.active ≈ matpower30["lossActive"][value] atol = 1e-13
        @test series.reactive ≈ matpower30["lossReactive"][value] atol = 1e-13
    end

    for (key, value) in system30.generator.label
        output = powerGenerator(system30, analysis; label = key)
        @test output.active ≈ matpower30["generatorActive"][value] atol = 1e-13
        @test output.reactive ≈ matpower30["generatorReactive"][value] atol = 1e-13
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