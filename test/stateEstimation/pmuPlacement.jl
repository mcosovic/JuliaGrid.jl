@testset "Optimal PMU Placement" begin
    @default(template)
    @default(unit)
    @config(label = Integer)

    ########## IEEE 14-bus Test Case ##########
    system14, monitoring14 = ems(path * "case14test.m")

    @testset "IEEE 14: Phasor Measurement Placement" begin
        placement = pmuPlacement(monitoring14, GLPK.Optimizer)

        @test collect(keys(placement.bus)) == [1; 4; 16; 7; 9]
        @test collect(keys(placement.from)) == [1; 2; 7; 8; 9; 11; 12; 13; 14; 15; 16; 17]
        @test collect(keys(placement.to)) == [4; 6; 10; 8; 9; 15]
    end

    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)
    updateBranch!(system14; label = 3, conductance = 0.01)
    updateBranch!(system14; label = 6, conductance = 0.05)
    updateBranch!(system14; label = 17, status = 0)

    acModel!(system14)
    pf = newtonRaphson(system14)
    powerFlow!(pf; current = true)

    placement = pmuPlacement(monitoring14, GLPK.Optimizer)

    for (key, idx) in placement.bus
        addPmu!(
            monitoring14; bus = key,
            magnitude = pf.voltage.magnitude[idx], angle = pf.voltage.angle[idx]
        )
    end
    for (key, idx) in placement.from
        addPmu!(
            monitoring14; from = key, magnitude = pf.current.from.magnitude[idx],
            angle = pf.current.from.angle[idx]
        )
    end
    for (key, idx) in placement.to
        addPmu!(
            monitoring14; to = key, magnitude = pf.current.to.magnitude[idx],
            angle = pf.current.to.angle[idx]
        )
    end

    @testset "IEEE 14: PMU State Estimation" begin
        se = pmuStateEstimation(monitoring14, LU)
        stateEstimation!(se)
        teststruct(se.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "IEEE 14: Wrapper PMU Placement" begin
        pmu = measurement(system14)
        pmuPlacement!(pmu, pf, GLPK.Optimizer)
        teststruct(pmu.pmu, monitoring14.pmu)
    end

    ########## IEEE 30-bus Test Case ##########
    system30, monitoring30 = ems(path * "case30test.m")

    acModel!(system30)
    pf = newtonRaphson(system30)
    powerFlow!( pf; current = true)

    placement = pmuPlacement(monitoring30, GLPK.Optimizer)

    for (key, idx) in placement.bus
        addPmu!(
            monitoring30; bus = key, magnitude = pf.voltage.magnitude[idx], angle = pf.voltage.angle[idx]
        )
    end
    for (key, idx) in placement.from
        addPmu!(
            monitoring30; from = key, magnitude = pf.current.from.magnitude[idx],
            angle = pf.current.from.angle[idx]
        )
    end
    for (key, idx) in placement.to
        addPmu!(
            monitoring30; to = key, magnitude = pf.current.to.magnitude[idx], angle = pf.current.to.angle[idx]
        )
    end

    @testset "IEEE 30: PMU State Estimation" begin
        se = pmuStateEstimation(monitoring30, LU)
        stateEstimation!(se)
        teststruct(se.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "IEEE 30: Wrapper PMU Placement" begin
        pmu = measurement(system30)
        pmuPlacement!(pmu, pf, GLPK.Optimizer)
        teststruct(pmu.pmu, monitoring30.pmu)
    end
end

@testset "Optimal PMU Placement with SCADA Measurements" begin
    system, monitoring = ems()

    addBus!(system; label = 1, type = 3, susceptance = 0.5)
    addBus!(system; label = 2, type = 1, active = 0.2)
    addBus!(system; label = 3, type = 2, active = 0.2)
    addBus!(system; label = 4, type = 1, active = 0.2)
    addBus!(system; label = 5, type = 1, active = 0.2)
    addBus!(system; label = 6, type = 1, active = 0.2)
    addBus!(system; label = 7, type = 1, active = 0.2)

    addBranch!(system; from = 1, to = 2, resistance = 0.1, reactance = 0.05)
    addBranch!(system; from = 2, to = 3, resistance = 0.1,  reactance = 0.05)
    addBranch!(system; from = 2, to = 6, resistance = 0.1,  reactance = 0.05)
    addBranch!(system; from = 2, to = 7, resistance = 0.1,  reactance = 0.05)
    addBranch!(system; from = 3, to = 4, resistance = 0.1,  reactance = 0.05)
    addBranch!(system; from = 3, to = 6, resistance = 0.1,  reactance = 0.05)
    addBranch!(system; from = 4, to = 5, resistance = 0.1,  reactance = 0.05)
    addBranch!(system; from = 4, to = 7, resistance = 0.1,  reactance = 0.05)

    addGenerator!(system; bus = 1, active = 2.1, reactive = 0.2)
    addGenerator!(system; bus = 3, active = 0.6, reactive = 0.3)

    addWattmeter!(monitoring; bus = 2, active = -0.2)
    addWattmeter!(monitoring; from = 2, active = 0.0699428)

    @testset "Phasor Measurement Placement" begin
        placement = pmuPlacement(monitoring, HiGHS.Optimizer; scada = true)

        @test collect(keys(placement.bus)) == [3; 4]
        @test collect(keys(placement.from)) == [5; 6; 7; 8]
        @test collect(keys(placement.to)) == [2; 5]
    end

    pf = newtonRaphson(system)
    powerFlow!(pf; power = true)

    @testset "Wrapper PMU Placement" begin
        pmuPlacement!(monitoring, pf, GLPK.Optimizer)
        se = gaussNewton(monitoring)
        stateEstimation!(se)
        teststruct(se.voltage, pf.voltage; atol = 1e-10)
    end
end