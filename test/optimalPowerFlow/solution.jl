system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))
torad = pi / 180

@testset "dcOptimalPowerFlow" begin
    matpower14 = h5read(string(pathData, "case14testResult.h5"), "/dcOptimal")
    matpower30 = h5read(string(pathData, "case30testResult.h5"), "/dcOptimal")

    ######## Modified IEEE 14-bus Test Case ##########
    dcModel!(system14)

    model = Model(Ipopt.Optimizer)
    dcOptimalPowerFlow!(system14, model)
    result = optimizePowerFlow!(system14, model)
    
    @test result.bus.voltage.angle ≈ matpower14["Ti"] * torad

    ######## Modified IEEE 30-bus Test Case ##########
    dcModel!(system30)
    model = Model(HiGHS.Optimizer)

    dcOptimalPowerFlow!(system30, model)
    result = optimizePowerFlow!(system30, model)
    result.bus.voltage.angle[1] = 0.0
    
    @test result.bus.voltage.angle ≈ matpower30["Ti"] * torad
end