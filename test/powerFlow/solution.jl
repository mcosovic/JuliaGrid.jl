system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))
torad = pi / 180

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

    @test result.bus.voltage.magnitude ≈ matpower14["Vi"]
    @test result.bus.voltage.angle ≈ matpower14["Ti"] * torad
    @test result.algorithm.iteration.number == matpower14["iterations"][1]

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

    @test result.bus.voltage.magnitude ≈ matpower30["Vi"]
    @test result.bus.voltage.angle ≈ matpower30["Ti"] * torad
    @test result.algorithm.iteration.number == matpower30["iterations"][1]
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

    @test result.bus.voltage.angle ≈ matpower14["Ti"] * torad
    

    ######## Modified IEEE 30-bus Test Case ##########
    dcModel!(system30)
    result = dcPowerFlow(system30)

    @test result.bus.voltage.angle ≈ matpower30["Ti"] * torad
end