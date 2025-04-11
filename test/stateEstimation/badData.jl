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
    powerFlow!(pf; power = true, current = true)

    monitoring = measurement(system14)
    @varmeter(label = "Varmeter ?", varianceBus = 1e-2, varianceFrom = 1e-2, varianceTo = 1e-2)
    @voltmeter(variance = 1e-2)
    @wattmeter(varianceBus = 1e-2, varianceFrom = 1e-2, varianceTo = 1e-2)

    addVoltmeter!(monitoring, pf)
    addWattmeter!(monitoring, pf)
    addVarmeter!(monitoring, pf)

    @testset "One Outlier" begin
        updateVarmeter!(monitoring; label = "Varmeter 4", reactive = 10.25)

        se = gaussNewton(monitoring)
        stateEstimation!(se)

        chi = chiTest(se)
        @test chi.detect
        @test chi.treshold ≈ 109.7 atol = 1e-1
        @test chi.objective ≈ 3227.3 atol = 1e-1

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "Varmeter 4"
        @test outlier.maxNormalizedResidual ≈ 52.5 atol = 1e-1

        stateEstimation!(se)
        teststruct(se.voltage, pf.voltage; atol = 1e-10)
    end

    @pmu(label = "PMU ?")
    @pmu(varianceMagnitudeBus = 1e-5, varianceAngleBus = 1e-5)
    @pmu(varianceMagnitudeFrom = 1e-5, varianceAngleFrom = 1e-5)
    @pmu(varianceMagnitudeTo = 1e-5, varianceAngleTo = 1e-5)

    @testset "Two Outliers" begin
        addPmu!(monitoring, pf; statusFrom = -1, statusTo = -1, polar = true)

        updateVarmeter!(monitoring; label = "Varmeter 4", status = 1)
        updatePmu!(monitoring; label = "PMU 10", magnitude = 30)

        se = gaussNewton(monitoring)
        stateEstimation!(se)

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "PMU 10"
        @test outlier.maxNormalizedResidual ≈ 7713.26 atol = 1e-1

        stateEstimation!(se)

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "Varmeter 4"
        @test outlier.maxNormalizedResidual ≈ 78.3 atol = 1e-1

        stateEstimation!(se)
        teststruct(se.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "Orthogonal Method with Two Outliers" begin
        updateVarmeter!(monitoring; label = "Varmeter 4", status = 1)
        updatePmu!(monitoring; label = "PMU 10", status = 1)

        se = gaussNewton(monitoring, Orthogonal)
        stateEstimation!(se)

        chi = chiTest(se)
        @test chi.detect

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "PMU 10"
        @test outlier.maxNormalizedResidual ≈ 7713.26 atol = 1e-1

        stateEstimation!(se)

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "Varmeter 4"
        @test outlier.maxNormalizedResidual ≈ 78.3 atol = 1e-1

        stateEstimation!(se)
        teststruct(se.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "PMU Rectangular with One Outlier" begin
        for (key, idx) in system14.branch.label
            addPmu!(
                monitoring; from = key, magnitude = pf.current.from.magnitude[idx],
                angle = pf.current.from.angle[idx]
            )
        end
        updatePmu!(monitoring; label = "PMU 20", magnitude = 30)

        se = gaussNewton(monitoring)
        stateEstimation!(se)

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "PMU 20"
        @test outlier.maxNormalizedResidual ≈ 335.59 atol = 1e-1

        stateEstimation!(se)
        teststruct(se.voltage, pf.voltage; atol = 1e-10)
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
    powerFlow!(pf; power = true, current = true)

    monitoring = measurement(system14)
    @pmu(label = "PMU ?")
    @pmu(varianceMagnitudeBus = 1e-5, varianceAngleBus = 1e-5)
    @pmu(varianceMagnitudeFrom = 1e-5, varianceAngleFrom = 1e-5)
    @pmu(varianceMagnitudeTo = 1e-5, varianceAngleTo = 1e-5)

    addPmu!(monitoring, pf)

    @testset "One Outlier" begin
        updatePmu!(monitoring; label = "PMU 2", magnitude = 15)

        se = pmuStateEstimation(monitoring)
        stateEstimation!(se)

        chi = chiTest(se)
        @test chi.detect

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "PMU 2"
        @test outlier.maxNormalizedResidual ≈ 2606.8 atol = 1e-1

        stateEstimation!(se)
        teststruct(se.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "Two Outliers" begin
        updatePmu!(monitoring; label = "PMU 2", status = 1)
        updatePmu!(monitoring; label = "PMU 20", angle = 10pi, magnitude = 30)

        se = pmuStateEstimation(monitoring)
        stateEstimation!(se)

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "PMU 20"
        @test outlier.maxNormalizedResidual ≈ 8853.2 atol = 1e-1

        stateEstimation!(se)

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "PMU 2"
        @test outlier.maxNormalizedResidual ≈ 2606.5 atol = 1e-1

        stateEstimation!(se)
        teststruct(se.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "Orthogonal Method with One Outlier" begin
        updatePmu!(monitoring; label = "PMU 2", status = 1)
        updatePmu!(
            monitoring; label = "PMU 20", magnitude = pf.current.to.magnitude[4],
            angle = pf.current.to.angle[4], status = 1
        )

        se = pmuStateEstimation(monitoring, Orthogonal)
        stateEstimation!(se)

        chi = chiTest(se)
        @test chi.detect

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "PMU 2"
        @test outlier.maxNormalizedResidual ≈ 2606.8 atol = 1e-1

        stateEstimation!(se)
        @test pf.voltage.magnitude ≈ se.voltage.magnitude
        @test pf.voltage.angle ≈ se.voltage.angle
    end

    @testset "Orthogonal Method with Two Outliers" begin
        updatePmu!(monitoring; label = "PMU 2", status = 1)
        updatePmu!(monitoring; label = "PMU 20", angle = 10pi, magnitude = 30)

        se = pmuStateEstimation(monitoring, Orthogonal)
        stateEstimation!(se)

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "PMU 20"
        @test outlier.maxNormalizedResidual ≈ 8853.2 atol = 1e-1

        stateEstimation!(se)

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "PMU 2"
        @test outlier.maxNormalizedResidual ≈ 2606.5 atol = 1e-1

        stateEstimation!(se)
        teststruct(se.voltage, pf.voltage; atol = 1e-10)
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
    powerFlow!(pf; power = true)

    V = pf.voltage
    P = pf.power

    monitoring = measurement(system14)

    @wattmeter(label = "Wattmeter ?")
    @wattmeter(varianceBus = 1e-2, varianceFrom = 1e-2, varianceTo = 1e-2)
    @pmu(label = "PMU ?", varianceAngleBus = 1e-5)

    for (key, idx) in system14.bus.label
        addWattmeter!(monitoring; bus = key, active = P.injection.active[idx])
    end
    for (key, idx) in system14.branch.label
        addWattmeter!(monitoring; from = key, active = P.from.active[idx])
        addWattmeter!(monitoring; to = key, active = P.to.active[idx])
    end
    for (key, idx) in system14.bus.label
        addPmu!(monitoring; bus = key, magnitude = 1.0, angle = V.angle[idx])
    end

    @testset "One Outlier" begin
        updateWattmeter!(monitoring; label = "Wattmeter 2", active = 100)

        se = dcStateEstimation(monitoring)
        stateEstimation!(se)

        chi = chiTest(se)
        @test chi.detect

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "Wattmeter 2"
        @test outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

        stateEstimation!(se)
        @test pf.voltage.angle ≈ se.voltage.angle
    end

    @testset "Two Outliers" begin
        updateWattmeter!(monitoring; label = "Wattmeter 2", status = 1)
        updatePmu!(monitoring; label = "PMU 10", angle = 10pi)

        se = dcStateEstimation(monitoring)
        stateEstimation!(se)

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "PMU 10"
        @test outlier.maxNormalizedResidual ≈ 5186.3 atol = 1e-1

        stateEstimation!(se)
        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "Wattmeter 2"
        @test outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

        stateEstimation!(se)
        @test pf.voltage.angle ≈ se.voltage.angle
    end

    @testset "Orthogonal Method with One Outlier" begin
        updateWattmeter!(monitoring; label = "Wattmeter 2", status = 1)
        updatePmu!(monitoring; label = "PMU 10", status = 1, angle = V.angle[10])

        se = dcStateEstimation(monitoring, Orthogonal)
        stateEstimation!(se)

        chi = chiTest(se)
        @test chi.detect

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "Wattmeter 2"
        @test outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

        stateEstimation!(se)
        @test pf.voltage.angle ≈ se.voltage.angle
    end

    @testset "Orthogonal Method with Two Outliers" begin
        updateWattmeter!(monitoring; label = "Wattmeter 2", status = 1)
        updatePmu!(monitoring; label = "PMU 10", angle = 10pi)

        se = dcStateEstimation(monitoring, Orthogonal)
        stateEstimation!(se)

        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "PMU 10"
        @test outlier.maxNormalizedResidual ≈ 5186.3 atol = 1e-1

        stateEstimation!(se)
        outlier = residualTest!(se; threshold = 3.0)
        @test outlier.label == "Wattmeter 2"
        @test outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

        stateEstimation!(se)
        @test pf.voltage.angle ≈ se.voltage.angle
    end
end