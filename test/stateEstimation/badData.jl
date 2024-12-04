system14 = powerSystem(path * "case14test.m")
system30 = powerSystem(path * "case30test.m")

@testset "AC State Estimation: Bad Data" begin
    @default(template)
    @default(unit)

    ########## IEEE 14-bus Test Case ##########
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)

    acModel!(system14)
    analysis = newtonRaphson(system14)
    for i = 1:1000
        stopping = mismatch!(system14, analysis)
        if all(stopping .< 1e-12)
            break
        end
        solve!(system14, analysis)
    end
    power!(system14, analysis)
    current!(system14, analysis)

    device = measurement()
    @varmeter(label = "Varmeter ?")
    for (key, idx) in system14.bus.label
        addVoltmeter!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx]
        )
        addWattmeter!(
            system14, device; bus = key, active = analysis.power.injection.active[idx]
        )
        addVarmeter!(
            system14, device; bus = key, reactive = analysis.power.injection.reactive[idx]
        )
    end

    for (key, idx) in system14.branch.label
        addWattmeter!(system14, device; from = key, active = analysis.power.from.active[idx])
        addWattmeter!(system14, device; to = key, active = analysis.power.to.active[idx])
        addVarmeter!(system14, device; from = key, reactive = analysis.power.from.reactive[idx])
        addVarmeter!(system14, device; to = key, reactive = analysis.power.to.reactive[idx])
    end

    @testset "One Outlier" begin
        updateVarmeter!(system14, device; label = "Varmeter 4", reactive = 10.25)

        analysisSE = gaussNewton(system14, device)
        for iteration = 1:20
            stopping = solve!(system14, analysisSE)
            if stopping < 1e-8
                break
            end
        end
        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "Varmeter 4"
        @test outlier.maxNormalizedResidual ≈ 52.5 atol = 1e-1

        analysisSE = gaussNewton(system14, device)
        for iteration = 1:20
            stopping = solve!(system14, analysisSE)
            if stopping < 1e-8
                break
            end
        end
        compstruct(analysisSE.voltage, analysis.voltage; atol = 1e-10)
    end

    @testset "Two Outliers" begin
        @pmu(label = "PMU ?")
        for (key, idx) in system14.bus.label
            addPmu!(
                system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
                angle = analysis.voltage.angle[idx], polar = true
            )
        end

        updateVarmeter!(system14, device; label = "Varmeter 4", status = 1)
        updatePmu!(system14, device; label = "PMU 10", magnitude = 30)

        analysisSE = gaussNewton(system14, device)
        for iteration = 1:20
            stopping = solve!(system14, analysisSE)
            if stopping < 1e-8
                break
            end
        end
        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "PMU 10"
        @test outlier.maxNormalizedResidual ≈ 7713.26 atol = 1e-1

        analysisSE = gaussNewton(system14, device)
        for iteration = 1:20
            stopping = solve!(system14, analysisSE)
            if stopping < 1e-8
                break
            end
        end
        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "Varmeter 4"
        @test outlier.maxNormalizedResidual ≈ 78.3 atol = 1e-1

        analysisSE = gaussNewton(system14, device)
        for iteration = 1:20
            stopping = solve!(system14, analysisSE)
            if stopping < 1e-8
                break
            end
        end
        @test analysis.voltage.magnitude ≈ analysisSE.voltage.magnitude
        @test analysis.voltage.angle ≈ analysisSE.voltage.angle
    end

    @testset "Orthogonal Method with Two Outliers" begin
        updateVarmeter!(system14, device; label = "Varmeter 4", status = 1)
        updatePmu!(system14, device; label = "PMU 10", statusMagnitude = 1)

        analysisSE = gaussNewton(system14, device, Orthogonal)
        for iteration = 1:20
            stopping = solve!(system14, analysisSE)
            if stopping < 1e-8
                break
            end
        end
        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "PMU 10"
        @test outlier.maxNormalizedResidual ≈ 7713.26 atol = 1e-1

        analysisSE = gaussNewton(system14, device, Orthogonal)
        for iteration = 1:20
            stopping = solve!(system14, analysisSE)
            if stopping < 1e-8
                break
            end
        end
        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "Varmeter 4"
        @test outlier.maxNormalizedResidual ≈ 78.3 atol = 1e-1

        analysisSE = gaussNewton(system14, device, Orthogonal)
        for iteration = 1:20
            stopping = solve!(system14, analysisSE)
            if stopping < 1e-8
                break
            end
        end
        compstruct(analysisSE.voltage, analysis.voltage; atol = 1e-10)
    end

    @testset "PMU Rectangular with One Outlier" begin
        for (key, idx) in system14.branch.label
            addPmu!(
                system14, device; from = key, magnitude = analysis.current.from.magnitude[idx],
                angle = analysis.current.from.angle[idx]
            )
        end
        updatePmu!(system14, device; label = "PMU 20", magnitude = 30)

        analysisSE = gaussNewton(system14, device)
        for iteration = 1:20
            stopping = solve!(system14, analysisSE)
            if stopping < 1e-8
                break
            end
        end
        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "PMU 20"
        @test outlier.maxNormalizedResidual ≈ 335.59 atol = 1e-1

        analysisSE = gaussNewton(system14, device)
        for iteration = 1:20
            stopping = solve!(system14, analysisSE)
            if stopping < 1e-8
                break
            end
        end
        compstruct(analysisSE.voltage, analysis.voltage; atol = 1e-10)
    end
end

@testset "PMU State Estimation: Bad Data" begin
    @default(template)
    @default(unit)

    ########## IEEE 14-bus Test Case ##########
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)

    acModel!(system14)
    analysis = newtonRaphson(system14)
    for i = 1:1000
        stopping = mismatch!(system14, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, analysis)
    end
    power!(system14, analysis)
    current!(system14, analysis)

    device = measurement()
    @pmu(label = "PMU ?")
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx]
        )
    end
    for (key, idx) in system14.branch.label
        addPmu!(
            system14, device; from = key, magnitude = analysis.current.from.magnitude[idx],
            angle = analysis.current.from.angle[idx]
        )
        addPmu!(
            system14, device; to = key, magnitude = analysis.current.to.magnitude[idx],
            angle = analysis.current.to.angle[idx]
        )
    end

    @testset "One Outlier" begin
        updatePmu!(system14, device; label = "PMU 2", magnitude = 15)
        analysisSE = pmuStateEstimation(system14, device)
        solve!(system14, analysisSE)

        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "PMU 2"
        @test outlier.maxNormalizedResidual ≈ 2606.8 atol = 1e-1

        solve!(system14, analysisSE)
        compstruct(analysisSE.voltage, analysis.voltage; atol = 1e-10)
    end

    @testset "Two Outliers" begin
        updatePmu!(system14, device; label = "PMU 2", statusAngle = 1, statusMagnitude = 1)
        updatePmu!(system14, device; label = "PMU 20", angle = 10pi, magnitude = 30)
        analysisSE = pmuStateEstimation(system14, device)
        solve!(system14, analysisSE)

        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "PMU 20"
        @test outlier.maxNormalizedResidual ≈ 8853.2 atol = 1e-1

        solve!(system14, analysisSE)
        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "PMU 2"
        @test outlier.maxNormalizedResidual ≈ 2606.5 atol = 1e-1

        solve!(system14, analysisSE)
        compstruct(analysisSE.voltage, analysis.voltage; atol = 1e-10)
    end

    @testset "Orthogonal Method with One Outlier" begin
        updatePmu!(system14, device; label = "PMU 2", statusAngle = 1, statusMagnitude = 1)
        updatePmu!(
            system14, device; label = "PMU 20", magnitude = analysis.current.to.magnitude[4],
            angle = analysis.current.to.angle[4], statusAngle = 1, statusMagnitude = 1
        )
        analysisSE = pmuStateEstimation(system14, device, Orthogonal)
        solve!(system14, analysisSE)

        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "PMU 2"
        @test outlier.maxNormalizedResidual ≈ 2606.8 atol = 1e-1

        solve!(system14, analysisSE)
        @test analysis.voltage.magnitude ≈ analysisSE.voltage.magnitude
        @test analysis.voltage.angle ≈ analysisSE.voltage.angle
    end

    @testset "Orthogonal Method with Two Outliers" begin
        updatePmu!(system14, device; label = "PMU 2", statusAngle = 1, statusMagnitude = 1)
        updatePmu!(system14, device; label = "PMU 20", angle = 10pi, magnitude = 30)
        analysisSE = pmuStateEstimation(system14, device, Orthogonal)
        solve!(system14, analysisSE)

        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "PMU 20"
        @test outlier.maxNormalizedResidual ≈ 8853.2 atol = 1e-1

        solve!(system14, analysisSE)
        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "PMU 2"
        @test outlier.maxNormalizedResidual ≈ 2606.5 atol = 1e-1

        solve!(system14, analysisSE)
        compstruct(analysisSE.voltage, analysis.voltage; atol = 1e-10)
    end
end

@testset "DC State Estimation: Bad Data" begin
    @default(template)
    @default(unit)

    ########## IEEE 14-bus Test Case ##########
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)

    dcModel!(system14)
    analysis = dcPowerFlow(system14)
    solve!(system14, analysis)
    power!(system14, analysis)
    device = measurement()

    @wattmeter(label = "Wattmeter ?")
    @pmu(label = "PMU ?")
    for (key, idx) in system14.bus.label
        addWattmeter!(
            system14, device; bus = key, active = analysis.power.injection.active[idx]
        )
    end
    for (key, idx) in system14.branch.label
        addWattmeter!(
            system14, device; from = key, active = analysis.power.from.active[idx]
        )
        addWattmeter!(
            system14, device; to = key, active = analysis.power.to.active[idx]
        )
    end
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device;
            bus = key, magnitude = 1.0, angle = analysis.voltage.angle[idx]
        )
    end

    @testset "One Outlier" begin
        updateWattmeter!(system14, device; label = "Wattmeter 2", active = 100)
        analysisSE = dcStateEstimation(system14, device)
        solve!(system14, analysisSE)

        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "Wattmeter 2"
        @test outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

        solve!(system14, analysisSE)
        @test analysis.voltage.angle ≈ analysisSE.voltage.angle
    end

    @testset "Two Outliers" begin
        updateWattmeter!(system14, device; label = "Wattmeter 2", status = 1)
        updatePmu!(system14, device; label = "PMU 10", angle = 10pi)
        analysisSE = dcStateEstimation(system14, device)
        solve!(system14, analysisSE)

        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "PMU 10"
        @test outlier.maxNormalizedResidual ≈ 5186.3 atol = 1e-1

        solve!(system14, analysisSE)
        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "Wattmeter 2"
        @test outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

        solve!(system14, analysisSE)
        @test analysis.voltage.angle ≈ analysisSE.voltage.angle
    end

    @testset "Orthogonal Method with One Outlier" begin
        updateWattmeter!(system14, device; label = "Wattmeter 2", status = 1)
        updatePmu!(
            system14, device;
            label = "PMU 10", statusAngle = 1, angle = analysis.voltage.angle[10]
        )
        analysisSE = dcStateEstimation(system14, device, Orthogonal)
        solve!(system14, analysisSE)

        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "Wattmeter 2"
        @test outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

        solve!(system14, analysisSE)
        @test analysis.voltage.angle ≈ analysisSE.voltage.angle
    end

    @testset "Orthogonal Method with Two Outliers" begin
        updateWattmeter!(system14, device; label = "Wattmeter 2", status = 1)
        updatePmu!(system14, device; label = "PMU 10", angle = 10pi)
        analysisSE = dcStateEstimation(system14, device, Orthogonal)
        solve!(system14, analysisSE)

        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "PMU 10"
        @test outlier.maxNormalizedResidual ≈ 5186.3 atol = 1e-1

        solve!(system14, analysisSE)
        outlier = residualTest!(system14, device, analysisSE; threshold = 3.0)
        @test outlier.label == "Wattmeter 2"
        @test outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

        solve!(system14, analysisSE)
        @test analysis.voltage.angle ≈ analysisSE.voltage.angle
    end
end