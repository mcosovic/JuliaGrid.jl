system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "Reactive Power Limits" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/reactiveLimit/newtonRaphson")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/reactiveLimit/newtonRaphson")

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

    reactiveLimit!(system14, model)

    model = newtonRaphson(system14)
    for i = 1:1000
        stopping = mismatch!(system14, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, model)
        iteration += 1
    end

    adjustAngle!(system14, model; slack = 1)

    @test model.voltage.magnitude ≈ matpower14["voltageMagnitude"]
    @test model.voltage.angle ≈ matpower14["voltageAngle"] 
    @test iteration == matpower14["iteration"][1]

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

    reactiveLimit!(system30, model)

    model = newtonRaphson(system30)
    for i = 1:1000
        stopping = mismatch!(system30, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, model)
        iteration += 1
    end

    adjustAngle!(system30, model; slack = 1)

    @test model.voltage.magnitude ≈ matpower30["voltageMagnitude"]
    @test model.voltage.angle ≈ matpower30["voltageAngle"] 
    @test iteration == matpower30["iteration"][1]
end