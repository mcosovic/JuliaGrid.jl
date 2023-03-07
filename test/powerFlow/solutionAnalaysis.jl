system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))
torad = pi / 180
topu = 1 / 100

@testset "newtonRaphson, newtonRaphson!" begin
    matpower14 = h5read(string(pathData, "case14testPowerFlowResult.h5"), "/nr")
    matpower30 = h5read(string(pathData, "case30testPowerFlowResult.h5"), "/nr")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    result = newtonRaphson(system14)
    stopping = result.algorithm.iteration.stopping
    for i = 1:1000
        newtonRaphson!(system14, result)
        if stopping.active < 1e-8 && stopping.reactive < 1e-8
            break
        end
    end
    bus!(system14, result)
    branch!(system14, result)
    generator!(system14, result)

    @test result.bus.voltage.magnitude ≈ matpower14["Vi"]
    @test result.bus.voltage.angle ≈ matpower14["Ti"] * torad
    @test result.algorithm.iteration.number == matpower14["iterations"][1]

    @test result.bus.power.injection.active ≈ matpower14["Pinj"] * topu
    @test result.bus.power.injection.reactive ≈ matpower14["Qinj"] * topu

    @test result.branch.power.from.active ≈ matpower14["Pij"] * topu
    @test result.branch.power.from.reactive ≈ matpower14["Qij"] * topu
    @test result.branch.power.to.active ≈ matpower14["Pji"] * topu
    @test result.branch.power.to.reactive ≈ matpower14["Qji"] * topu
    @test result.branch.power.shunt.reactive ≈ matpower14["Qbranch"] * topu
    @test result.branch.power.loss.active ≈ matpower14["Ploss"] * topu
    @test result.branch.power.loss.reactive ≈ matpower14["Qloss"] * topu

    @test result.generator.power.active ≈ matpower14["Pgen"] * topu
    @test result.generator.power.reactive ≈ matpower14["Qgen"] * topu

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    result = newtonRaphson(system30)
    stopping = result.algorithm.iteration.stopping
    for i = 1:1000
        newtonRaphson!(system30, result)
        if stopping.active < 1e-8 && stopping.reactive < 1e-8
            break
        end
    end
    bus!(system30, result)
    branch!(system30, result)
    generator!(system30, result)

    @test result.bus.voltage.magnitude ≈ matpower30["Vi"]
    @test result.bus.voltage.angle ≈ matpower30["Ti"] * torad
    @test result.algorithm.iteration.number == matpower30["iterations"][1]

    @test result.bus.power.injection.active ≈ matpower30["Pinj"] * topu
    @test result.bus.power.injection.reactive ≈ matpower30["Qinj"] * topu

    @test result.branch.power.from.active ≈ matpower30["Pij"] * topu
    @test result.branch.power.from.reactive ≈ matpower30["Qij"] * topu
    @test result.branch.power.to.active ≈ matpower30["Pji"] * topu
    @test result.branch.power.to.reactive ≈ matpower30["Qji"] * topu
    @test result.branch.power.shunt.reactive ≈ matpower30["Qbranch"] * topu
    @test result.branch.power.loss.active ≈ matpower30["Ploss"] * topu
    @test result.branch.power.loss.reactive ≈ matpower30["Qloss"] * topu

    @test result.generator.power.active ≈ matpower30["Pgen"] * topu
    @test result.generator.power.reactive ≈ matpower30["Qgen"] * topu
end

@testset "fastNewtonRaphsonBX, fastNewtonRaphson!" begin
    matpower14 = h5read(string(pathData, "case14testPowerFlowResult.h5"), "/fdbx")
    matpower30 = h5read(string(pathData, "case30testPowerFlowResult.h5"), "/fdbx")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    result = fastNewtonRaphsonBX(system14)
    stopping = result.algorithm.iteration.stopping
    for i = 1:1000
        fastNewtonRaphson!(system14, result)
        if stopping.active < 1e-8 && stopping.reactive < 1e-8
            break
        end
    end

    @test result.bus.voltage.magnitude ≈ matpower14["Vi"]
    @test result.bus.voltage.angle ≈ matpower14["Ti"] * torad
    @test result.algorithm.iteration.number == matpower14["iterations"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    result = fastNewtonRaphsonBX(system30)
    stopping = result.algorithm.iteration.stopping
    for i = 1:1000
        fastNewtonRaphson!(system30, result)
        if stopping.active < 1e-8 && stopping.reactive < 1e-8
            break
        end
    end

    @test result.bus.voltage.magnitude ≈ matpower30["Vi"]
    @test result.bus.voltage.angle ≈ matpower30["Ti"] * torad
    @test result.algorithm.iteration.number == matpower30["iterations"][1]
end

@testset "fastNewtonRaphsonXB, fastNewtonRaphson!" begin
    matpower14 = h5read(string(pathData, "case14testPowerFlowResult.h5"), "/fdxb")
    matpower30 = h5read(string(pathData, "case30testPowerFlowResult.h5"), "/fdxb")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    result = fastNewtonRaphsonXB(system14)
    stopping = result.algorithm.iteration.stopping
    for i = 1:1000
        fastNewtonRaphson!(system14, result)
        if stopping.active < 1e-8 && stopping.reactive < 1e-8
            break
        end
    end

    @test result.bus.voltage.magnitude ≈ matpower14["Vi"]
    @test result.bus.voltage.angle ≈ matpower14["Ti"] * torad
    @test result.algorithm.iteration.number == matpower14["iterations"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    result = fastNewtonRaphsonXB(system30)
    stopping = result.algorithm.iteration.stopping
    for i = 1:1000
        fastNewtonRaphson!(system30, result)
        if stopping.active < 1e-8 && stopping.reactive < 1e-8
            break
        end
    end

    @test result.bus.voltage.magnitude ≈ matpower30["Vi"]
    @test result.bus.voltage.angle ≈ matpower30["Ti"] * torad
    @test result.algorithm.iteration.number == matpower30["iterations"][1]
end

@testset "gaussSeidel, gaussSeidel!" begin
    matpower14 = h5read(string(pathData, "case14testPowerFlowResult.h5"), "/gs")
    matpower30 = h5read(string(pathData, "case30testPowerFlowResult.h5"), "/gs")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    result = gaussSeidel(system14)
    stopping = result.algorithm.iteration.stopping
    for i = 1:1000
        gaussSeidel!(system14, result)
        if stopping.active < 1e-8 && stopping.reactive < 1e-8
            break
        end
    end

    @test result.bus.voltage.magnitude ≈ matpower14["Vi"]
    @test result.bus.voltage.angle ≈ matpower14["Ti"] * torad
    @test result.algorithm.iteration.number == matpower14["iterations"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    result = gaussSeidel(system30)
    stopping = result.algorithm.iteration.stopping
    for i = 1:1000
        gaussSeidel!(system30, result)
        if stopping.active < 1e-8 && stopping.reactive < 1e-8
            break
        end
    end

    @test result.bus.voltage.magnitude ≈ matpower30["Vi"]
    @test result.bus.voltage.angle ≈ matpower30["Ti"] * torad
    @test result.algorithm.iteration.number == matpower30["iterations"][1]
end

@testset "dcPowerFlow" begin
    matpower14 = h5read(string(pathData, "case14testPowerFlowResult.h5"), "/dc")
    matpower30 = h5read(string(pathData, "case30testPowerFlowResult.h5"), "/dc")

    ######## Modified IEEE 14-bus Test Case ##########
    dcModel!(system14)
    result = dcPowerFlow(system14)
    bus!(system14, result)
    branch!(system14, result)
    generator!(system14, result)
    
    @test result.bus.voltage.angle ≈ matpower14["Ti"] * torad
    @test result.bus.power.injection.active ≈ matpower14["Pinj"] * topu
    @test result.branch.power.from.active ≈ matpower14["Pij"] * topu
    @test result.generator.power.active ≈ matpower14["Pgen"] * topu
    

    ######## Modified IEEE 30-bus Test Case ##########
    dcModel!(system30)
    result = dcPowerFlow(system30)
    bus!(system30, result)
    branch!(system30, result)
    generator!(system30, result)
    
    @test result.bus.voltage.angle ≈ matpower30["Ti"] * torad
    @test result.bus.power.injection.active ≈ matpower30["Pinj"] * topu
    @test result.branch.power.from.active ≈ matpower30["Pij"] * topu
    @test result.generator.power.active ≈ matpower30["Pgen"] * topu
end