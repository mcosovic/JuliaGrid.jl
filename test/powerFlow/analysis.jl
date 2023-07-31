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

    powers = power(system14, model)   

    @test powers.bus.injection.active ≈ matpower14["Pinj"] 
    @test powers.bus.injection.reactive ≈ matpower14["Qinj"] 
    @test powers.branch.from.active ≈ matpower14["Pij"] 
    @test powers.branch.from.reactive ≈ matpower14["Qij"] 
    @test powers.branch.to.active ≈ matpower14["Pji"] 
    @test powers.branch.to.reactive ≈ matpower14["Qji"] 
    @test powers.branch.shunt.reactive ≈ matpower14["Qbranch"] 
    @test powers.branch.loss.active ≈ matpower14["Ploss"] 
    @test powers.branch.loss.reactive ≈ matpower14["Qloss"] 
    @test powers.generator.output.active ≈ matpower14["Pgen"] 
    @test powers.generator.output.reactive ≈ matpower14["Qgen"] 

    for (key, value) in system14.bus.label
        powers = powerBus(system14, model; label = key)
        @test powers.injection.active ≈ matpower14["Pinj"][value] atol = 1e-13
        @test powers.injection.reactive ≈ matpower14["Qinj"][value] atol = 1e-13
    end

    for (key, value) in system14.branch.label
        powers = powerBranch(system14, model; label = key)
        @test powers.from.active ≈ matpower14["Pij"][value] atol = 1e-13
        @test powers.from.reactive ≈ matpower14["Qij"][value] atol = 1e-13
        @test powers.to.active ≈ matpower14["Pji"][value] atol = 1e-13
        @test powers.to.reactive ≈ matpower14["Qji"][value] atol = 1e-13
        @test powers.shunt.reactive ≈ matpower14["Qbranch"][value] atol = 1e-13
        @test powers.loss.active ≈ matpower14["Ploss"][value] atol = 1e-13
        @test powers.loss.reactive ≈ matpower14["Qloss"][value] atol = 1e-13
    end

    for (key, value) in system14.generator.label
        powers = powerGenerator(system14, model; label = key)
        @test powers.output.active ≈ matpower14["Pgen"][value] atol = 1e-13 
        @test powers.output.reactive ≈ matpower14["Qgen"][value] atol = 1e-13 
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

    powers = power(system30, model)   

    @test powers.bus.injection.active ≈ matpower30["Pinj"] 
    @test powers.bus.injection.reactive ≈ matpower30["Qinj"] 
    @test powers.branch.from.active ≈ matpower30["Pij"] 
    @test powers.branch.from.reactive ≈ matpower30["Qij"] 
    @test powers.branch.to.active ≈ matpower30["Pji"] 
    @test powers.branch.to.reactive ≈ matpower30["Qji"] 
    @test powers.branch.shunt.reactive ≈ matpower30["Qbranch"] 
    @test powers.branch.loss.active ≈ matpower30["Ploss"] 
    @test powers.branch.loss.reactive ≈ matpower30["Qloss"] 
    @test powers.generator.output.active ≈ matpower30["Pgen"] 
    @test powers.generator.output.reactive ≈ matpower30["Qgen"] 

    for (key, value) in system30.bus.label
        powers = powerBus(system30, model; label = key)
        @test powers.injection.active ≈ matpower30["Pinj"][value] atol = 1e-13
        @test powers.injection.reactive ≈ matpower30["Qinj"][value] atol = 1e-13
    end

    for (key, value) in system30.branch.label
        powers = powerBranch(system30, model; label = key)
        @test powers.from.active ≈ matpower30["Pij"][value] atol = 1e-13
        @test powers.from.reactive ≈ matpower30["Qij"][value] atol = 1e-13
        @test powers.to.active ≈ matpower30["Pji"][value] atol = 1e-13
        @test powers.to.reactive ≈ matpower30["Qji"][value] atol = 1e-13
        @test powers.shunt.reactive ≈ matpower30["Qbranch"][value] atol = 1e-13
        @test powers.loss.active ≈ matpower30["Ploss"][value] atol = 1e-13
        @test powers.loss.reactive ≈ matpower30["Qloss"][value] atol = 1e-13
    end

    for (key, value) in system30.generator.label
        powers = powerGenerator(system30, model; label = key)
        @test powers.output.active ≈ matpower30["Pgen"][value] atol = 1e-13 
        @test powers.output.reactive ≈ matpower30["Qgen"][value] atol = 1e-13 
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