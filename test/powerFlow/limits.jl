system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "Reactive Power Limits" begin
    field = "/acPowerFlow/reactiveLimit/newtonRaphson"
    matpower14 = h5read(string(pathData, "case14testResult.h5"), field)
    matpower30 = h5read(string(pathData, "case30testResult.h5"), field)

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    model = newtonRaphson(system14)
    iterations = 0
    for i = 1:1000
        stopping = mismatch!(system14, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, model)
        iterations += 1
    end
    power = analysisGenerator(system14, model)

    reactiveLimit!(system14, model, power)

    model = newtonRaphson(system14)
    for i = 1:1000
        stopping = mismatch!(system14, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, model)
        iterations += 1
    end

    adjustAngle!(system14, model; slack = 1)

    @test model.voltage.magnitude ≈ matpower14["Vi"]
    @test model.voltage.angle ≈ matpower14["Ti"] 
    @test iterations == matpower14["iterations"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    model = newtonRaphson(system30)
    iterations = 0
    for i = 1:1000
        stopping = mismatch!(system30, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, model)
        iterations += 1
    end
    power = analysisGenerator(system30, model)

    reactiveLimit!(system30, model, power)

    model = newtonRaphson(system30)
    for i = 1:1000
        stopping = mismatch!(system30, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, model)
        iterations += 1
    end

    adjustAngle!(system30, model; slack = 1)

    @test model.voltage.magnitude ≈ matpower30["Vi"]
    @test model.voltage.angle ≈ matpower30["Ti"] 
    @test iterations == matpower30["iterations"][1]
end
