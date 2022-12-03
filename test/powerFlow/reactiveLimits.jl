system14 = powerSystem(string(pathData, "case14test.h5"))
system30 = powerSystem(string(pathData, "case30test.h5"))

torad = pi / 180
topu = 1 / (1e-6 * system14.basePower)

@testset "newtonRaphson, newtonRaphson!, reactivePowerLimit!, adjustVoltageAngle!" begin
    matpower14 = h5read(string(pathData, "case14testPowerFlowResult.h5"), "/nrLimit")
    matpower30 = h5read(string(pathData, "case30testPowerFlowResult.h5"), "/nrLimit")

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
    iterations = result.algorithm.iteration.number

    reactivePowerLimit!(system14, result)

    result = newtonRaphson(system14)
    stopping = result.algorithm.iteration.stopping
    for i = 1:1000
        newtonRaphson!(system14, result)
        if stopping.active < 1e-8 && stopping.reactive < 1e-8
            break
        end
    end
    iterations += result.algorithm.iteration.number

    adjustVoltageAngle!(system14, result)

    @test result.bus.voltage.magnitude ≈ matpower14["Vi"]
    @test result.bus.voltage.angle ≈ matpower14["Ti"] * torad
    @test iterations == matpower14["iterations"][1]

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
    iterations = result.algorithm.iteration.number

    reactivePowerLimit!(system30, result)

    result = newtonRaphson(system30)
    stopping = result.algorithm.iteration.stopping
    for i = 1:1000
        newtonRaphson!(system30, result)
        if stopping.active < 1e-8 && stopping.reactive < 1e-8
            break
        end
    end
    iterations += result.algorithm.iteration.number

    adjustVoltageAngle!(system30, result)

    @test result.bus.voltage.magnitude ≈ matpower30["Vi"]
    @test result.bus.voltage.angle ≈ matpower30["Ti"] * torad
    @test iterations == matpower30["iterations"][1]
end
