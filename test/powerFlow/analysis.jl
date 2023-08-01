system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "Newton-Raphson Method" begin
    field = "/acPowerFlow/newtonRaphson"
    matpower14 = h5read(string(pathData, "case14testResult.h5"), field)
    matpower30 = h5read(string(pathData, "case30testResult.h5"), field)

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

    @test model.voltage.magnitude ≈ matpower14["Vi"]
    @test model.voltage.angle ≈ matpower14["Ti"]
    @test iteration == matpower14["iterations"][1]

    power!(system14, model)   

    @test model.power.injection.active ≈ matpower14["Pinj"] 
    @test model.power.injection.reactive ≈ matpower14["Qinj"] 
    @test model.power.from.active ≈ matpower14["Pij"] 
    @test model.power.from.reactive ≈ matpower14["Qij"] 
    @test model.power.to.active ≈ matpower14["Pji"] 
    @test model.power.to.reactive ≈ matpower14["Qji"] 
    @test model.power.charging.reactive ≈ matpower14["Qbranch"] 
    @test model.power.loss.active ≈ matpower14["Ploss"] 
    @test model.power.loss.reactive ≈ matpower14["Qloss"] 
    @test model.power.generator.active ≈ matpower14["Pgen"] 
    @test model.power.generator.reactive ≈ matpower14["Qgen"] 

    for (key, value) in system14.bus.label
        injection = powerInjection(system14, model; label = key)
        @test injection.active ≈ matpower14["Pinj"][value] atol = 1e-13
        @test injection.reactive ≈ matpower14["Qinj"][value] atol = 1e-13
    end

    for (key, value) in system14.branch.label
        from = powerFrom(system14, model; label = key)
        @test from.active ≈ matpower14["Pij"][value] atol = 1e-13
        @test from.reactive ≈ matpower14["Qij"][value] atol = 1e-13
    
        to = powerTo(system14, model; label = key)
        @test to.active ≈ matpower14["Pji"][value] atol = 1e-13
        @test to.reactive ≈ matpower14["Qji"][value] atol = 1e-13
    
        charging = powerCharging(system14, model; label = key)
        @test charging ≈ matpower14["Qbranch"][value] atol = 1e-13
    
        loss = powerLoss(system14, model; label = key)
        @test loss.active ≈ matpower14["Ploss"][value] atol = 1e-13
        @test loss.reactive ≈ matpower14["Qloss"][value] atol = 1e-13
    end

    for (key, value) in system14.generator.label
        output = powerGenerator(system14, model; label = key)
        @test output.active ≈ matpower14["Pgen"][value] atol = 1e-13 
        @test output.reactive ≈ matpower14["Qgen"][value] atol = 1e-13 
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

    @test model.voltage.magnitude ≈ matpower30["Vi"]
    @test model.voltage.angle ≈ matpower30["Ti"]
    @test iteration == matpower30["iterations"][1]

    power!(system30, model)   

    @test model.power.injection.active ≈ matpower30["Pinj"] 
    @test model.power.injection.reactive ≈ matpower30["Qinj"] 
    @test model.power.from.active ≈ matpower30["Pij"] 
    @test model.power.from.reactive ≈ matpower30["Qij"] 
    @test model.power.to.active ≈ matpower30["Pji"] 
    @test model.power.to.reactive ≈ matpower30["Qji"] 
    @test model.power.charging.reactive ≈ matpower30["Qbranch"] 
    @test model.power.loss.active ≈ matpower30["Ploss"] 
    @test model.power.loss.reactive ≈ matpower30["Qloss"] 
    @test model.power.generator.active ≈ matpower30["Pgen"] 
    @test model.power.generator.reactive ≈ matpower30["Qgen"] 

    for (key, value) in system30.bus.label
        injection = powerInjection(system30, model; label = key)
        @test injection.active ≈ matpower30["Pinj"][value] atol = 1e-13
        @test injection.reactive ≈ matpower30["Qinj"][value] atol = 1e-13
    end

    for (key, value) in system30.branch.label
        from = powerFrom(system30, model; label = key)
        @test from.active ≈ matpower30["Pij"][value] atol = 1e-13
        @test from.reactive ≈ matpower30["Qij"][value] atol = 1e-13
    
        to = powerTo(system30, model; label = key)
        @test to.active ≈ matpower30["Pji"][value] atol = 1e-13
        @test to.reactive ≈ matpower30["Qji"][value] atol = 1e-13
    
        charging = powerCharging(system30, model; label = key)
        @test charging ≈ matpower30["Qbranch"][value] atol = 1e-13
    
        loss = powerLoss(system30, model; label = key)
        @test loss.active ≈ matpower30["Ploss"][value] atol = 1e-13
        @test loss.reactive ≈ matpower30["Qloss"][value] atol = 1e-13
    end

    for (key, value) in system30.generator.label
        output = powerGenerator(system30, model; label = key)
        @test output.active ≈ matpower30["Pgen"][value] atol = 1e-13 
        @test output.reactive ≈ matpower30["Qgen"][value] atol = 1e-13 
    end
end

@testset "Fast Newton-Raphson BX Method" begin
    field = "/acPowerFlow/fastNewtonRaphson/BX"
    matpower14 = h5read(string(pathData, "case14testResult.h5"), field)
    matpower30 = h5read(string(pathData, "case30testResult.h5"), field)

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

    @test model.voltage.magnitude ≈ matpower14["Vi"]
    @test model.voltage.angle ≈ matpower14["Ti"]
    @test iteration == matpower14["iterations"][1]

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

    @test model.voltage.magnitude ≈ matpower30["Vi"]
    @test model.voltage.angle ≈ matpower30["Ti"]
    @test iteration == matpower30["iterations"][1]
end

@testset "Fast Newton-Raphson XB Method" begin
    field = "/acPowerFlow/fastNewtonRaphson/XB"
    matpower14 = h5read(string(pathData, "case14testResult.h5"), field)
    matpower30 = h5read(string(pathData, "case30testResult.h5"), field)

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

    @test model.voltage.magnitude ≈ matpower14["Vi"]
    @test model.voltage.angle ≈ matpower14["Ti"] 
    @test iteration == matpower14["iterations"][1]

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

    @test model.voltage.magnitude ≈ matpower30["Vi"]
    @test model.voltage.angle ≈ matpower30["Ti"] 
    @test iteration == matpower30["iterations"][1]
end

@testset "Gauss-Seidel Method" begin
    field = "/acPowerFlow/gaussSeidel"
    matpower14 = h5read(string(pathData, "case14testResult.h5"), field)
    matpower30 = h5read(string(pathData, "case30testResult.h5"), field)

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

    @test model.voltage.magnitude ≈ matpower14["Vi"]
    @test model.voltage.angle ≈ matpower14["Ti"]
    @test iteration == matpower14["iterations"][1]

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

    @test model.voltage.magnitude ≈ matpower30["Vi"]
    @test model.voltage.angle ≈ matpower30["Ti"]
    @test iteration == matpower30["iterations"][1]
end

@testset "DC Power Flow" begin
    field = "/dcPowerFlow"
    matpower14 = h5read(string(pathData, "case14testResult.h5"), field)
    matpower30 = h5read(string(pathData, "case30testResult.h5"), field)

    ######## Modified IEEE 14-bus Test Case ##########
    dcModel!(system14)
    model = dcPowerFlow(system14)
    
    solve!(system14, model)
    @test model.voltage.angle ≈ matpower14["Ti"] 

    power!(system14, model)
    @test model.power.injection.active ≈ matpower14["Pinj"]
    @test model.power.from.active ≈ matpower14["Pij"]
    @test model.power.generator.active ≈ matpower14["Pgen"]

    for (key, value) in system14.bus.label
        @test powerInjection(system14, model; label = key) ≈ matpower14["Pinj"][value] atol = 1e-14
    end

    for (key, value) in system14.branch.label
        @test powerFrom(system14, model; label = key) ≈ matpower14["Pij"][value] atol = 1e-14
        @test powerTo(system14, model; label = key) ≈ -matpower14["Pij"][value] atol = 1e-14
    end

    for (key, value) in system14.generator.label
        @test powerGenerator(system14, model; label = key) ≈ matpower14["Pgen"][value] atol = 1e-14
    end

    ######## Modified IEEE 30-bus Test Case ##########
    dcModel!(system30)
    model = dcPowerFlow(system30)
    
    solve!(system30, model)
    @test model.voltage.angle ≈ matpower30["Ti"]

    power!(system30, model)
    @test model.power.injection.active ≈ matpower30["Pinj"]
    @test model.power.from.active ≈ matpower30["Pij"]
    @test model.power.generator.active ≈ matpower30["Pgen"]

    for (key, value) in system30.bus.label
        @test powerInjection(system30, model; label = key) ≈ matpower30["Pinj"][value] atol = 1e-14
    end

    for (key, value) in system30.branch.label
        @test powerFrom(system30, model; label = key) ≈ matpower30["Pij"][value] atol = 1e-14
        @test powerTo(system30, model; label = key) ≈ -matpower30["Pij"][value] atol = 1e-14
    end

    for (key, value) in system30.generator.label
        @test powerGenerator(system30, model; label = key) ≈ matpower30["Pgen"][value] atol = 1e-14
    end
end