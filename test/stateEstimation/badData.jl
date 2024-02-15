system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))
    
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
        addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[value], noise = false)
    end
    for (key, value) in system14.branch.label
        if system14.branch.layout.status[value] == 1
            addWattmeter!(system14, device; from = key, active = analysis.power.from.active[value], noise = false)
            addWattmeter!(system14, device; to = key, active = analysis.power.to.active[value], noise = false) 
        end
    end
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = 1.0, angle = analysis.voltage.angle[value], noise = false)
    end
    
    ####### WLS LU: One Outlier #######
    updateWattmeter!(system14, device; label = "Wattmeter 2", active = 100, noise = false)
    analysisSE = dcStateEstimation(system14, device)
    solve!(system14, analysisSE)

    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.bad.label == "Wattmeter 2"
    @test analysisSE.bad.maxNormalizedResidual ≈ 829.9 atol = 1e-1
    
    solve!(system14, analysisSE)
    @test analysis.voltage.angle ≈ analysisSE.voltage.angle

    ####### WLS LU: Two Outliers #######
    updatePmu!(system14, device; label = "PMU 10", angle = 10pi, noise = false)
    analysisSE = dcStateEstimation(system14, device)
    solve!(system14, analysisSE)

    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.bad.label == "PMU 10"
    @test analysisSE.bad.maxNormalizedResidual ≈ 5186.3 atol = 1e-1

    solve!(system14, analysisSE)
    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.bad.label == "Wattmeter 2"
    @test analysisSE.bad.maxNormalizedResidual ≈ 829.9 atol = 1e-1

    solve!(system14, analysisSE)
    @test analysis.voltage.angle ≈ analysisSE.voltage.angle

    ####### WLS Orthogonal: One Outlier #######
    updatePmu!(system14, device; label = "PMU 10", angle = analysis.voltage.angle[10], noise = false)
    analysisSE = dcStateEstimation(system14, device, Orthogonal)
    solve!(system14, analysisSE)

    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.bad.label == "Wattmeter 2"
    @test analysisSE.bad.maxNormalizedResidual ≈ 829.9 atol = 1e-1

    solve!(system14, analysisSE)
    @test analysis.voltage.angle ≈ analysisSE.voltage.angle

    ####### WLS Orthogonal: Two Outliers #######
    updatePmu!(system14, device; label = "PMU 10", angle = 10pi, noise = false)
    analysisSE = dcStateEstimation(system14, device, Orthogonal)
    solve!(system14, analysisSE)

    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.bad.label == "PMU 10"
    @test analysisSE.bad.maxNormalizedResidual ≈ 5186.3 atol = 1e-1

    solve!(system14, analysisSE)
    residualTest!(system14, device, analysisSE; threshold = 3.0)
    @test analysisSE.bad.label == "Wattmeter 2"
    @test analysisSE.bad.maxNormalizedResidual ≈ 829.9 atol = 1e-1

    solve!(system14, analysisSE)
    @test analysis.voltage.angle ≈ analysisSE.voltage.angle
end