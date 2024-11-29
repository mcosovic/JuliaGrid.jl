system14 = powerSystem(path * "case14test.m")
system30 = powerSystem(path * "case30test.m")
@testset "AC State Estimation" begin
    @default(template)
    @default(unit)

    ########## Test AC State Estimation Function ##########
    function acStateEstimationTest(system, device, analysis)
        analysisSE = gaussNewton(system, device)
        for iteration = 1:100
            stopping = solve!(system, analysisSE)
            if stopping < 1e-10
                break
            end
        end
        compstruct(analysisSE.voltage, analysis.voltage; atol = 1e-10)

        analysisLAV = acLavStateEstimation(system, device, Ipopt.Optimizer)
        set_silent(analysisLAV.method.jump)
        solve!(system, analysisLAV)
        compstruct(analysisLAV.voltage, analysis.voltage; atol = 1e-8)

        return analysisSE
    end

    ########## IEEE 14-bus Test Case ##########
    @pmu(varianceMagnitudeBus = 1, varianceAngleBus = 1)

    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.25)
    updateBus!(system14; label = 1, magnitude = 1.0)
    updateBus!(system14; label = 3, magnitude = 1.2)
    updateBus!(system14; label = 4, magnitude = 1.0)
    updateBus!(system14; label = 5, magnitude = 1.1)
    updateBranch!(system14; label = 3, conductance = 0.01)
    updateBranch!(system14; label = 6, conductance = 0.05)

    acModel!(system14)
    analysis = newtonRaphson(system14)
    for i = 1:100
        stopping = mismatch!(system14, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, analysis)
    end
    power!(system14, analysis)
    current!(system14, analysis)

    # Voltmeter Measurements
    device = measurement()
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], statusMagnitude = 0, polar = true
        )
        addVoltmeter!(
            system14, device;
            bus = key, magnitude = analysis.voltage.magnitude[idx], variance = 1e-3
        )
    end
    analysisSE = acStateEstimationTest(system14, device, analysis)

    @capture_out printVoltmeterData(system14, device, analysisSE)
    @capture_out printVoltmeterData(system14, device, analysisSE; label = 1, header = true)
    @capture_out printVoltmeterData(system14, device, analysisSE; label = 6)
    @capture_out printVoltmeterData(system14, device, analysisSE; label = 8, footer = true)

    # Ammeter Measurements
    device = measurement()
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], polar = true
        )
    end
    for (key, idx) in system14.branch.label
        addAmmeter!(
            system14, device;
            from = key, magnitude = analysis.current.from.magnitude[idx], variance = 1e-3
        )
        addAmmeter!(
            system14, device;
            to = key, magnitude = analysis.current.to.magnitude[idx], variance = 1e-3
        )
    end
    analysisSE = acStateEstimationTest(system14, device, analysis)

    @capture_out printAmmeterData(system14, device, analysisSE)
    @capture_out printAmmeterData(system14, device, analysisSE; label = 1, header = true)
    @capture_out printAmmeterData(system14, device, analysisSE; label = 6)
    @capture_out printAmmeterData(system14, device, analysisSE; label = 8, footer = true)

    # Bus Wattmeter Measurements
    device = measurement()
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], statusAngle = 0, polar = true
        )
        addWattmeter!(
            system14, device;
            bus = key, active = analysis.power.injection.active[idx], variance = 1e-3
        )
    end
    analysisSE = acStateEstimationTest(system14, device, analysis)

    @capture_out printWattmeterData(system14, device, analysisSE)
    @capture_out printWattmeterData(system14, device, analysisSE; label = 1, header = true)
    @capture_out printWattmeterData(system14, device, analysisSE; label = 6)
    @capture_out printWattmeterData(system14, device, analysisSE; label = 8, footer = true)

    # Branch Wattmeter Measurements
    device = measurement()
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], statusAngle = 0, polar = true
        )
    end
    for (key, idx) in system14.branch.label
        addWattmeter!(
            system14, device;
            from = key, active = analysis.power.from.active[idx], variance = 1e-3
        )
        addWattmeter!(
            system14, device;
            to = key, active = analysis.power.to.active[idx], variance = 1e-3
        )
    end
    analysisSE = acStateEstimationTest(system14, device, analysisSE)

    # Bus Varmeter Measurements
    device = measurement()
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], polar = true
        )
        addVarmeter!(
            system14, device;
            bus = key, reactive = analysis.power.injection.reactive[idx], variance = 1e-3
        )
    end
    analysisSE = acStateEstimationTest(system14, device, analysis)

    # Branch Varmeter Measurements
    device = measurement()
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], polar = true
        )
    end
    for (key, idx) in system14.branch.label
        addVarmeter!(
            system14, device;
            from = key, reactive = analysis.power.from.reactive[idx], variance = 1e-2
        )
        addVarmeter!(
            system14, device;
            to = key, reactive = analysis.power.to.reactive[idx], variance = 1e-2
        )
    end
    analysisSE = acStateEstimationTest(system14, device, analysis)

    # Bus Rectangular PMU Measurements
    device = measurement()
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx]
        )
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], correlated = true
        )
    end
    analysisSE = acStateEstimationTest(system14, device, analysis)

    # Branch Rectangular PMU Measurements
    device = measurement()
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], polar = true
        )
    end
    for (key, idx) in system14.branch.label
        addPmu!(
            system14, device; from = key,
            magnitude = analysis.current.from.magnitude[idx],
            angle = analysis.current.from.angle[idx]
        )
        addPmu!(
            system14, device; to = key, magnitude = analysis.current.to.magnitude[idx],
            angle = analysis.current.to.angle[idx]
        )
    end
    acStateEstimationTest(system14, device, analysis)

    # Branch Rectangular Correlated PMU Measurements
    device = measurement()
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], polar = true
        )
    end
    for (key, idx) in system14.branch.label
        addPmu!(
            system14, device; from = key,
            magnitude = analysis.current.from.magnitude[idx],
            angle = analysis.current.from.angle[idx], correlated = true
        )
        addPmu!(
            system14, device; to = key, magnitude = analysis.current.to.magnitude[idx],
            angle = analysis.current.to.angle[idx], correlated = true
        )
    end
    acStateEstimationTest(system14, device, analysis)

    # From-Branch Polar PMU Measurements
    device = measurement()
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], polar = true
        )
    end
    for (key, idx) in system14.branch.label
        if idx ∉ [5, 7, 15, 19, 20]
        addPmu!(
            system14, device; from = key, magnitude = analysis.current.from.magnitude[idx],
            angle = analysis.current.from.angle[idx]
        )
        end
    end
    acStateEstimationTest(system14, device, analysis)

    # To-Branch Polar PMU Measurements
    device = measurement()
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], polar = true
        )
    end
    for (key, idx) in system14.branch.label
        if idx in [2, 3, 4, 6, 8, 11, 12, 16, 18, 20]
            addPmu!(
                system14, device; to = key, magnitude = analysis.current.to.magnitude[idx],
                angle = analysis.current.to.angle[idx]
            )
        end
    end
    acStateEstimationTest(system14, device, analysis)

    # All Measurements
    device = measurement()
    for (key, idx) in system14.bus.label
        addVoltmeter!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx]
        )
        addWattmeter!(
            system14, device; bus = key, active = analysis.power.injection.active[idx]
        )
        addVarmeter!(
            system14,
            device; bus = key, reactive = analysis.power.injection.reactive[idx]
        )
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], polar = true
        )
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx]
        )
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], correlated = true
        )
    end
    for (key, idx) in system14.branch.label
        addWattmeter!(
            system14, device; from = key, active = analysis.power.from.active[idx]
        )
        addWattmeter!(
            system14, device; to = key, active = analysis.power.to.active[idx]
        )
        addVarmeter!(
            system14, device; from = key, reactive = analysis.power.from.reactive[idx]
        )
        addVarmeter!(
            system14, device; to = key, reactive = analysis.power.to.reactive[idx]
        )
        addAmmeter!(
            system14, device; from = key, magnitude = analysis.current.from.magnitude[idx]
        )
        addAmmeter!(
            system14, device; to = key, magnitude = analysis.current.to.magnitude[idx]
        )
        addPmu!(
            system14, device; from = key, magnitude = analysis.current.from.magnitude[idx],
            angle = analysis.current.from.angle[idx], statusAngle = 1, polar = true
        )
        addPmu!(
            system14, device; from = key, magnitude = analysis.current.from.magnitude[idx],
            angle = analysis.current.from.angle[idx]
        )
        addPmu!(
            system14, device; to = key, magnitude = analysis.current.to.magnitude[idx],
            angle = analysis.current.to.angle[idx]
        )
        addPmu!(
            system14, device; from = key, magnitude = analysis.current.from.magnitude[idx],
            angle = analysis.current.from.angle[idx], correlated = true
        )
        addPmu!(
            system14, device; to = key, magnitude = analysis.current.to.magnitude[idx],
            angle = analysis.current.to.angle[idx], correlated = true
        )
    end
    acStateEstimationTest(system14, device, analysis)

    # QR Factorization
    analysisQR = gaussNewton(system14, device, QR)
    for iteration = 1:100
        stopping = solve!(system14, analysisQR)
        if stopping < 1e-8
            break
        end
    end
    @test analysisQR.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle

    # Orthogonal Method
    device = measurement()
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
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], polar = true
        )
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx]
        )
    end

    for (key, idx) in system14.branch.label
        addWattmeter!(
            system14, device; from = key, active = analysis.power.from.active[idx]
        )
        addWattmeter!(
            system14, device; to = key, active = analysis.power.to.active[idx]
        )
        addVarmeter!(
            system14, device; from = key, reactive = analysis.power.from.reactive[idx]
        )
        addVarmeter!(
            system14, device; to = key, reactive = analysis.power.to.reactive[idx]
        )
        addAmmeter!(
            system14, device; from = key, magnitude = analysis.current.from.magnitude[idx]
        )
        addAmmeter!(
            system14, device; to = key, magnitude = analysis.current.to.magnitude[idx]
        )
        addPmu!(
            system14, device; from = key, magnitude = analysis.current.from.magnitude[idx],
            angle = analysis.current.from.angle[idx], statusAngle = 0, polar = true
        )
        addPmu!(
            system14, device; to = key, magnitude = analysis.current.to.magnitude[idx],
            angle = analysis.current.to.angle[idx], statusAngle = 0, polar = true
        )
        addPmu!(
            system14, device; from = key, magnitude = analysis.current.from.magnitude[idx],
            angle = analysis.current.from.angle[idx]
        )
        addPmu!(
            system14, device; to = key, magnitude = analysis.current.to.magnitude[idx],
            angle = analysis.current.to.angle[idx]
        )
    end

    analysisOrt = gaussNewton(system14, device, Orthogonal)
    for iteration = 1:100
        stopping = solve!(system14, analysisOrt)
        if stopping < 1e-8
            break
        end
    end
    power!(system14, analysisOrt)

    compstruct(analysisOrt.voltage, analysis.voltage; atol = 1e-10)
    compstruct(analysisOrt.power, analysis.power; atol = 1e-10)

    # Specific Bus Powers
    for (key, idx) in system14.bus.label
        active, reactive = injectionPower(system14, analysisOrt; label = key)
        @test active ≈ analysis.power.injection.active[idx] atol = 1e-6
        @test reactive ≈ analysis.power.injection.reactive[idx] atol = 1e-6

        active, reactive = supplyPower(system14, analysisOrt; label = key)
        @test active ≈ analysis.power.supply.active[idx] atol = 1e-6
        @test reactive ≈ analysis.power.supply.reactive[idx] atol = 1e-6

        active, reactive = shuntPower(system14, analysisOrt; label = key)
        @test active ≈ analysis.power.shunt.active[idx] atol = 1e-6
        @test reactive ≈ analysis.power.shunt.reactive[idx] atol = 1e-6
    end

    # Specific Branch Powers
    for (key, idx) in system14.branch.label
        active, reactive = fromPower(system14, analysisOrt; label = key)
        @test active ≈ analysis.power.from.active[idx] atol = 1e-6
        @test reactive ≈ analysis.power.from.reactive[idx] atol = 1e-6

        active, reactive = toPower(system14, analysisOrt; label = key)
        @test active ≈ analysis.power.to.active[idx] atol = 1e-6
        @test reactive ≈ analysis.power.to.reactive[idx] atol = 1e-6

        active, reactive = seriesPower(system14, analysisOrt; label = key)
        @test active ≈ analysis.power.series.active[idx] atol = 1e-6
        @test reactive ≈ analysis.power.series.reactive[idx] atol = 1e-6

        active, reactive = chargingPower(system14, analysisOrt; label = key)
        @test active ≈ analysis.power.charging.active[idx] atol = 1e-6
        @test reactive ≈ analysis.power.charging.reactive[idx] atol = 1e-6
    end

    ########## IEEE 30-bus Test Case ##########
    acModel!(system30)
    analysis = newtonRaphson(system30)
    for i = 1:100
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
    end
    power!(system30, analysis)
    current!(system30, analysis)

    # Voltmeter Measurements
    device = measurement()
    for (key, idx) in system30.bus.label
        addPmu!(
            system30, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], statusMagnitude = 0, polar = true
        )
        addVoltmeter!(
            system30, device;
            bus = key, magnitude = analysis.voltage.magnitude[idx], variance = 1e-4
        )
    end
    acStateEstimationTest(system30, device, analysis)

    # Wattmeter Measurements
    device = measurement()
    for (key, idx) in system30.bus.label
        addPmu!(
            system30, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], statusAngle = 0, polar = true
        )
        addWattmeter!(
            system30, device;
            bus = key, active = analysis.power.injection.active[idx], variance = 1e-3
        )
    end
    for (key, idx) in system30.branch.label
        addWattmeter!(
            system30, device;
            from = key, active = analysis.power.from.active[idx], variance = 1e-2
        )
        addWattmeter!(
            system30, device;
            to = key, active = analysis.power.to.active[idx], variance = 1e-1
        )
    end
    acStateEstimationTest(system30, device, analysis)

    # Varmeter Measurements
    device = measurement()
    for (key, idx) in system30.bus.label
        addPmu!(
            system30, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], statusMagnitude = 0, polar = true
        )
        addVarmeter!(
            system30, device;
            bus = key, reactive = analysis.power.injection.reactive[idx], variance = 1e-3
        )
    end
    for (key, idx) in system30.branch.label
        addVarmeter!(
            system30, device;
            from = key, reactive = analysis.power.from.reactive[idx], variance = 1e-3
        )
        addVarmeter!(
            system30, device;
            to = key, reactive = analysis.power.to.reactive[idx], variance = 1e-3
        )
    end
    acStateEstimationTest(system30, device, analysis)

    # Rectangular PMU Measurements
    device = measurement()
    for (key, idx) in system30.bus.label
        addPmu!(
            system30, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], polar = true
        )
        addPmu!(
            system30, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], correlated = true
        )
    end
    for (key, idx) in system30.branch.label
        addPmu!(
            system30, device; from = key, magnitude = analysis.current.from.magnitude[idx],
            angle = analysis.current.from.angle[idx]
        )
        addPmu!(
            system30, device; to = key, magnitude = analysis.current.to.magnitude[idx],
            angle = analysis.current.to.angle[idx]
        )
        addPmu!(
            system30, device; from = key, magnitude = analysis.current.from.magnitude[idx],
            angle = analysis.current.from.angle[idx], correlated = true
        )
        addPmu!(
            system30, device; to = key, magnitude = analysis.current.to.magnitude[idx],
            angle = analysis.current.to.angle[idx], correlated = true
        )
    end
    acStateEstimationTest(system30, device, analysis)

    # Polar PMU Measurements
    device = measurement()
    for (key, idx) in system30.bus.label
        addPmu!(
            system30, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], polar = true
        )
    end
    addPmu!(
        system30, device; from = 8, magnitude = analysis.current.from.magnitude[8],
        angle = analysis.current.from.angle[8], polar = true
    )
    addPmu!(
        system30, device; to = 10, magnitude = analysis.current.to.magnitude[10],
        angle = analysis.current.to.angle[10], polar = true
    )

    acStateEstimationTest(system30, device, analysis)

    # All Measurements
    device = measurement()
    for (key, idx) in system30.bus.label
        addVoltmeter!(
            system30, device; bus = key, magnitude = analysis.voltage.magnitude[idx]
        )
        addWattmeter!(
            system30, device; bus = key, active = analysis.power.injection.active[idx]
        )
        addVarmeter!(
            system30, device; bus = key, reactive = analysis.power.injection.reactive[idx]
        )
        addPmu!(
            system30, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], polar = true
        )
        addPmu!(
            system30, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx]
        )
    end
    for (key, idx) in system30.branch.label
        addWattmeter!(
            system30, device; from = key, active = analysis.power.from.active[idx]
        )
        addWattmeter!(
            system30, device; to = key, active = analysis.power.to.active[idx]
        )
        addVarmeter!(
            system30, device; from = key, reactive = analysis.power.from.reactive[idx]
        )
        addVarmeter!(
            system30, device; to = key, reactive = analysis.power.to.reactive[idx]
        )
        addPmu!(
            system30, device; from = key, magnitude = analysis.current.from.magnitude[idx],
            angle = analysis.current.from.angle[idx]
        )
        addPmu!(
            system30, device; to = key, magnitude = analysis.current.to.magnitude[idx],
            angle = analysis.current.to.angle[idx]
        )
    end
    acStateEstimationTest(system30, device, analysis)

    # Orthogonal Method
    analysisOrt = gaussNewton(system30, device, Orthogonal)
    for iteration = 1:100
        stopping = solve!(system30, analysisOrt)
        if stopping < 1e-8
            break
        end
    end
    compstruct(analysisOrt.voltage, analysis.voltage; atol = 1e-10)

    # Covariance Matrix
    system = powerSystem()
    device = measurement()
    covariance = zeros(6, 6)

    addBus!(system; type = 3, active = 0.5)
    addBus!(system; type = 1, reactive = 0.05)
    addBus!(system; type = 1, active = 0.5)

    @branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
    addBranch!(system; from = 1, to = 2, reactance = 0.05)
    addBranch!(system; from = 1, to = 2, reactance = 0.01)
    addBranch!(system; from = 2, to = 3, reactance = 0.04)

    addGenerator!(system; label = 1, bus = 1, active = 3.2, reactive = 0.2)

    zv = 0.9; zθ = 0.5; vv = 1e-2; vθ = 1.6
    addPmu!(
        system, device; bus = 3, magnitude = zv, angle = zθ,
        varianceMagnitude = vv, varianceAngle = vθ, correlated = true
    )
    covariance[1,1] = vv * (cos(zθ))^2 + vθ * (zv * sin(zθ))^2
    covariance[2,2] = vv * (sin(zθ))^2 + vθ * (zv * cos(zθ))^2
    covariance[1,2] = cos(zθ) * sin(zθ) * (vv - vθ * zv^2)
    covariance[2,1] = covariance[1,2]

    zv = 0.8; zθ = -0.3; vv = 0.5; vθ = 2.6
    addPmu!(
        system, device;
        from = 3, magnitude = zv, angle = zθ, varianceMagnitude = vv, varianceAngle = vθ
    )
    covariance[3,3] = vv * (cos(zθ))^2 + vθ * (zv * sin(zθ))^2
    covariance[4,4] = vv * (sin(zθ))^2 + vθ * (zv * cos(zθ))^2

    zv = 1.3; zθ = -0.2; vv = 1e-1; vθ = 0.2
    addPmu!(
        system, device; to = 2, magnitude = zv, angle = zθ, varianceMagnitude = vv,
        varianceAngle = vθ, correlated = true
    )
    covariance[5,5] = vv * (cos(zθ))^2 + vθ * (zv * sin(zθ))^2
    covariance[6,6] = vv * (sin(zθ))^2 + vθ * (zv * cos(zθ))^2
    covariance[5,6] = cos(zθ) * sin(zθ) * (vv - vθ * zv^2)
    covariance[6,5] = covariance[5,6]

    analysis = gaussNewton(system, device)
    @test inv(covariance) ≈ Matrix(analysis.method.precision)
end

system14 = powerSystem(path * "case14test.m")
system30 = powerSystem(path * "case30test.m")
@testset "PMU State Estimation" begin
    @default(template)
    @default(unit)

    ########## Test PMU State Estimation Function ##########
    function pmuStateEstimationTest(system, device, analysis)
        analysisSE = pmuStateEstimation(system, device)
        solve!(system, analysisSE)
        compstruct(analysisSE.voltage, analysis.voltage; atol = 1e-8)

        analysisLAV = pmuLavStateEstimation(system, device, Ipopt.Optimizer)
        set_silent(analysisLAV.method.jump)
        solve!(system, analysisLAV)
        compstruct(analysisLAV.voltage, analysis.voltage; atol = 1e-6)
    end

    ########## IEEE 14-bus Test Case ##########
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)
    updateBranch!(system14; label = 3, conductance = 0.01)
    updateBranch!(system14; label = 6, conductance = 0.05)

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

    # Uncorrelated PMU Measurements
    device = measurement()
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
    pmuStateEstimationTest(system14, device, analysis)

    # QR Factorization
    analysisQR = pmuStateEstimation(system14, device, QR)
    solve!(system14, analysisQR)
    power!(system14, analysisQR)

    compstruct(analysisQR.voltage, analysis.voltage; atol = 1e-10)
    compstruct(analysisQR.power, analysis.power; atol = 1e-10)

    # Orthogonal Method
    analysisOrt = pmuStateEstimation(system14, device, Orthogonal)
    solve!(system14, analysisOrt)
    compstruct(analysisOrt.voltage, analysis.voltage; atol = 1e-10)

    # Specific Bus Powers
    for (key, idx) in system14.bus.label
        active, reactive = injectionPower(system14, analysisQR; label = key)
        @test active ≈ analysis.power.injection.active[idx] atol = 1e-6
        @test reactive ≈ analysis.power.injection.reactive[idx] atol = 1e-6

        active, reactive = supplyPower(system14, analysisQR; label = key)
        @test active ≈ analysis.power.supply.active[idx] atol = 1e-6
        @test reactive ≈ analysis.power.supply.reactive[idx] atol = 1e-6

        active, reactive = shuntPower(system14, analysisQR; label = key)
        @test active ≈ analysis.power.shunt.active[idx] atol = 1e-6
        @test reactive ≈ analysis.power.shunt.reactive[idx] atol = 1e-6
    end

    # Specific Branch Powers
    for (key, idx) in system14.branch.label
        active, reactive = fromPower(system14, analysisQR; label = key)
        @test active ≈ analysis.power.from.active[idx] atol = 1e-6
        @test reactive ≈ analysis.power.from.reactive[idx] atol = 1e-6

        active, reactive = toPower(system14, analysisQR; label = key)
        @test active ≈ analysis.power.to.active[idx] atol = 1e-6
        @test reactive ≈ analysis.power.to.reactive[idx] atol = 1e-6

        active, reactive = seriesPower(system14, analysisQR; label = key)
        @test active ≈ analysis.power.series.active[idx] atol = 1e-6
        @test reactive ≈ analysis.power.series.reactive[idx] atol = 1e-6

        active, reactive = chargingPower(system14, analysisQR; label = key)
        @test active ≈ analysis.power.charging.active[idx] atol = 1e-6
        @test reactive ≈ analysis.power.charging.reactive[idx] atol = 1e-6
    end

    # Correlated PMU Measurements
    device = measurement()
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], correlated = true
        )
    end
    for (key, idx) in system14.branch.label
        addPmu!(
            system14, device; from = key, magnitude = analysis.current.from.magnitude[idx],
            angle = analysis.current.from.angle[idx], correlated = true
        )
        addPmu!(
            system14, device; to = key, magnitude = analysis.current.to.magnitude[idx],
            angle = analysis.current.to.angle[idx], correlated = true
        )
    end
    pmuStateEstimationTest(system14, device, analysis)

    ########## IEEE 30-bus Test Case ##########
    acModel!(system30)
    analysis = newtonRaphson(system30)
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
    end
    current!(system30, analysis)

    # PMU Measurements
    device = measurement()
    for (key, idx) in system30.bus.label
        addPmu!(
            system30, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], varianceAngle = 1e-5,
            varianceMagnitude = varianceAngle = 1e-6
        )
        addPmu!(
            system30, device; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], varianceAngle = 1e-6,
            varianceMagnitude = varianceAngle = 1e-6, correlated = true
        )
    end
    for (key, idx) in system30.branch.label
        addPmu!(
            system30, device; from = key, magnitude = analysis.current.from.magnitude[idx],
            angle = analysis.current.from.angle[idx], varianceAngle = 1e-7,
            varianceMagnitude = varianceAngle = 1e-6, correlated = true
        )
        addPmu!(
            system30, device; to = key, magnitude = analysis.current.to.magnitude[idx],
            angle = analysis.current.to.angle[idx], varianceAngle = 1e-7,
            varianceMagnitude = varianceAngle = 1e-5
        )
    end
    pmuStateEstimationTest(system30, device, analysis)
end

system14 = powerSystem(path * "case14test.m")
system30 = powerSystem(path * "case30test.m")
@testset "DC State Estimation" begin
    @default(template)
    @default(unit)

    ########## Test DC State Estimation Function ##########
    function dcStateEstimationTest(system, device, analysis)
        analysisSE = dcStateEstimation(system, device)
        solve!(system, analysisSE)
        @test analysisSE.voltage.angle ≈ analysis.voltage.angle

        analysisLAV = dcLavStateEstimation(system, device, Ipopt.Optimizer)
        set_silent(analysisLAV.method.jump)
        solve!(system, analysisLAV)
        @test analysisLAV.voltage.angle ≈ analysis.voltage.angle

        return analysisSE
    end

    ########## IEEE 14-bus Test Case ##########
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)

    dcModel!(system14)
    analysis = dcPowerFlow(system14)
    solve!(system14, analysis)
    power!(system14, analysis)
    device = measurement()

    # Bus Wattmeter Measurements
    device = measurement()
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device;
            bus = key, magnitude = 1.0, angle = analysis.voltage.angle[idx], polar = true
        )
        addWattmeter!(
            system14, device;
            bus = key, active = analysis.power.injection.active[idx], variance = 1e-3
        )
    end
    dcStateEstimationTest(system14, device, analysis)

    # Branch Wattmeter Measurements
    device = measurement()
    for (key, idx) in system14.bus.label
        addPmu!(
            system14, device;
            bus = key, magnitude = 1.0, angle = analysis.voltage.angle[idx], polar = true
        )
    end
    for (key, idx) in system14.branch.label
        addWattmeter!(system14, device; from = key, active = analysis.power.from.active[idx])
        addWattmeter!(system14, device; to = key, active = analysis.power.to.active[idx])
    end
    analysisSE = dcStateEstimationTest(system14, device, analysis)

    @capture_out printPmuData(system14, device, analysisSE)
    @capture_out printPmuData(system14, device, analysisSE; label = 1, header = true)
    @capture_out printPmuData(system14, device, analysisSE; label = 6)
    @capture_out printPmuData(system14, device, analysisSE; label = 8, footer = true)

    # Wattmeters
    for (key, idx) in system14.bus.label
        addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[idx])
    end
    for (key, idx) in system14.branch.label
        addWattmeter!(system14, device; from = key, active = analysis.power.from.active[idx])
        addWattmeter!(system14, device; to = key, active = analysis.power.to.active[idx])
    end
    analysisSE = dcStateEstimationTest(system14, device, analysis)

    @capture_out printWattmeterData(system14, device, analysisSE)
    @capture_out printWattmeterData(system14, device, analysisSE; label = 1, header = true)
    @capture_out printWattmeterData(system14, device, analysisSE; label = 6)
    @capture_out printWattmeterData(system14, device, analysisSE; label = 8, footer = true)

    # QR Factorization
    analysisQR = dcStateEstimation(system14, device, QR)
    solve!(system14, analysisQR)
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle

    # Orthogonal Method
    analysisOrt = dcStateEstimation(system14, device, Orthogonal)
    solve!(system14, analysisOrt)
    power!(system14, analysisOrt)

    @test analysisOrt.voltage.angle ≈ analysis.voltage.angle
    compstruct(analysisOrt.power, analysis.power; atol = 1e-10)

    # Specific Bus Powers
    for (key, idx) in system14.bus.label
        @test injectionPower(system14, analysisOrt; label = key) ≈ analysis.power.injection.active[idx] atol = 1e-6
        @test supplyPower(system14, analysisOrt; label = key) ≈ analysis.power.supply.active[idx] atol = 1e-6
    end

    # Specific Branch Powers
    for (key, idx) in system14.branch.label
        @test fromPower(system14, analysisOrt; label = key) ≈ analysis.power.from.active[idx] atol = 1e-6
        @test toPower(system14, analysisOrt; label = key) ≈ analysis.power.to.active[idx] atol = 1e-6
    end

    ########## IEEE 30-bus Test Case ##########
    dcModel!(system30)
    analysis = dcPowerFlow(system30)
    solve!(system30, analysis)
    power!(system30, analysis)

    # Wattmeters
    device = measurement()
    for (key, idx) in system30.bus.label
        addWattmeter!(system30, device; bus = key, active = analysis.power.injection.active[idx], variance = 1e-6)
    end
    for (key, idx) in system30.branch.label
        addWattmeter!(system30, device; from = key, active = analysis.power.from.active[idx], variance = 1e-7)
        addWattmeter!(system30, device; to = key, active = analysis.power.to.active[idx], variance = 1e-8)
    end
    dcStateEstimationTest(system30, device, analysis)

    # Orthogonal Method
    analysisOrt = dcStateEstimation(system30, device, Orthogonal)
    solve!(system30, analysisOrt)
    @test analysisOrt.voltage.angle ≈ analysis.voltage.angle
end

@testset "Print Data in Per-Units" begin
    system = powerSystem(path * "case14test.m")
    device = measurement("measurement14.h5")
    addPmu!(system, device; bus = 1, magnitude = 1.0, angle = 0.0)
    addPmu!(system, device; bus = 3, magnitude = 1.1, angle = -0.3)

    ########## Print AC Data ##########
    analysis = gaussNewton(system, device)
    solve!(system, analysis)
    power!(system, analysis)
    current!(system, analysis)

    # Print Voltmeter Data
    width = Dict("Voltage Magnitude Residual" => 10)
    show = Dict("Voltage Magnitude Estimate" => false)
    fmt = Dict("Voltage Magnitude" => "%.2f")
    @capture_out printVoltmeterData(system, device, analysis; width, show, fmt, repeat = 10)
    @capture_out printVoltmeterData(system, device, analysis; label = 1, header = true)
    @capture_out printVoltmeterData(system, device, analysis; label = 2, footer = true)
    @capture_out printVoltmeterData(system, device, analysis; style = false)

    # Print Ammeter Data
    show = Dict("Current Magnitude Status" => false)
    @capture_out printAmmeterData(system, device, analysis; show, repeat = 10)
    @capture_out printAmmeterData(system, device, analysis; label = "From 1", header = true)
    @capture_out printAmmeterData(system, device, analysis; label = "From 2", footer = true)
    @capture_out printAmmeterData(system, device, analysis; style = false)

    ##### Print Wattmeter Data
    @capture_out printWattmeterData(system, device, analysis; repeat = 10)
    @capture_out printWattmeterData(system, device, analysis; label = 1, header = true)
    @capture_out printWattmeterData(system, device, analysis; label = 4, footer = true)
    @capture_out printWattmeterData(system, device, analysis; style = false)

    # Print Varmeter Data
    @capture_out printVarmeterData(system, device, analysis; repeat = 10)
    @capture_out printVarmeterData(system, device, analysis; label = 1, header = true)
    @capture_out printVarmeterData(system, device, analysis; label = 4, footer = true)
    @capture_out printVarmeterData(system, device, analysis; style = false)

    # Print PMU Data
    @capture_out printPmuData(system, device, analysis; repeat = 10)
    @capture_out printPmuData(system, device, analysis; label = "From 1", header = true)
    @capture_out printPmuData(system, device, analysis; label = "From 4", footer = true)
    @capture_out printPmuData(system, device, analysis; style = false)
    @capture_out printPmuData(system, device, analysis; label = "From 1", style = false)
    @capture_out printPmuData(system, device, analysis; label = 41, style = false)

    ########## Print DC Data ##########
    analysis = dcStateEstimation(system, device)
    solve!(system, analysis)
    power!(system, analysis)

    # Print Wattmeter Data
    @capture_out printWattmeterData(system, device, analysis; repeat = 10)
    @capture_out printWattmeterData(system, device, analysis; label = 1, header = true)
    @capture_out printWattmeterData(system, device, analysis; label = 4, footer = true)
    @capture_out printWattmeterData(system, device, analysis; style = false)

    # Print PMU Data
    @capture_out printPmuData(system, device, analysis; repeat = 10)
    @capture_out printPmuData(system, device, analysis; label = 41, header = true)
    @capture_out printPmuData(system, device, analysis; label = 42, footer = true)
    @capture_out printPmuData(system, device, analysis; style = false)
end

@testset "Print Data in SI Units" begin
    system = powerSystem(path * "case14test.m")
    device = measurement("measurement14.h5")
    addPmu!(system, device; bus = 1, magnitude = 1.0, angle = 0.0)
    addPmu!(system, device; bus = 3, magnitude = 1.1, angle = -0.3)

    @power(GW, MVAr, MVA)
    @voltage(kV, deg, V)
    @current(MA, deg)

    ########## Print AC Data ##########
    analysis = gaussNewton(system, device)
    solve!(system, analysis)
    power!(system, analysis)
    current!(system, analysis)

    # Print Voltmeter Data
    @capture_out printVoltmeterData(system, device, analysis)
    @capture_out printVoltmeterData(system, device, analysis; label = 1)

    # Print Ammeter Data
    @capture_out printAmmeterData(system, device, analysis)
    @capture_out printAmmeterData(system, device, analysis; label = "From 1")

    # Print Wattmeter Data
    @capture_out printWattmeterData(system, device, analysis)
    @capture_out printWattmeterData(system, device, analysis; label = 1)

    # Print Varmeter Data
    @capture_out printVarmeterData(system, device, analysis)
    @capture_out printVarmeterData(system, device, analysis; label = 1)

    # Print PMU Data
    @capture_out printPmuData(system, device, analysis)
    @capture_out printPmuData(system, device, analysis; label = "From 1")
    @capture_out printPmuData(system, device, analysis; label = 41)

    ########## Print DC Data ##########
    analysis = dcStateEstimation(system, device)
    solve!(system, analysis)
    power!(system, analysis)

    # Print Wattmeter Data
    @capture_out printWattmeterData(system, device, analysis)
    @capture_out printWattmeterData(system, device, analysis; label = 1)

    # Print PMU Data
    @capture_out printPmuData(system, device, analysis)
    @capture_out printPmuData(system, device, analysis; label = 41)
end
