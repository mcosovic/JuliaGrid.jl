system14 = powerSystem(path * "case14test.m")
system30 = powerSystem(path * "case30test.m")

@testset "Newton-Raphson Method with Reactive Power Limits" begin
    matpower14 = h5read(path * "results.h5", "case14test/reactiveLimit/newtonRaphson")
    matpower30 = h5read(path * "results.h5", "case30test/reactiveLimit/newtonRaphson")

    ########## IEEE 14-bus Test Case ##########
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

    reactiveLimit!(system14, analysis)

    analysis = newtonRaphson(system14)
    for i = 1:1000
        stopping = mismatch!(system14, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, analysis)
        iteration += 1
    end

    adjustAngle!(system14, analysis; slack = 1)

    @testset "IEEE 14: Iteration Number and Voltages" begin
        @test iteration == matpower14["iteration"][1]
        @test analysis.voltage.magnitude ≈ matpower14["voltageMagnitude"]
        @test analysis.voltage.angle ≈ matpower14["voltageAngle"]
    end

    ########## IEEE 30-bus Test Case ##########
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

    @suppress reactiveLimit!(system30, analysis)

    analysis = newtonRaphson(system30)
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
        iteration += 1
    end

    adjustAngle!(system30, analysis; slack = 1)

    @testset "IEEE 30: Iteration Number and Voltages" begin
        @test iteration == matpower30["iteration"][1]
        @test analysis.voltage.magnitude ≈ matpower30["voltageMagnitude"]
        @test analysis.voltage.angle ≈ matpower30["voltageAngle"]
    end
end