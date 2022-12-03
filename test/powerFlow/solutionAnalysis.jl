@testset "dcPowerFlow, dcModel, bus, branch, generator" begin
    pathData = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/data/")

    system14 = powerSystem(string(pathData, "case14test.h5"))
    system30 = powerSystem(string(pathData, "case30test.h5"))

    matpower14 = h5read(string(pathData, "case14testPowerFlowResult.h5"), "/dc")
    matpower30 = h5read(string(pathData, "case30testPowerFlowResult.h5"), "/dc")

    torad = pi / 180

    ######## Modified IEEE 14-bus Test Case ##########
    dcModel!(system14)
    result = dcPowerFlow(system14)
    branch!(system14, result)
    bus!(system14, result)
    generator!(system14, result)

    topu = 1 / (1e-6 * system14.basePower)
    @test result.bus.voltage.angle ≈ matpower14["Ti"] * torad
    @test result.bus.power.injection.active ≈ matpower14["Pinj"] * topu
    @test result.bus.power.injection.active ≈ result.bus.power.supply.active - system14.bus.demand.active
    @test result.branch.power.from.active ≈ matpower14["Pij"] * topu
    @test result.generator.power.active ≈ matpower14["Pgen"] * topu

    ######## Modified IEEE 30-bus Test Case ##########
    dcModel!(system30)
    result = dcPowerFlow(system30)
    branch!(system30, result)
    bus!(system30, result)
    generator!(system30, result)

    topu = 1 / (1e-6 * system30.basePower)
    @test result.bus.voltage.angle ≈ matpower30["Ti"] * torad
    @test result.bus.power.injection.active ≈ matpower30["Pinj"] * topu
    @test result.bus.power.injection.active ≈ result.bus.power.supply.active - system30.bus.demand.active
    @test result.branch.power.from.active ≈ matpower30["Pij"] * topu
    @test result.generator.power.active ≈ matpower30["Pgen"] * topu
end