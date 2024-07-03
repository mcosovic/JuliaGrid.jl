system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))
@testset "AC State Estimation" begin
    @default(template)
    @default(unit)

    ################ Test AC State Estimation Function ################
    function acStateEstimationTest(system, device, analysis)
        analysisSE = gaussNewton(system, device)
        for iteration = 1:100
            stopping = solve!(system, analysisSE)
            if stopping < 1e-10
                break
            end
        end
        @test analysisSE.voltage.magnitude ≈ analysis.voltage.magnitude
        @test analysisSE.voltage.angle ≈ analysis.voltage.angle

        analysisLAV = acLavStateEstimation(system, device, Ipopt.Optimizer)
        JuMP.set_silent(analysisLAV.method.jump)
        solve!(system, analysisLAV)
        @test analysisLAV.voltage.magnitude ≈ analysis.voltage.magnitude atol = 1e-6
        @test analysisLAV.voltage.angle ≈ analysis.voltage.angle atol = 1e-6

        return analysisSE
    end

    ################ Modified IEEE 14-bus Test Case ################
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

    ######## Test Voltmeter Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], statusMagnitude = 0, polar = true)
        addVoltmeter!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], variance = 1e-3)
    end
    analysisSE = acStateEstimationTest(system14, device, analysis)

    @capture_out printVoltmeterData(system14, device, analysisSE)
    @capture_out printVoltmeterData(system14, device, analysisSE; label = 1, header = true)
    @capture_out printVoltmeterData(system14, device, analysisSE; label = 6)
    @capture_out printVoltmeterData(system14, device, analysisSE; label = 8, footer = true)

    ######## Test Ammeter Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], polar = true)
    end
    for (key, value) in system14.branch.label
        addAmmeter!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], variance = 1e-3)
        addAmmeter!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], variance = 1e-3)
    end
    analysisSE = acStateEstimationTest(system14, device, analysis)

    @capture_out printAmmeterData(system14, device, analysisSE)
    @capture_out printAmmeterData(system14, device, analysisSE; label = 1, header = true)
    @capture_out printAmmeterData(system14, device, analysisSE; label = 6)
    @capture_out printAmmeterData(system14, device, analysisSE; label = 8, footer = true)

    ######## Test Bus Wattmeter Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], statusAngle = 0, polar = true)
        addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[value], variance = 1e-3)
    end
    analysisSE = acStateEstimationTest(system14, device, analysis)

    @capture_out printWattmeterData(system14, device, analysisSE)
    @capture_out printWattmeterData(system14, device, analysisSE; label = 1, header = true)
    @capture_out printWattmeterData(system14, device, analysisSE; label = 6)
    @capture_out printWattmeterData(system14, device, analysisSE; label = 8, footer = true)

    ######## Test Branch Wattmeter Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], statusAngle = 0, polar = true)
    end
    for (key, value) in system14.branch.label
        addWattmeter!(system14, device; from = key, active = analysis.power.from.active[value], variance = 1e-3)
        addWattmeter!(system14, device; to = key, active = analysis.power.to.active[value], variance = 1e-3)
    end
    analysisSE = acStateEstimationTest(system14, device, analysisSE)

    @capture_out printWattmeterData(system14, device, analysisSE)
    @capture_out printWattmeterData(system14, device, analysisSE; label = 1, header = true)
    @capture_out printWattmeterData(system14, device, analysisSE; label = 6)
    @capture_out printWattmeterData(system14, device, analysisSE; label = 8, footer = true)

    ######## Test Bus Varmeter Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], polar = true)
        addVarmeter!(system14, device; bus = key, reactive = analysis.power.injection.reactive[value], variance = 1e-3)
    end
    analysisSE = acStateEstimationTest(system14, device, analysis)

    @capture_out printVarmeterData(system14, device, analysisSE)
    @capture_out printVarmeterData(system14, device, analysisSE; label = 1, header = true)
    @capture_out printVarmeterData(system14, device, analysisSE; label = 6)
    @capture_out printVarmeterData(system14, device, analysisSE; label = 8, footer = true)

    ######## Test Branch Varmeter Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], polar = true)
    end
    for (key, value) in system14.branch.label
        addVarmeter!(system14, device; from = key, reactive = analysis.power.from.reactive[value], variance = 1e-2)
        addVarmeter!(system14, device; to = key, reactive = analysis.power.to.reactive[value], variance = 1e-2)
    end
    analysisSE = acStateEstimationTest(system14, device, analysis)

    @capture_out printVarmeterData(system14, device, analysisSE)
    @capture_out printVarmeterData(system14, device, analysisSE; label = 1, header = true)
    @capture_out printVarmeterData(system14, device, analysisSE; label = 6)
    @capture_out printVarmeterData(system14, device, analysisSE; label = 8, footer = true)

    ######## Test Bus Rectangular PMU Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value])
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], correlated = true)
    end
    analysisSE = acStateEstimationTest(system14, device, analysis)

    @capture_out printPmuData(system14, device, analysisSE)
    @capture_out printPmuData(system14, device, analysisSE; label = 1, header = true)
    @capture_out printPmuData(system14, device, analysisSE; label = 6)
    @capture_out printPmuData(system14, device, analysisSE; label = 8, footer = true)

    ######## Test Branch Rectangular PMU Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], polar = true)
    end
    for (key, value) in system14.branch.label
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value])
        addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value])
    end
    acStateEstimationTest(system14, device, analysis)

    ######## Test Branch Rectangular Correlated PMU Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], polar = true)
    end
    for (key, value) in system14.branch.label
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], correlated = true)
        addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], correlated = true)
    end
    acStateEstimationTest(system14, device, analysis)

    ######## Test From-Branch Polar PMU Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], polar = true)
    end
    for (key, value) in system14.branch.label
        if value ∉ [5, 7, 15, 19, 20]
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value])
        end
    end
    acStateEstimationTest(system14, device, analysis)

    ######## Test To-Branch Polar PMU Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], polar = true)
    end
    for (key, value) in system14.branch.label
        if value in [2, 3, 4, 6, 8, 11, 12, 16, 18, 20]
            addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value])
        end
    end
    acStateEstimationTest(system14, device, analysis)

    ####### Test All Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addVoltmeter!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value])
        addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[value])
        addVarmeter!(system14, device; bus = key, reactive = analysis.power.injection.reactive[value])
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], polar = true)
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value])
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], correlated = true)
    end
    for (key, value) in system14.branch.label
        addWattmeter!(system14, device; from = key, active = analysis.power.from.active[value])
        addWattmeter!(system14, device; to = key, active = analysis.power.to.active[value])
        addVarmeter!(system14, device; from = key, reactive = analysis.power.from.reactive[value])
        addVarmeter!(system14, device; to = key, reactive = analysis.power.to.reactive[value])
        addAmmeter!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value])
        addAmmeter!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value])
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], statusAngle = 0, polar = true)
        addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], statusAngle = 0, polar = true)
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value])
        addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value])
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], correlated = true)
        addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], correlated = true)
    end
    acStateEstimationTest(system14, device, analysis)

    ###### Test QR Factorization #######
    analysisQR = gaussNewton(system14, device, QR)
    for iteration = 1:100
        stopping = solve!(system14, analysisQR)
        if stopping < 1e-8
            break
        end
    end
    @test analysisQR.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle

    ####### Test Orthogonal Method #######
    device = measurement()
    for (key, value) in system14.bus.label
        addVoltmeter!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value])
        addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[value])
        addVarmeter!(system14, device; bus = key, reactive = analysis.power.injection.reactive[value])
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], polar = true)
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value])
    end

    for (key, value) in system14.branch.label
        addWattmeter!(system14, device; from = key, active = analysis.power.from.active[value])
        addWattmeter!(system14, device; to = key, active = analysis.power.to.active[value])
        addVarmeter!(system14, device; from = key, reactive = analysis.power.from.reactive[value])
        addVarmeter!(system14, device; to = key, reactive = analysis.power.to.reactive[value])
        addAmmeter!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value])
        addAmmeter!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value])
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], statusAngle = 0, polar = true)
        addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], statusAngle = 0, polar = true)
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value])
        addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value])
    end

    analysisOrt = gaussNewton(system14, device, Orthogonal)
    for iteration = 1:100
        stopping = solve!(system14, analysisOrt)
        if stopping < 1e-8
            break
        end
    end
    @test analysisOrt.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisOrt.voltage.angle ≈ analysis.voltage.angle

    ####### Test Powers #######
    power!(system14, analysisOrt)
    @test analysisOrt.power.injection.active ≈ analysis.power.injection.active
    @test analysisOrt.power.injection.reactive ≈ analysis.power.injection.reactive
    @test analysisOrt.power.supply.active ≈ analysis.power.supply.active
    @test analysisOrt.power.supply.reactive ≈ analysis.power.supply.reactive
    @test analysisOrt.power.shunt.active ≈ analysis.power.shunt.active
    @test analysisOrt.power.shunt.reactive ≈ analysis.power.shunt.reactive
    @test analysisOrt.power.from.active ≈ analysis.power.from.active
    @test analysisOrt.power.from.reactive ≈ analysis.power.from.reactive
    @test analysisOrt.power.to.active ≈ analysis.power.to.active
    @test analysisOrt.power.to.reactive ≈ analysis.power.to.reactive
    @test analysisOrt.power.series.active ≈ analysis.power.series.active
    @test analysisOrt.power.series.reactive ≈ analysis.power.series.reactive
    @test analysisOrt.power.charging.active ≈ analysis.power.charging.active
    @test analysisOrt.power.charging.reactive ≈ analysis.power.charging.reactive

    ####### Test Specific Bus Powers #######
    for (key, value) in system14.bus.label
        active, reactive = injectionPower(system14, analysisOrt; label = key)
        @test active ≈ analysis.power.injection.active[value] atol = 1e-6
        @test reactive ≈ analysis.power.injection.reactive[value] atol = 1e-6

        active, reactive = supplyPower(system14, analysisOrt; label = key)
        @test active ≈ analysis.power.supply.active[value] atol = 1e-6
        @test reactive ≈ analysis.power.supply.reactive[value] atol = 1e-6

        active, reactive = shuntPower(system14, analysisOrt; label = key)
        @test active ≈ analysis.power.shunt.active[value] atol = 1e-6
        @test reactive ≈ analysis.power.shunt.reactive[value] atol = 1e-6
    end

    ####### Test Specific Branch Powers #######
    for (key, value) in system14.branch.label
        active, reactive = fromPower(system14, analysisOrt; label = key)
        @test active ≈ analysis.power.from.active[value] atol = 1e-6
        @test reactive ≈ analysis.power.from.reactive[value] atol = 1e-6

        active, reactive = toPower(system14, analysisOrt; label = key)
        @test active ≈ analysis.power.to.active[value] atol = 1e-6
        @test reactive ≈ analysis.power.to.reactive[value] atol = 1e-6

        active, reactive = seriesPower(system14, analysisOrt; label = key)
        @test active ≈ analysis.power.series.active[value] atol = 1e-6
        @test reactive ≈ analysis.power.series.reactive[value] atol = 1e-6

        active, reactive = chargingPower(system14, analysisOrt; label = key)
        @test active ≈ analysis.power.charging.active[value] atol = 1e-6
        @test reactive ≈ analysis.power.charging.reactive[value] atol = 1e-6
    end

    ################ Modified IEEE 30-bus Test Case ################
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

    ######## Test Voltmeter Measurements #######
    device = measurement()
    for (key, value) in system30.bus.label
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], statusMagnitude = 0, polar = true)
        addVoltmeter!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], variance = 1e-4)
    end
    acStateEstimationTest(system30, device, analysis)

    ######## Test Wattmeter Measurements #######
    device = measurement()
    for (key, value) in system30.bus.label
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], statusAngle = 0, polar = true)
        addWattmeter!(system30, device; bus = key, active = analysis.power.injection.active[value], variance = 1e-3)
    end
    for (key, value) in system30.branch.label
        addWattmeter!(system30, device; from = key, active = analysis.power.from.active[value], variance = 1e-2)
        addWattmeter!(system30, device; to = key, active = analysis.power.to.active[value], variance = 1e-1)
    end
    acStateEstimationTest(system30, device, analysis)

    ######## Test Varmeter Measurements #######
    device = measurement()
    for (key, value) in system30.bus.label
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], polar = true)
        addVarmeter!(system30, device; bus = key, reactive = analysis.power.injection.reactive[value], variance = 1e-3)
    end
    for (key, value) in system30.branch.label
        addVarmeter!(system30, device; from = key, reactive = analysis.power.from.reactive[value], variance = 1e-3)
        addVarmeter!(system30, device; to = key, reactive = analysis.power.to.reactive[value], variance = 1e-3)
    end
    acStateEstimationTest(system30, device, analysis)

    ######## Test Rectangular PMU Measurements #######
    device = measurement()
    for (key, value) in system30.bus.label
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], polar = true)
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], correlated = true)
    end
    for (key, value) in system30.branch.label
        addPmu!(system30, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value])
        addPmu!(system30, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value])
        addPmu!(system30, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], correlated = true)
        addPmu!(system30, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], correlated = true)
    end
    acStateEstimationTest(system30, device, analysis)

    ###### Test All Measurements #######
    device = measurement()
    for (key, value) in system30.bus.label
        addVoltmeter!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value])
        addWattmeter!(system30, device; bus = key, active = analysis.power.injection.active[value])
        addVarmeter!(system30, device; bus = key, reactive = analysis.power.injection.reactive[value])
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], polar = true)
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value])
    end
    for (key, value) in system30.branch.label
        addWattmeter!(system30, device; from = key, active = analysis.power.from.active[value])
        addWattmeter!(system30, device; to = key, active = analysis.power.to.active[value])
        addVarmeter!(system30, device; from = key, reactive = analysis.power.from.reactive[value])
        addVarmeter!(system30, device; to = key, reactive = analysis.power.to.reactive[value])
        addPmu!(system30, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value])
        addPmu!(system30, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value])
    end
    acStateEstimationTest(system30, device, analysis)

    ####### Test Orthogonal Method #######
    analysisOrt = gaussNewton(system30, device, Orthogonal)
    for iteration = 1:100
        stopping = solve!(system30, analysisOrt)
        if stopping < 1e-8
            break
        end
    end
    @test analysisOrt.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisOrt.voltage.angle ≈ analysis.voltage.angle

    ####### Test Covariance Matrix #######
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
    addPmu!(system, device; bus = 3, magnitude = zv, angle = zθ, varianceMagnitude = vv, varianceAngle = vθ, correlated = true)
    covariance[1,1] = vv * (cos(zθ))^2 + vθ * (zv * sin(zθ))^2
    covariance[2,2] = vv * (sin(zθ))^2 + vθ * (zv * cos(zθ))^2
    covariance[1,2] = cos(zθ) * sin(zθ) * (vv - vθ * zv^2)
    covariance[2,1] = covariance[1,2]

    zv = 0.8; zθ = -0.3; vv = 0.5; vθ = 2.6
    addPmu!(system, device; from = 3, magnitude = zv, angle = zθ, varianceMagnitude = vv, varianceAngle = vθ)
    covariance[3,3] = vv * (cos(zθ))^2 + vθ * (zv * sin(zθ))^2
    covariance[4,4] = vv * (sin(zθ))^2 + vθ * (zv * cos(zθ))^2

    zv = 1.3; zθ = -0.2; vv = 1e-1; vθ = 0.2
    addPmu!(system, device; to = 2, magnitude = zv, angle = zθ, varianceMagnitude = vv, varianceAngle = vθ, correlated = true)
    covariance[5,5] = vv * (cos(zθ))^2 + vθ * (zv * sin(zθ))^2
    covariance[6,6] = vv * (sin(zθ))^2 + vθ * (zv * cos(zθ))^2
    covariance[5,6] = cos(zθ) * sin(zθ) * (vv - vθ * zv^2)
    covariance[6,5] = covariance[5,6]

    analysis = gaussNewton(system, device)
    @test inv(covariance) ≈ Matrix(analysis.method.precision)
end

system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))
@testset "PMU State Estimation" begin
    @default(template)
    @default(unit)

    ################ Test PMU State Estimation Function ################
    function pmuStateEstimationTest(system, device, analysis)
        analysisSE = pmuWlsStateEstimation(system, device)
        solve!(system, analysisSE)
        @test analysisSE.voltage.magnitude ≈ analysis.voltage.magnitude
        @test analysisSE.voltage.angle ≈ analysis.voltage.angle

        analysisLAV = pmuLavStateEstimation(system, device, Ipopt.Optimizer)
        JuMP.set_silent(analysisLAV.method.jump)
        solve!(system, analysisLAV)
        @test analysisLAV.voltage.magnitude ≈ analysis.voltage.magnitude
        @test analysisLAV.voltage.angle ≈ analysis.voltage.angle
    end

    ################ Modified IEEE 14-bus Test Case ################
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

    ######## Test Uncorrelated PMU Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value])
    end
    for (key, value) in system14.branch.label
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value])
        addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value])
    end
    pmuStateEstimationTest(system14, device, analysis)

    ###### Test QR Factorization #######
    analysisQR = pmuWlsStateEstimation(system14, device, QR)
    solve!(system14, analysisQR)
    @test analysisQR.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle

    ####### Test Orthogonal Method #######
    analysisOrt = pmuWlsStateEstimation(system14, device, Orthogonal)
    solve!(system14, analysisOrt)
    @test analysisOrt.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisOrt.voltage.angle ≈ analysis.voltage.angle

    ####### Test Powers #######
    power!(system14, analysisQR)
    @test analysisQR.power.injection.active ≈ analysis.power.injection.active
    @test analysisQR.power.injection.reactive ≈ analysis.power.injection.reactive
    @test analysisQR.power.supply.active ≈ analysis.power.supply.active
    @test analysisQR.power.supply.reactive ≈ analysis.power.supply.reactive
    @test analysisQR.power.shunt.active ≈ analysis.power.shunt.active
    @test analysisQR.power.shunt.reactive ≈ analysis.power.shunt.reactive
    @test analysisQR.power.from.active ≈ analysis.power.from.active
    @test analysisQR.power.from.reactive ≈ analysis.power.from.reactive
    @test analysisQR.power.to.active ≈ analysis.power.to.active
    @test analysisQR.power.to.reactive ≈ analysis.power.to.reactive
    @test analysisQR.power.series.active ≈ analysis.power.series.active
    @test analysisQR.power.series.reactive ≈ analysis.power.series.reactive
    @test analysisQR.power.charging.active ≈ analysis.power.charging.active
    @test analysisQR.power.charging.reactive ≈ analysis.power.charging.reactive

    ####### Test Specific Bus Powers #######
    for (key, value) in system14.bus.label
        active, reactive = injectionPower(system14, analysisQR; label = key)
        @test active ≈ analysis.power.injection.active[value] atol = 1e-6
        @test reactive ≈ analysis.power.injection.reactive[value] atol = 1e-6

        active, reactive = supplyPower(system14, analysisQR; label = key)
        @test active ≈ analysis.power.supply.active[value] atol = 1e-6
        @test reactive ≈ analysis.power.supply.reactive[value] atol = 1e-6

        active, reactive = shuntPower(system14, analysisQR; label = key)
        @test active ≈ analysis.power.shunt.active[value] atol = 1e-6
        @test reactive ≈ analysis.power.shunt.reactive[value] atol = 1e-6
    end

    ####### Test Specific Branch Powers #######
    for (key, value) in system14.branch.label
        active, reactive = fromPower(system14, analysisQR; label = key)
        @test active ≈ analysis.power.from.active[value] atol = 1e-6
        @test reactive ≈ analysis.power.from.reactive[value] atol = 1e-6

        active, reactive = toPower(system14, analysisQR; label = key)
        @test active ≈ analysis.power.to.active[value] atol = 1e-6
        @test reactive ≈ analysis.power.to.reactive[value] atol = 1e-6

        active, reactive = seriesPower(system14, analysisQR; label = key)
        @test active ≈ analysis.power.series.active[value] atol = 1e-6
        @test reactive ≈ analysis.power.series.reactive[value] atol = 1e-6

        active, reactive = chargingPower(system14, analysisQR; label = key)
        @test active ≈ analysis.power.charging.active[value] atol = 1e-6
        @test reactive ≈ analysis.power.charging.reactive[value] atol = 1e-6
    end

    ######## Test Correlated PMU Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], correlated = true)
    end
    for (key, value) in system14.branch.label
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], correlated = true)
        addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], correlated = true)
    end
    pmuStateEstimationTest(system14, device, analysis)

    ################ Modified IEEE 30-bus Test Case ################
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

    ######## Test PMU Measurements #######
    device = measurement()
    for (key, value) in system30.bus.label
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], varianceAngle = 1e-2, varianceMagnitude = varianceAngle = 1e-3)
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], varianceAngle = 1e-6, varianceMagnitude = varianceAngle = 1e-5, correlated = true)
    end
    for (key, value) in system30.branch.label
        addPmu!(system30, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], varianceAngle = 1e-7, varianceMagnitude = varianceAngle = 1e-6, correlated = true)
        addPmu!(system30, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], varianceAngle = 1e-4, varianceMagnitude = varianceAngle = 1e-5)
    end
    pmuStateEstimationTest(system30, device, analysis)
end

system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))
@testset "DC State Estimation" begin
    @default(template)
    @default(unit)

    ################ Test DC State Estimation Function ################
    function dcStateEstimationTest(system, device, analysis)
        analysisSE = dcWlsStateEstimation(system, device)
        solve!(system, analysisSE)
        @test analysisSE.voltage.angle ≈ analysis.voltage.angle

        analysisLAV = dcLavStateEstimation(system, device, Ipopt.Optimizer)
        JuMP.set_silent(analysisLAV.method.jump)
        solve!(system, analysisLAV)
        @test analysisLAV.voltage.angle ≈ analysis.voltage.angle

        return analysisSE
    end

    ############### Modified IEEE 14-bus Test Case ################
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)

    dcModel!(system14)
    analysis = dcPowerFlow(system14)
    solve!(system14, analysis)
    power!(system14, analysis)
    device = measurement()

    ######## Test Bus Wattmeter Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = 1.0, angle = analysis.voltage.angle[value], polar = true)
        addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[value], variance = 1e-3)
    end
    dcStateEstimationTest(system14, device, analysis)

    ######## Test Branch Wattmeter Measurements #######
    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = 1.0, angle = analysis.voltage.angle[value], polar = true)
    end
    for (key, value) in system14.branch.label
        addWattmeter!(system14, device; from = key, active = analysis.power.from.active[value])
        addWattmeter!(system14, device; to = key, active = analysis.power.to.active[value])
    end
    analysisSE = dcStateEstimationTest(system14, device, analysis)

    @capture_out printPmuData(system14, device, analysisSE)
    @capture_out printPmuData(system14, device, analysisSE; label = 1, header = true)
    @capture_out printPmuData(system14, device, analysisSE; label = 6)
    @capture_out printPmuData(system14, device, analysisSE; label = 8, footer = true)

    ######## Test Wattmeters ########
    for (key, value) in system14.bus.label
        addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[value])
    end
    for (key, value) in system14.branch.label
        addWattmeter!(system14, device; from = key, active = analysis.power.from.active[value])
        addWattmeter!(system14, device; to = key, active = analysis.power.to.active[value])
    end
    analysisSE = dcStateEstimationTest(system14, device, analysis)

    @capture_out printWattmeterData(system14, device, analysisSE)
    @capture_out printWattmeterData(system14, device, analysisSE; label = 1, header = true)
    @capture_out printWattmeterData(system14, device, analysisSE; label = 6)
    @capture_out printWattmeterData(system14, device, analysisSE; label = 8, footer = true)

    ###### Test QR Factorization #######
    analysisQR = dcWlsStateEstimation(system14, device, QR)
    solve!(system14, analysisQR)
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle

    ####### Test Orthogonal Method #######
    analysisOrt = dcWlsStateEstimation(system14, device, Orthogonal)
    solve!(system14, analysisOrt)
    @test analysisOrt.voltage.angle ≈ analysis.voltage.angle

    ####### Test Powers #######
    power!(system14, analysisOrt)
    @test analysisOrt.power.injection.active ≈ analysis.power.injection.active
    @test analysisOrt.power.supply.active ≈ analysis.power.supply.active
    @test analysisOrt.power.from.active ≈ analysis.power.from.active
    @test analysisOrt.power.to.active ≈ analysis.power.to.active

    ####### Test Specific Bus Powers #######
    for (key, value) in system14.bus.label
        @test injectionPower(system14, analysisOrt; label = key) ≈ analysis.power.injection.active[value] atol = 1e-6
        @test supplyPower(system14, analysisOrt; label = key) ≈ analysis.power.supply.active[value] atol = 1e-6
    end

    ####### Test Specific Branch Powers #######
    for (key, value) in system14.branch.label
        @test fromPower(system14, analysisOrt; label = key) ≈ analysis.power.from.active[value] atol = 1e-6
        @test toPower(system14, analysisOrt; label = key) ≈ analysis.power.to.active[value] atol = 1e-6
    end

    ################ Modified IEEE 30-bus Test Case ################
    dcModel!(system30)
    analysis = dcPowerFlow(system30)
    solve!(system30, analysis)
    power!(system30, analysis)

    ######## Test Wattmeters ########
    device = measurement()
    for (key, value) in system30.bus.label
        addWattmeter!(system30, device; bus = key, active = analysis.power.injection.active[value], variance = 1e-6)
    end
    for (key, value) in system30.branch.label
        addWattmeter!(system30, device; from = key, active = analysis.power.from.active[value], variance = 1e-7)
        addWattmeter!(system30, device; to = key, active = analysis.power.to.active[value], variance = 1e-8)
    end
    dcStateEstimationTest(system30, device, analysis)

    ####### Test Orthogonal Method #######
    analysisOrt = dcWlsStateEstimation(system30, device, Orthogonal)
    solve!(system30, analysisOrt)
    @test analysisOrt.voltage.angle ≈ analysis.voltage.angle
end