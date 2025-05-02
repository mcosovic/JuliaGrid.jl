system14 = powerSystem(path * "case14test.m")
system30 = powerSystem(path * "case30test.m")

@testset "Newton-Raphson Method with Reactive Power Limits" begin
    matpower14 = h5read(path * "results.h5", "case14test/reactiveLimit/newtonRaphson")
    matpower30 = h5read(path * "results.h5", "case30test/reactiveLimit/newtonRaphson")

    ########## IEEE 14-bus Test Case ##########
    acModel!(system14)
    analysis = newtonRaphson(system14)
    powerFlow!(analysis)
    iteration = copy(analysis.method.iteration)

    reactiveLimit!(analysis)

    analysis = newtonRaphson(system14)
    powerFlow!(analysis)
    analysis.method.iteration += iteration

    adjustAngle!(analysis; slack = "Bus 1 HV")

    @testset "IEEE 14: Matpower" begin
        testVoltage(matpower14, analysis)
    end

    ########## IEEE 30-bus Test Case ##########
    acModel!(system30)
    analysis = newtonRaphson(system30)
    powerFlow!(analysis)
    iteration = copy(analysis.method.iteration)

    @suppress reactiveLimit!(analysis)

    analysis = newtonRaphson(system30)
    powerFlow!(analysis)
    analysis.method.iteration += iteration

    adjustAngle!(analysis; slack = 1)

    @testset "IEEE 30: Matpower" begin
        testVoltage(matpower30, analysis)
    end
end