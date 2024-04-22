system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "AC State Estimation: Bad Data" begin
    @default(template)
    @default(unit)

    ############### Modified IEEE 14-bus Test Case ################
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
    for (key, value) in system14.bus.label
        addVoltmeter!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value])
        addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[value])
        addVarmeter!(system14, device; bus = key, reactive = analysis.power.injection.reactive[value])
    end

    for (key, value) in system14.branch.label
        addWattmeter!(system14, device; from = key, active = analysis.power.from.active[value])
        addWattmeter!(system14, device; to = key, active = analysis.power.to.active[value])
        addVarmeter!(system14, device; from = key, reactive = analysis.power.from.reactive[value])
        addVarmeter!(system14, device; to = key, reactive = analysis.power.to.reactive[value])
    end

    ####### WLS LU: One Outlier #######
    updateVarmeter!(system14, device; label = "Varmeter 4", reactive = 10.25)

    analysisSE = gaussNewton(system14, device)
    for iteration = 1:20
        stopping = solve!(system14, analysisSE)
        if stopping < 1e-8
            break
        end
    end
    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "Varmeter 4"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 52.5 atol = 1e-1

    analysisSE = gaussNewton(system14, device)
    for iteration = 1:20
        stopping = solve!(system14, analysisSE)
        if stopping < 1e-8
            break
        end
    end
    @test analysis.voltage.magnitude ≈ analysisSE.voltage.magnitude
    @test analysis.voltage.angle ≈ analysisSE.voltage.angle


    ###### WLS LU: Two Outliers #######
    @pmu(label = "PMU ?")
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], polar = true)
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
    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "PMU 10"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 7713.26 atol = 1e-1

    analysisSE = gaussNewton(system14, device)
    for iteration = 1:20
        stopping = solve!(system14, analysisSE)
        if stopping < 1e-8
            break
        end
    end
    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "Varmeter 4"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 78.3 atol = 1e-1

    analysisSE = gaussNewton(system14, device)
    for iteration = 1:20
        stopping = solve!(system14, analysisSE)
        if stopping < 1e-8
            break
        end
    end
    @test analysis.voltage.magnitude ≈ analysisSE.voltage.magnitude
    @test analysis.voltage.angle ≈ analysisSE.voltage.angle

    ####### WLS Orthogonal: Two Outliers #######
    updateVarmeter!(system14, device; label = "Varmeter 4", status = 1)
    updatePmu!(system14, device; label = "PMU 10", statusMagnitude = 1)

    analysisSE = gaussNewton(system14, device, Orthogonal)
    for iteration = 1:20
        stopping = solve!(system14, analysisSE)
        if stopping < 1e-8
            break
        end
    end
    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "PMU 10"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 7713.26 atol = 1e-1

    analysisSE = gaussNewton(system14, device, Orthogonal)
    for iteration = 1:20
        stopping = solve!(system14, analysisSE)
        if stopping < 1e-8
            break
        end
    end
    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "Varmeter 4"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 78.3 atol = 1e-1

    analysisSE = gaussNewton(system14, device, Orthogonal)
    for iteration = 1:20
        stopping = solve!(system14, analysisSE)
        if stopping < 1e-8
            break
        end
    end
    @test analysis.voltage.magnitude ≈ analysisSE.voltage.magnitude
    @test analysis.voltage.angle ≈ analysisSE.voltage.angle


    ####### PMU Rectangular #######
    for (key, value) in system14.branch.label
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value])
    end
    updatePmu!(system14, device; label = "PMU 20", magnitude = 30)

    analysisSE = gaussNewton(system14, device)
    for iteration = 1:20
        stopping = solve!(system14, analysisSE)
        if stopping < 1e-8
            break
        end
    end
    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "PMU 20"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 335.59 atol = 1e-1

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

@testset "PMU State Estimation: Bad Data" begin
    @default(template)
    @default(unit)

    ############### Modified IEEE 14-bus Test Case ################
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
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value])
    end
    for (key, value) in system14.branch.label
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value])
        addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value])
    end

    ####### WLS LU: One Outlier #######
    updatePmu!(system14, device; label = "PMU 2", magnitude = 15)
    analysisSE = pmuWlsStateEstimation(system14, device)
    solve!(system14, analysisSE)

    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "PMU 2"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 2606.8 atol = 1e-1

    solve!(system14, analysisSE)
    @test analysis.voltage.magnitude ≈ analysisSE.voltage.magnitude
    @test analysis.voltage.angle ≈ analysisSE.voltage.angle

    ###### WLS LU: Two Outliers #######
    updatePmu!(system14, device; label = "PMU 2", statusAngle = 1, statusMagnitude = 1)
    updatePmu!(system14, device; label = "PMU 20", angle = 10pi, magnitude = 30)
    analysisSE = pmuWlsStateEstimation(system14, device)
    solve!(system14, analysisSE)

    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "PMU 20"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 8853.2 atol = 1e-1

    solve!(system14, analysisSE)
    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "PMU 2"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 2606.5 atol = 1e-1

    solve!(system14, analysisSE)
    @test analysis.voltage.magnitude ≈ analysisSE.voltage.magnitude
    @test analysis.voltage.angle ≈ analysisSE.voltage.angle

    ###### WLS Orthogonal: One Outlier #######
    updatePmu!(system14, device; label = "PMU 2", statusAngle = 1, statusMagnitude = 1)
    updatePmu!(system14, device; label = "PMU 20", magnitude = analysis.current.to.magnitude[4], angle = analysis.current.to.angle[4], statusAngle = 1, statusMagnitude = 1)
    analysisSE = pmuWlsStateEstimation(system14, device, Orthogonal)
    solve!(system14, analysisSE)

    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "PMU 2"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 2606.8 atol = 1e-1

    solve!(system14, analysisSE)
    @test analysis.voltage.magnitude ≈ analysisSE.voltage.magnitude
    @test analysis.voltage.angle ≈ analysisSE.voltage.angle

    ####### WLS Orthogonal: Two Outliers #######
    updatePmu!(system14, device; label = "PMU 2", statusAngle = 1, statusMagnitude = 1)
    updatePmu!(system14, device; label = "PMU 20", angle = 10pi, magnitude = 30)
    analysisSE = pmuWlsStateEstimation(system14, device, Orthogonal)
    solve!(system14, analysisSE)

    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "PMU 20"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 8853.2 atol = 1e-1

    solve!(system14, analysisSE)
    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "PMU 2"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 2606.5 atol = 1e-1

    solve!(system14, analysisSE)
    @test analysis.voltage.magnitude ≈ analysisSE.voltage.magnitude
    @test analysis.voltage.angle ≈ analysisSE.voltage.angle
end

@testset "DC State Estimation: Bad Data" begin
    @default(template)
    @default(unit)

    ############### Modified IEEE 14-bus Test Case ################
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)

    dcModel!(system14)
    analysis = dcPowerFlow(system14)
    solve!(system14, analysis)
    power!(system14, analysis)
    device = measurement()

    ################ Wattmeters ################
    @wattmeter(label = "Wattmeter ?")
    @pmu(label = "PMU ?")
    for (key, value) in system14.bus.label
        addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[value])
    end
    for (key, value) in system14.branch.label
        addWattmeter!(system14, device; from = key, active = analysis.power.from.active[value])
        addWattmeter!(system14, device; to = key, active = analysis.power.to.active[value])
    end
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = 1.0, angle = analysis.voltage.angle[value])
    end

    ####### WLS LU: One Outlier #######
    updateWattmeter!(system14, device; label = "Wattmeter 2", active = 100)
    analysisSE = dcWlsStateEstimation(system14, device)
    solve!(system14, analysisSE)

    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "Wattmeter 2"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

    solve!(system14, analysisSE)
    @test analysis.voltage.angle ≈ analysisSE.voltage.angle

    ####### WLS LU: Two Outliers #######
    updateWattmeter!(system14, device; label = "Wattmeter 2", status = 1)
    updatePmu!(system14, device; label = "PMU 10", angle = 10pi)
    analysisSE = dcWlsStateEstimation(system14, device)
    solve!(system14, analysisSE)

    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "PMU 10"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 5186.3 atol = 1e-1

    solve!(system14, analysisSE)
    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "Wattmeter 2"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

    solve!(system14, analysisSE)
    @test analysis.voltage.angle ≈ analysisSE.voltage.angle

    ####### WLS Orthogonal: One Outlier #######
    updateWattmeter!(system14, device; label = "Wattmeter 2", status = 1)
    updatePmu!(system14, device; label = "PMU 10", statusAngle = 1, angle = analysis.voltage.angle[10])
    analysisSE = dcWlsStateEstimation(system14, device, Orthogonal)
    solve!(system14, analysisSE)

    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "Wattmeter 2"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

    solve!(system14, analysisSE)
    @test analysis.voltage.angle ≈ analysisSE.voltage.angle

    ####### WLS Orthogonal: Two Outliers #######
    updateWattmeter!(system14, device; label = "Wattmeter 2", status = 1)
    updatePmu!(system14, device; label = "PMU 10", angle = 10pi)
    analysisSE = dcWlsStateEstimation(system14, device, Orthogonal)
    solve!(system14, analysisSE)

    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "PMU 10"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 5186.3 atol = 1e-1

    solve!(system14, analysisSE)
    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.method.outlier.label == "Wattmeter 2"
    @test analysisSE.method.outlier.maxNormalizedResidual ≈ 829.9 atol = 1e-1

    solve!(system14, analysisSE)
    @test analysis.voltage.angle ≈ analysisSE.voltage.angle
end