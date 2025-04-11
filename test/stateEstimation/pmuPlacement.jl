system14 = powerSystem(path * "case14test.m")
system30 = powerSystem(path * "case30test.m")
@testset "Optimal PMU Placement" begin
    @default(template)
    @default(unit)

    ########## IEEE 14-bus Test Case ##########
    @testset "IEEE 14: Phasor Measurement Placement" begin
        placement = pmuPlacement(system14, GLPK.Optimizer)

        @test collect(keys(placement.bus)) == ["1"; "4"; "16"; "7"; "9"]
        @test collect(keys(placement.from)) ==
            ["1"; "2"; "7"; "8"; "9"; "11"; "12"; "13"; "14"; "15"; "16"; "17"]
        @test collect(keys(placement.to)) == ["4"; "6"; "10"; "8"; "9"; "15"]
    end

    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)
    updateBranch!(system14; label = 3, conductance = 0.01)
    updateBranch!(system14; label = 6, conductance = 0.05)
    updateBranch!(system14; label = 17, status = 0)

    acModel!(system14)
    pf = newtonRaphson(system14)
    powerFlow!(pf; current = true)

    placement = pmuPlacement(system14, GLPK.Optimizer)

    monitoring = measurement(system14)
    for (key, idx) in placement.bus
        addPmu!(
            monitoring; bus = key,
            magnitude = pf.voltage.magnitude[idx], angle = pf.voltage.angle[idx]
        )
    end
    for (key, idx) in placement.from
        addPmu!(
            monitoring; from = key, magnitude = pf.current.from.magnitude[idx],
            angle = pf.current.from.angle[idx]
        )
    end
    for (key, idx) in placement.to
        addPmu!(
            monitoring; to = key, magnitude = pf.current.to.magnitude[idx],
            angle = pf.current.to.angle[idx]
        )
    end

    @testset "IEEE 14: PMU State Estimation" begin
        se = pmuStateEstimation(monitoring, LU)
        stateEstimation!(se)
        teststruct(se.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "IEEE 14: Wrapper PMU Placement" begin
        pmu = measurement(system14)
        pmuPlacement!(pmu, pf, GLPK.Optimizer)
        teststruct(pmu.pmu, monitoring.pmu)
    end

    ########## IEEE 30-bus Test Case ##########
    acModel!(system30)
    pf = newtonRaphson(system30)
    powerFlow!( pf; current = true)

    placement = pmuPlacement(system30, GLPK.Optimizer)

    monitoring = measurement(system30)
    for (key, idx) in placement.bus
        addPmu!(
            monitoring; bus = key, magnitude = pf.voltage.magnitude[idx], angle = pf.voltage.angle[idx]
        )
    end
    for (key, idx) in placement.from
        addPmu!(
            monitoring; from = key, magnitude = pf.current.from.magnitude[idx],
            angle = pf.current.from.angle[idx]
        )
    end
    for (key, idx) in placement.to
        addPmu!(
            monitoring; to = key, magnitude = pf.current.to.magnitude[idx], angle = pf.current.to.angle[idx]
        )
    end

    @testset "IEEE 30: PMU State Estimation" begin
        se = pmuStateEstimation(monitoring, LU)
        stateEstimation!(se)
        teststruct(se.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "IEEE 30: Wrapper PMU Placement" begin
        pmu = measurement(system30)
        pmuPlacement!(pmu, pf, GLPK.Optimizer)
        teststruct(pmu.pmu, monitoring.pmu)
    end
end