system14 = powerSystem(path * "case14test.m")
system30 = powerSystem(path * "case30test.m")

@testset "Newton-Raphson Method with Reactive Power Limits" begin
    matpower14 = h5read(path * "results.h5", "case14test/reactiveLimit/newtonRaphson")
    matpower30 = h5read(path * "results.h5", "case30test/reactiveLimit/newtonRaphson")

    ########## IEEE 14-bus Test Case ##########
    acModel!(system14)
    analysis = newtonRaphson(system14)
    powerFlow!(system14, analysis)
    iteration = copy(analysis.method.iteration)

    reactiveLimit!(system14, analysis)

    analysis = newtonRaphson(system14)
    analysis.method.iteration = iteration
    powerFlow!(system14, analysis)

    adjustAngle!(system14, analysis; slack = 1)

    @testset "IEEE 14: Matpower" begin
        testVoltageMatpower(matpower14, analysis)
    end

    ########## IEEE 30-bus Test Case ##########
    acModel!(system30)
    analysis = newtonRaphson(system30)
    powerFlow!(system30, analysis)
    iteration = copy(analysis.method.iteration)

    @suppress reactiveLimit!(system30, analysis)

    analysis = newtonRaphson(system30)
    analysis.method.iteration = iteration
    powerFlow!(system30, analysis)

    adjustAngle!(system30, analysis; slack = 1)

    @testset "IEEE 30: Matpower" begin
        testVoltageMatpower(matpower30, analysis)
    end
end