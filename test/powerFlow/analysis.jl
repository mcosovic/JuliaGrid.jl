system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "Newton-Raphson Method" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/newtonRaphson")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/newtonRaphson")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    model = newtonRaphson(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, model)
        iteration += 1
    end
    power!(system14, model) 

    @test model.voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test model.voltage.angle ≈ matpower14["voltageAngle"]
    @test iteration == matpower14["iteration"][1]
    @test model.power.injection.active ≈ matpower14["injectionActive"] 
    @test model.power.injection.reactive ≈ matpower14["injectionReactive"] 
    @test model.power.supply.active ≈ matpower14["supplyActive"] 
    @test model.power.supply.reactive ≈ matpower14["supplyReactive"] 
    @test model.power.shunt.active ≈ matpower14["shuntActive"] 
    @test model.power.shunt.reactive ≈ matpower14["shuntReactive"] 
    @test model.power.from.active ≈ matpower14["fromActive"] 
    @test model.power.from.reactive ≈ matpower14["fromReactive"] 
    @test model.power.to.active ≈ matpower14["toActive"] 
    @test model.power.to.reactive ≈ matpower14["toReactive"] 
    @test model.power.charging.reactive ≈ matpower14["chargingReactive"] 
    @test model.power.loss.active ≈ matpower14["lossActive"] 
    @test model.power.loss.reactive ≈ matpower14["lossReactive"] 
    @test model.power.generator.active ≈ matpower14["generatorActive"] 
    @test model.power.generator.reactive ≈ matpower14["generatorReactive"] 

    for (key, value) in system14.bus.label
        injection = powerInjection(system14, model; label = key)
        @test injection.active ≈ matpower14["injectionActive"][value] atol = 1e-13
        @test injection.reactive ≈ matpower14["injectionReactive"][value] atol = 1e-13

        supply = powerSupply(system14, model; label = key)
        @test supply.active ≈ matpower14["supplyActive"][value] atol = 1e-13
        @test supply.reactive ≈ matpower14["supplyReactive"][value] atol = 1e-13

        shunt = powerShunt(system14, model; label = key)
        @test shunt.active ≈ matpower14["shuntActive"][value] atol = 1e-13
        @test shunt.reactive ≈ matpower14["shuntReactive"][value] atol = 1e-13
    end

    for (key, value) in system14.branch.label
        from = powerFrom(system14, model; label = key)
        @test from.active ≈ matpower14["fromActive"][value] atol = 1e-13
        @test from.reactive ≈ matpower14["fromReactive"][value] atol = 1e-13
    
        to = powerTo(system14, model; label = key)
        @test to.active ≈ matpower14["toActive"][value] atol = 1e-13
        @test to.reactive ≈ matpower14["toReactive"][value] atol = 1e-13
    
        charging = powerCharging(system14, model; label = key)
        @test charging ≈ matpower14["chargingReactive"][value] atol = 1e-13
    
        loss = powerLoss(system14, model; label = key)
        @test loss.active ≈ matpower14["lossActive"][value] atol = 1e-13
        @test loss.reactive ≈ matpower14["lossReactive"][value] atol = 1e-13
    end

    for (key, value) in system14.generator.label
        output = powerGenerator(system14, model; label = key)
        @test output.active ≈ matpower14["generatorActive"][value] atol = 1e-13 
        @test output.reactive ≈ matpower14["generatorReactive"][value] atol = 1e-13 
    end

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    model = newtonRaphson(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, model)
        iteration += 1
    end
    power!(system30, model)

    @test model.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test model.voltage.angle ≈ matpower30["voltageAngle"]
    @test iteration == matpower30["iteration"][1]
    @test model.power.injection.active ≈ matpower30["injectionActive"] 
    @test model.power.injection.reactive ≈ matpower30["injectionReactive"] 
    @test model.power.supply.active ≈ matpower30["supplyActive"] 
    @test model.power.supply.reactive ≈ matpower30["supplyReactive"] 
    @test model.power.shunt.active ≈ matpower30["shuntActive"] 
    @test model.power.shunt.reactive ≈ matpower30["shuntReactive"] 
    @test model.power.from.active ≈ matpower30["fromActive"] 
    @test model.power.from.reactive ≈ matpower30["fromReactive"] 
    @test model.power.to.active ≈ matpower30["toActive"] 
    @test model.power.to.reactive ≈ matpower30["toReactive"] 
    @test model.power.charging.reactive ≈ matpower30["chargingReactive"] 
    @test model.power.loss.active ≈ matpower30["lossActive"] 
    @test model.power.loss.reactive ≈ matpower30["lossReactive"] 
    @test model.power.generator.active ≈ matpower30["generatorActive"] 
    @test model.power.generator.reactive ≈ matpower30["generatorReactive"] 

    for (key, value) in system30.bus.label
        injection = powerInjection(system30, model; label = key)
        @test injection.active ≈ matpower30["injectionActive"][value] atol = 1e-13
        @test injection.reactive ≈ matpower30["injectionReactive"][value] atol = 1e-13

        supply = powerSupply(system30, model; label = key)
        @test supply.active ≈ matpower30["supplyActive"][value] atol = 1e-13
        @test supply.reactive ≈ matpower30["supplyReactive"][value] atol = 1e-13

        shunt = powerShunt(system30, model; label = key)
        @test shunt.active ≈ matpower30["shuntActive"][value] atol = 1e-13
        @test shunt.reactive ≈ matpower30["shuntReactive"][value] atol = 1e-13
    end

    for (key, value) in system30.branch.label
        from = powerFrom(system30, model; label = key)
        @test from.active ≈ matpower30["fromActive"][value] atol = 1e-13
        @test from.reactive ≈ matpower30["fromReactive"][value] atol = 1e-13
    
        to = powerTo(system30, model; label = key)
        @test to.active ≈ matpower30["toActive"][value] atol = 1e-13
        @test to.reactive ≈ matpower30["toReactive"][value] atol = 1e-13
    
        charging = powerCharging(system30, model; label = key)
        @test charging ≈ matpower30["chargingReactive"][value] atol = 1e-13
    
        loss = powerLoss(system30, model; label = key)
        @test loss.active ≈ matpower30["lossActive"][value] atol = 1e-13
        @test loss.reactive ≈ matpower30["lossReactive"][value] atol = 1e-13
    end

    for (key, value) in system30.generator.label
        output = powerGenerator(system30, model; label = key)
        @test output.active ≈ matpower30["generatorActive"][value] atol = 1e-13 
        @test output.reactive ≈ matpower30["generatorReactive"][value] atol = 1e-13 
    end
end

@testset "Fast Newton-Raphson BX Method" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/fastNewtonRaphsonBX")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/fastNewtonRaphsonBX")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    model = fastNewtonRaphsonBX(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, model)
        iteration += 1
    end

    @test model.voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test model.voltage.angle ≈ matpower14["voltageAngle"]
    @test iteration == matpower14["iteration"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    model = fastNewtonRaphsonBX(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, model)
        iteration += 1
    end

    @test model.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test model.voltage.angle ≈ matpower30["voltageAngle"]
    @test iteration == matpower30["iteration"][1]
end

@testset "Fast Newton-Raphson XB Method" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/fastNewtonRaphsonXB")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/fastNewtonRaphsonXB")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    model = fastNewtonRaphsonXB(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, model)
        iteration += 1
    end

    @test model.voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test model.voltage.angle ≈ matpower14["voltageAngle"] 
    @test iteration == matpower14["iteration"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    model = fastNewtonRaphsonXB(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, model)
        iteration += 1
    end

    @test model.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test model.voltage.angle ≈ matpower30["voltageAngle"] 
    @test iteration == matpower30["iteration"][1]
end

@testset "Gauss-Seidel Method" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/gaussSeidel")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/gaussSeidel")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    model = gaussSeidel(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, model)
        iteration += 1
    end

    @test model.voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test model.voltage.angle ≈ matpower14["voltageAngle"]
    @test iteration == matpower14["iteration"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    model = gaussSeidel(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, model)
        iteration += 1
    end

    @test model.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test model.voltage.angle ≈ matpower30["voltageAngle"]
    @test iteration == matpower30["iteration"][1]
end

@testset "DC Power Flow" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/dcPowerFlow")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/dcPowerFlow")

    ######## Modified IEEE 14-bus Test Case ##########
    dcModel!(system14)
    model = dcPowerFlow(system14)
    solve!(system14, model)
    power!(system14, model)

    @test model.voltage.angle ≈ matpower14["voltage"] 
    @test model.power.injection.active ≈ matpower14["injection"]
    @test model.power.supply.active ≈ matpower14["supply"]
    @test model.power.from.active ≈ matpower14["from"]
    @test model.power.to.active ≈ -matpower14["from"]
    @test model.power.generator.active ≈ matpower14["generator"]

    for (key, value) in system14.bus.label
        @test powerInjection(system14, model; label = key) ≈ matpower14["injection"][value] atol = 1e-14
        @test powerSupply(system14, model; label = key) ≈ matpower14["supply"][value] atol = 1e-14
    end

    for (key, value) in system14.branch.label
        @test powerFrom(system14, model; label = key) ≈ matpower14["from"][value] atol = 1e-14
        @test powerTo(system14, model; label = key) ≈ -matpower14["from"][value] atol = 1e-14
    end

    for (key, value) in system14.generator.label
        @test powerGenerator(system14, model; label = key) ≈ matpower14["generator"][value] atol = 1e-14
    end

    ######## Modified IEEE 30-bus Test Case ##########
    dcModel!(system30)
    model = dcPowerFlow(system30)
    solve!(system30, model)
    power!(system30, model)

    @test model.voltage.angle ≈ matpower30["voltage"] 
    @test model.power.injection.active ≈ matpower30["injection"]
    @test model.power.supply.active ≈ matpower30["supply"]
    @test model.power.from.active ≈ matpower30["from"]
    @test model.power.to.active ≈ -matpower30["from"]
    @test model.power.generator.active ≈ matpower30["generator"]

    for (key, value) in system30.bus.label
        @test powerInjection(system30, model; label = key) ≈ matpower30["injection"][value] atol = 1e-14
        @test powerSupply(system30, model; label = key) ≈ matpower30["supply"][value] atol = 1e-14
    end

    for (key, value) in system30.branch.label
        @test powerFrom(system30, model; label = key) ≈ matpower30["from"][value] atol = 1e-14
        @test powerTo(system30, model; label = key) ≈ -matpower30["from"][value] atol = 1e-14
    end

    for (key, value) in system30.generator.label
        @test powerGenerator(system30, model; label = key) ≈ matpower30["generator"][value] atol = 1e-14
    end
end