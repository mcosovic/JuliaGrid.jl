system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "reactivePowerLimit!, adjustVoltageAngle!" begin
    matpower14 = h5read(string(pathData, "case14testResult.h5"), "/nrLimit")
    matpower30 = h5read(string(pathData, "case30testResult.h5"), "/nrLimit")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    result = newtonRaphson(system14)
    iterations = 0
    for i = 1:1000
        stopping = mismatch!(system14, result)
        if all(stopping .< 1e-8)
            break
        end
        solvePowerFlow!(system14, result)
        iterations += 1
    end

    reactivePowerLimit!(system14, result)

    result = newtonRaphson(system14)
    for i = 1:1000
        stopping = mismatch!(system14, result)
        if all(stopping .< 1e-8)
            break
        end
        solvePowerFlow!(system14, result)
        iterations += 1
    end

    adjustVoltageAngle!(system14, result; slack = 1)

    @test result.bus.voltage.magnitude ≈ matpower14["Vi"]
    @test result.bus.voltage.angle ≈ matpower14["Ti"] * torad
    @test iterations == matpower14["iterations"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    result = newtonRaphson(system30)
    iterations = 0
    for i = 1:1000
        stopping = mismatch!(system30, result)
        if all(stopping .< 1e-8)
            break
        end
        solvePowerFlow!(system30, result)
        iterations += 1
    end

    reactivePowerLimit!(system30, result)

    result = newtonRaphson(system30)
    for i = 1:1000
        stopping = mismatch!(system30, result)
        if all(stopping .< 1e-8)
            break
        end
        solvePowerFlow!(system30, result)
        iterations += 1
    end

    adjustVoltageAngle!(system30, result; slack = 1)

    @test result.bus.voltage.magnitude ≈ matpower30["Vi"]
    @test result.bus.voltage.angle ≈ matpower30["Ti"] * torad
    @test iterations == matpower30["iterations"][1]
end
