system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "DC Optimal Power Flow" begin
    matpower14 = h5read(string(pathData, "results.h5"), "case14test/dcOptimalPowerFlow")
    matpower30 = h5read(string(pathData, "results.h5"), "case30test/dcOptimalPowerFlow")

    ######## Modified IEEE 14-bus Test Case ##########
    dcModel!(system14)
    analysis = dcOptimalPowerFlow(system14, Ipopt.Optimizer)
    solve!(system14, analysis)
    power!(system14, analysis)

    @test analysis.voltage.angle ≈ matpower14["voltage"] atol = 1e-6
    @test analysis.power.injection.active ≈ matpower14["injection"] atol = 1e-6
    @test analysis.power.supply.active ≈ matpower14["supply"] atol = 1e-6
    @test analysis.power.from.active ≈ matpower14["from"] atol = 1e-6
    @test analysis.power.to.active ≈ -matpower14["from"] atol = 1e-6
    @test analysis.power.generator.active ≈ matpower14["generator"] atol = 1e-6

    for (key, value) in system14.bus.label
        @test powerInjection(system14, analysis; label = key) ≈ matpower14["injection"][value] atol = 1e-6
        @test powerSupply(system14, analysis; label = key) ≈ matpower14["supply"][value] atol = 1e-6
    end

    for (key, value) in system14.branch.label
        @test powerFrom(system14, analysis; label = key) ≈ matpower14["from"][value] atol = 1e-6
        @test powerTo(system14, analysis; label = key) ≈ -matpower14["from"][value] atol = 1e-6
    end

    for (key, value) in system14.generator.label
        @test powerGenerator(system14, analysis; label = key) ≈ matpower14["generator"][value] atol = 1e-6
    end

    ######## Modified IEEE 30-bus Test Case ##########
    dcModel!(system30)
    analysis = dcOptimalPowerFlow(system30, HiGHS.Optimizer)
    solve!(system30, analysis)
    power!(system30, analysis)

    @test analysis.voltage.angle ≈ matpower30["voltage"] atol = 1e-10
    @test analysis.power.injection.active ≈ matpower30["injection"] atol = 1e-6
    @test analysis.power.supply.active ≈ matpower30["supply"] atol = 1e-10
    @test analysis.power.from.active ≈ matpower30["from"] atol = 1e-10
    @test analysis.power.to.active ≈ -matpower30["from"] atol = 1e-10
    @test analysis.power.generator.active ≈ matpower30["generator"] atol = 1e-10

    for (key, value) in system30.bus.label
        @test powerInjection(system30, analysis; label = key) ≈ matpower30["injection"][value] atol = 1e-6
        @test powerSupply(system30, analysis; label = key) ≈ matpower30["supply"][value] atol = 1e-10
    end

    for (key, value) in system30.branch.label
        @test powerFrom(system30, analysis; label = key) ≈ matpower30["from"][value] atol = 1e-10
        @test powerTo(system30, analysis; label = key) ≈ -matpower30["from"][value] atol = 1e-10
    end

    for (key, value) in system30.generator.label
        @test powerGenerator(system30, analysis; label = key) ≈ matpower30["generator"][value] atol = 1e-10
    end
end