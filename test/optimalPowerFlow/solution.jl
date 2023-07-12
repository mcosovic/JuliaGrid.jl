system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "DC Optimal Power Flow" begin
    field = "/dcOptimalPowerFlow"
    matpower14 = h5read(string(pathData, "case14testResult.h5"), field)
    matpower30 = h5read(string(pathData, "case30testResult.h5"), field)

    ######## Modified IEEE 14-bus Test Case ##########
    dcModel!(system14)
    model = dcOptimalPowerFlow(system14, HiGHS.Optimizer)
    solve!(system14, model)

    @test model.voltage.angle ≈ matpower14["Ti"] atol = 1e-10
    @test model.power.active ≈ matpower14["Pgen"] atol = 1e-10

    ######## Modified IEEE 30-bus Test Case ##########
    dcModel!(system30)
    model = dcOptimalPowerFlow(system30, HiGHS.Optimizer)
    solve!(system30, model)

    @test model.voltage.angle ≈ matpower30["Ti"] atol = 1e-10
    @test model.power.active ≈ matpower30["Pgen"] atol = 1e-10
end