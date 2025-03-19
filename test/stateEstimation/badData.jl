system14 = powerSystem(path * "case14test.m")
system30 = powerSystem(path * "case30test.m")

@testset "AC State Estimation: Bad Data" begin
    @default(template)
    @default(unit)

    ########## IEEE 14-bus Test Case ##########
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)

    acModel!(system14)
    pf = newtonRaphson(system14)
    powerFlow!(system14, pf; power = true, current = true)

    device = measurement()
    @varmeter(label = "Varmeter ?", varianceBus = 1e-2, varianceFrom = 1e-2, varianceTo = 1e-2)
    @voltmeter(variance = 1e-2)
    @wattmeter(varianceBus = 1e-2, varianceFrom = 1e-2, varianceTo = 1e-2)

    addVoltmeter!(system14, device, pf)
    addWattmeter!(system14, device, pf)
    addVarmeter!(system14, device, pf)

    @testset "One Outlier" begin
        updateVarmeter!(system14, device; label = "Varmeter 4", reactive = 10.25)

        se = gaussNewton(system14, device)
        stateEstimation!(system14, se)

        @test chiTest(system14, device, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "Varmeter 4"
        @test outlier.maxNormalizedResidual ≈ 52.5 atol = 1e-1

        stateEstimation!(system14, se)
        compstruct(se.voltage, pf.voltage; atol = 1e-10)
    end

    @pmu(label = "PMU ?")
    @pmu(varianceMagnitudeBus = 1e-5, varianceAngleBus = 1e-5)
    @pmu(varianceMagnitudeFrom = 1e-5, varianceAngleFrom = 1e-5)
    @pmu(varianceMagnitudeTo = 1e-5, varianceAngleTo = 1e-5)

    @testset "Two Outliers" begin
        addPmu!(system14, device, pf; statusFrom = -1, statusTo = -1, polar = true)

        updateVarmeter!(system14, device; label = "Varmeter 4", status = 1)
        updatePmu!(system14, device; label = "PMU 10", magnitude = 30)

        se = gaussNewton(system14, device)
        stateEstimation!(system14, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "PMU 10"
        @test outlier.maxNormalizedResidual ≈ 7713.26 atol = 1e-1

        stateEstimation!(system14, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "Varmeter 4"
        @test outlier.maxNormalizedResidual ≈ 78.3 atol = 1e-1

        stateEstimation!(system14, se)
        compstruct(se.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "Orthogonal Method with Two Outliers" begin
        updateVarmeter!(system14, device; label = "Varmeter 4", status = 1)
        updatePmu!(system14, device; label = "PMU 10", status = 1)

        se = gaussNewton(system14, device, Orthogonal)
        stateEstimation!(system14, se)

        @test chiTest(system14, device, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "PMU 10"
        @test outlier.maxNormalizedResidual ≈ 7713.26 atol = 1e-1

        stateEstimation!(system14, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "Varmeter 4"
        @test outlier.maxNormalizedResidual ≈ 78.3 atol = 1e-1

        stateEstimation!(system14, se)
        compstruct(se.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "PMU Rectangular with One Outlier" begin
        for (key, idx) in system14.branch.label
            addPmu!(
                system14, device; from = key, magnitude = pf.current.from.magnitude[idx],
                angle = pf.current.from.angle[idx]
            )
        end
        updatePmu!(system14, device; label = "PMU 20", magnitude = 30)

        se = gaussNewton(system14, device)
        stateEstimation!(system14, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "PMU 20"
        @test outlier.maxNormalizedResidual ≈ 335.59 atol = 1e-1

        stateEstimation!(system14, se)
        compstruct(se.voltage, pf.voltage; atol = 1e-10)
    end
end

@testset "PMU State Estimation: Bad Data" begin
    @default(template)
    @default(unit)

    ########## IEEE 14-bus Test Case ##########
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)

    acModel!(system14)
    pf = newtonRaphson(system14)
    powerFlow!(system14, pf; power = true, current = true)

    device = measurement()
    @pmu(label = "PMU ?")
    @pmu(varianceMagnitudeBus = 1e-5, varianceAngleBus = 1e-5)
    @pmu(varianceMagnitudeFrom = 1e-5, varianceAngleFrom = 1e-5)
    @pmu(varianceMagnitudeTo = 1e-5, varianceAngleTo = 1e-5)

    addPmu!(system14, device, pf)

    @testset "One Outlier" begin
        updatePmu!(system14, device; label = "PMU 2", magnitude = 15)

        se = pmuStateEstimation(system14, device)
        stateEstimation!(system14, se)

        @test chiTest(system14, device, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "PMU 2"
        @test outlier.maxNormalizedResidual ≈ 2606.8 atol = 1e-1

        stateEstimation!(system14, se)
        compstruct(se.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "Two Outliers" begin
        updatePmu!(system14, device; label = "PMU 2", status = 1)
        updatePmu!(system14, device; label = "PMU 20", angle = 10pi, magnitude = 30)

        se = pmuStateEstimation(system14, device)
        stateEstimation!(system14, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "PMU 20"
        @test outlier.maxNormalizedResidual ≈ 8853.2 atol = 1e-1

        stateEstimation!(system14, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "PMU 2"
        @test outlier.maxNormalizedResidual ≈ 2606.5 atol = 1e-1

        stateEstimation!(system14, se)
        compstruct(se.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "Orthogonal Method with One Outlier" begin
        updatePmu!(system14, device; label = "PMU 2", status = 1)
        updatePmu!(
            system14, device; label = "PMU 20", magnitude = pf.current.to.magnitude[4],
            angle = pf.current.to.angle[4], status = 1
        )

        se = pmuStateEstimation(system14, device, Orthogonal)
        stateEstimation!(system14, se)

        @test chiTest(system14, device, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "PMU 2"
        @test outlier.maxNormalizedResidual ≈ 2606.8 atol = 1e-1

        stateEstimation!(system14, se)
        @test pf.voltage.magnitude ≈ se.voltage.magnitude
        @test pf.voltage.angle ≈ se.voltage.angle
    end

    @testset "Orthogonal Method with Two Outliers" begin
        updatePmu!(system14, device; label = "PMU 2", status = 1)
        updatePmu!(system14, device; label = "PMU 20", angle = 10pi, magnitude = 30)

        se = pmuStateEstimation(system14, device, Orthogonal)
        stateEstimation!(system14, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "PMU 20"
        @test outlier.maxNormalizedResidual ≈ 8853.2 atol = 1e-1

        stateEstimation!(system14, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "PMU 2"
        @test outlier.maxNormalizedResidual ≈ 2606.5 atol = 1e-1

        stateEstimation!(system14, se)
        compstruct(se.voltage, pf.voltage; atol = 1e-10)
    end
end

@testset "DC State Estimation: Bad Data" begin
    @default(template)
    @default(unit)

    ########## IEEE 14-bus Test Case ##########
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)

    dcModel!(system14)
    pf = dcPowerFlow(system14)
    powerFlow!(system14, pf; power = true)

    V = pf.voltage
    P = pf.power

    device = measurement()

    @wattmeter(label = "Wattmeter ?")
    @wattmeter(varianceBus = 1e-2, varianceFrom = 1e-2, varianceTo = 1e-2)
    @pmu(label = "PMU ?", varianceAngleBus = 1e-5)

    for (key, idx) in system14.bus.label
        addWattmeter!(system14, device; bus = key, active = P.injection.active[idx])
    end
    for (key, idx) in system14.branch.label
        addWattmeter!(system14, device; from = key, active = P.from.active[idx])
        addWattmeter!(system14, device; to = key, active = P.to.active[idx])
    end
    for (key, idx) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = 1.0, angle = V.angle[idx])
    end

    @testset "One Outlier" begin
        updateWattmeter!(system14, device; label = "Wattmeter 2", active = 100)

        se = dcStateEstimation(system14, device)
        stateEstimation!(system14, se)

        @test chiTest(system14, device, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "Wattmeter 2"
        @test outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

        stateEstimation!(system14, se)
        @test pf.voltage.angle ≈ se.voltage.angle
    end

    @testset "Two Outliers" begin
        updateWattmeter!(system14, device; label = "Wattmeter 2", status = 1)
        updatePmu!(system14, device; label = "PMU 10", angle = 10pi)

        se = dcStateEstimation(system14, device)
        stateEstimation!(system14, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "PMU 10"
        @test outlier.maxNormalizedResidual ≈ 5186.3 atol = 1e-1

        stateEstimation!(system14, se)
        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "Wattmeter 2"
        @test outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

        stateEstimation!(system14, se)
        @test pf.voltage.angle ≈ se.voltage.angle
    end

    @testset "Orthogonal Method with One Outlier" begin
        updateWattmeter!(system14, device; label = "Wattmeter 2", status = 1)
        updatePmu!(system14, device; label = "PMU 10", status = 1, angle = V.angle[10])

        se = dcStateEstimation(system14, device, Orthogonal)
        stateEstimation!(system14, se)

        @test chiTest(system14, device, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "Wattmeter 2"
        @test outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

        stateEstimation!(system14, se)
        @test pf.voltage.angle ≈ se.voltage.angle
    end

    @testset "Orthogonal Method with Two Outliers" begin
        updateWattmeter!(system14, device; label = "Wattmeter 2", status = 1)
        updatePmu!(system14, device; label = "PMU 10", angle = 10pi)

        se = dcStateEstimation(system14, device, Orthogonal)
        stateEstimation!(system14, se)

        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "PMU 10"
        @test outlier.maxNormalizedResidual ≈ 5186.3 atol = 1e-1

        stateEstimation!(system14, se)
        outlier = residualTest!(system14, device, se; threshold = 3.0)
        @test outlier.label == "Wattmeter 2"
        @test outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

        stateEstimation!(system14, se)
        @test pf.voltage.angle ≈ se.voltage.angle
    end
end