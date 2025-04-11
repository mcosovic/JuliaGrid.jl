system14 = powerSystem(path * "case14test.m")
system30 = powerSystem(path * "case30test.m")
@testset "AC State Estimation" begin
    @default(template)
    @default(unit)

    ########## IEEE 14-bus Test Case ##########
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.25)
    updateBus!(system14; label = 1, magnitude = 1.0)
    updateBus!(system14; label = 3, magnitude = 1.2)
    updateBus!(system14; label = 4, magnitude = 1.0)
    updateBus!(system14; label = 5, magnitude = 1.1)
    updateBranch!(system14; label = 3, conductance = 0.01)
    updateBranch!(system14; label = 6, conductance = 0.05)

    acModel!(system14)
    pf = newtonRaphson(system14)
    powerFlow!(pf; power = true, current = true)

    monitoring = measurement(system14)
    @pmu(varianceMagnitudeBus = 1, varianceAngleBus = 1)
    addPmu!( monitoring, pf; statusFrom = -1, statusTo = -1, polar = true)

    @testset "IEEE 14: Voltmeter Measurements" begin
        meter = deepcopy(monitoring)

        @voltmeter(variance = 1e-4)
        addVoltmeter!(meter, pf)
        testAcEstimation(meter, pf)
    end

    @testset "IEEE 14: Ammeter Measurements" begin
        meter = deepcopy(monitoring)

        @ammeter(varianceFrom = 1e-2, varianceTo = 1e-2)
        addAmmeter!(meter, pf)
        testAcEstimation(meter, pf)
    end

    @testset "IEEE 14: Ammeter Squared Measurements" begin
        meter = deepcopy(monitoring)

        @ammeter(varianceFrom = 1e-4, varianceTo = 1e-4)
        addAmmeter!(meter, pf; square = true)
        testAcEstimation(meter, pf)
    end

    @testset "IEEE 14: Bus Wattmeter Measurements" begin
        meter = deepcopy(monitoring)

        @wattmeter(varianceBus = 1e-4)
        addWattmeter!(meter, pf; statusFrom = -1, statusTo = -1)
        testAcEstimation(meter, pf)
    end

    @testset "IEEE 14: Branch Wattmeter Measurements" begin
        meter = deepcopy(monitoring)

        @wattmeter(varianceFrom = 1e-4, varianceTo = 1e-4)
        addWattmeter!(meter, pf; statusBus = -1)
        testAcEstimation(meter, pf)
    end

    @testset "IEEE 14: Bus Varmeter Measurements" begin
        meter = deepcopy(monitoring)

        @varmeter(varianceBus = 1e-4)
        addVarmeter!(meter, pf; statusFrom = -1, statusTo = -1)
        testAcEstimation(meter, pf)
    end

    @testset "IEEE 14: Branch Varmeter Measurements" begin
        meter = deepcopy(monitoring)

        @varmeter(varianceFrom = 1e-2, varianceTo = 1e-2)
        addVarmeter!(meter, pf; statusBus = -1)
        testAcEstimation(meter, pf)
    end

    @testset "IEEE 14: PMU Bus Rectangular Correlated Measurements" begin
        monitoring = measurement(system14)

        addPmu!(
            monitoring, pf; varianceMagnitudeBus = 1e-4, varianceAngleBus = 1e-4,
            statusFrom = -1, statusTo = -1, correlated = true)
        addPmuBus(monitoring, pf)
        testAcEstimation(monitoring, pf)
    end

    @testset "IEEE 14: PMU Branch Rectangular Measurements" begin
        monitoring = measurement(system14)

        @pmu(varianceMagnitudeFrom = 1e-4, varianceAngleFrom = 1e-4)
        @pmu(varianceMagnitudeTo = 1e-4, varianceAngleTo = 1e-4)
        addPmu!(monitoring, pf; statusBus = -1)
        addPmuBus(monitoring, pf)
        testAcEstimation(monitoring, pf)
    end

    @testset "IEEE 14: PMU Branch Rectangular Correlated Measurements" begin
        monitoring = measurement(system14)

        addPmu!(monitoring, pf; statusBus = -1, correlated = true)
        addPmuBus(monitoring, pf)
        testAcEstimation(monitoring, pf)
    end

    @testset "IEEE 14: PMU From-Branch Polar Measurements" begin
        monitoring = measurement(system14)

        @pmu(varianceMagnitudeFrom = 1e-2, varianceAngleFrom = 1e-2)
        addPmu!(monitoring, pf; statusBus = -1, statusTo = -1, polar = true)
        addPmuBus(monitoring, pf)
        monitoring.pmu.magnitude.status[[2, 14, 18]] .= 0
        monitoring.pmu.angle.status[[14, 18]] .= 0

        testAcEstimation(monitoring, pf)
    end

    @testset "IEEE 14: PMU From-Branch Polar Squared Measurements" begin
        monitoring = measurement(system14)

        @pmu(varianceMagnitudeFrom = 1e-2, varianceAngleFrom = 1e-2)
        addPmu!(monitoring, pf; statusBus = -1, statusTo = -1, polar = true, square = true)
        addPmuBus(monitoring, pf)
        monitoring.pmu.magnitude.status[[14, 18]] .= 0
        monitoring.pmu.angle.status[[14, 18]] .= 0

        testAcEstimation(monitoring, pf)
    end

    @testset "IEEE 14: PMU To-Branch Polar Measurements" begin
        monitoring = measurement(system14)

        @pmu(varianceMagnitudeTo = 1e-2, varianceAngleTo = 1e-2)
        addPmu!(monitoring, pf; statusBus = -1, statusFrom = -1, statusTo = 0, polar = true)
        addPmuBus(monitoring, pf)

        monitoring.pmu.magnitude.status[4] = 1
        monitoring.pmu.magnitude.status[8] = 1
        monitoring.pmu.magnitude.status[12] = 1
        monitoring.pmu.magnitude.status[16] = 1
        monitoring.pmu.magnitude.status[18] = 1

        monitoring.pmu.angle.status[3] = 1
        monitoring.pmu.angle.status[5] = 1
        monitoring.pmu.angle.status[8] = 1
        monitoring.pmu.angle.status[13] = 1
        monitoring.pmu.angle.status[18] = 1

        testAcEstimation(monitoring, pf)
    end

    @testset "IEEE 14: PMU To-Branch Polar Squared Measurements" begin
        monitoring = measurement(system14)

        @pmu(varianceMagnitudeTo = 1e-2, varianceAngleTo = 1e-2)
        addPmu!(monitoring, pf; statusBus = -1, statusFrom = -1, statusTo = 0, polar = true, square = true)
        addPmuBus(monitoring, pf)

        monitoring.pmu.magnitude.status[4] = 1
        monitoring.pmu.magnitude.status[8] = 1
        monitoring.pmu.magnitude.status[12] = 1
        monitoring.pmu.magnitude.status[16] = 1
        monitoring.pmu.magnitude.status[18] = 1

        testAcEstimation(monitoring, pf)
    end

    monitoring = measurement(system14)
    @testset "IEEE 14: All Measurements" begin
        addVoltmeter!(monitoring, pf)
        addAmmeter!(monitoring, pf)
        addWattmeter!(monitoring, pf)
        addVarmeter!(monitoring, pf)
        addPmu!(monitoring, pf)
        testAcEstimation(monitoring, pf)
    end

    @testset "IEEE 14: QR Factorization" begin
        analysisQR = gaussNewton(monitoring, QR)
        stateEstimation!(analysisQR)

        teststruct(analysisQR.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "IEEE 14: Orthogonal Method" begin
        orthogonal = gaussNewton(monitoring, Orthogonal)
        stateEstimation!(orthogonal; power = true, current = true)

        teststruct(orthogonal.voltage, pf.voltage; atol = 1e-10)
        teststruct(orthogonal.power, pf.power; atol = 1e-10)
    end

    ########## IEEE 30-bus Test Case ##########
    acModel!(system30)
    pf = newtonRaphson(system30)
    powerFlow!(pf; power = true, current = true)

    monitoring = measurement(system30)
    addPmu!(monitoring, pf; statusFrom = -1, statusTo = -1, polar = true)

    @testset "IEEE 30: Voltmeter Measurements" begin
        meter = deepcopy(monitoring)

        addVoltmeter!(meter, pf; variance = 1e-4)
        testAcEstimation(meter, pf)
    end

    @testset "IEEE 30: Wattmeter Measurements" begin
        meter = deepcopy(monitoring)

        addWattmeter!(meter, pf; varianceBus = 1e-2, varianceFrom = 1e-2, varianceTo = 1e-2)
        testAcEstimation(meter, pf)
    end

    @testset "IEEE 30: Varmeter Measurements" begin
        meter = deepcopy(monitoring)

        addVarmeter!(meter, pf)
        testAcEstimation(meter, pf)
    end

    @testset "IEEE 30: Rectangular PMU Measurements" begin
        monitoring = measurement(system30)

        addPmu!(monitoring, pf; correlated = true)
        addPmuBus(monitoring, pf)
        testAcEstimation(monitoring, pf)
    end

    monitoring = measurement(system30)

    @testset "IEEE 30: All Measurements" begin
        addVoltmeter!(monitoring, pf)
        addWattmeter!(monitoring, pf)
        addVarmeter!(monitoring, pf)
        addPmu!(monitoring, pf)
        testAcEstimation(monitoring, pf)
    end

    @testset "IEEE 30: Orthogonal Method" begin
        orthogonal = gaussNewton(monitoring, Orthogonal)
        stateEstimation!(orthogonal; tolerance = 1e-10, power = true)

        teststruct(orthogonal.voltage, pf.voltage; atol = 1e-8)
        teststruct(orthogonal.power, pf.power; atol = 1e-8)
    end

    @testset "IEEE 30: Covariance Matrix" begin
        system, monitoring = ems()
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
            monitoring; bus = 3, magnitude = zv, angle = zθ,
            varianceMagnitude = vv, varianceAngle = vθ, correlated = true
        )
        covariance[1,1] = vv * (cos(zθ))^2 + vθ * (zv * sin(zθ))^2
        covariance[2,2] = vv * (sin(zθ))^2 + vθ * (zv * cos(zθ))^2
        covariance[1,2] = cos(zθ) * sin(zθ) * (vv - vθ * zv^2)
        covariance[2,1] = covariance[1,2]

        zv = 0.8; zθ = -0.3; vv = 0.5; vθ = 2.6
        addPmu!(
            monitoring;
            from = 3, magnitude = zv, angle = zθ, varianceMagnitude = vv, varianceAngle = vθ
        )
        covariance[3,3] = vv * (cos(zθ))^2 + vθ * (zv * sin(zθ))^2
        covariance[4,4] = vv * (sin(zθ))^2 + vθ * (zv * cos(zθ))^2

        zv = 1.3; zθ = -0.2; vv = 1e-1; vθ = 0.2
        addPmu!(
            monitoring; to = 2, magnitude = zv, angle = zθ, varianceMagnitude = vv,
            varianceAngle = vθ, correlated = true
        )
        covariance[5,5] = vv * (cos(zθ))^2 + vθ * (zv * sin(zθ))^2
        covariance[6,6] = vv * (sin(zθ))^2 + vθ * (zv * cos(zθ))^2
        covariance[5,6] = cos(zθ) * sin(zθ) * (vv - vθ * zv^2)
        covariance[6,5] = covariance[5,6]

        analysis = gaussNewton(monitoring)
        @test inv(covariance) ≈ Matrix(analysis.method.precision)
    end
end

system14 = powerSystem(path * "case14test.m")
system30 = powerSystem(path * "case30test.m")
@testset "PMU State Estimation" begin
    @default(template)
    @default(unit)

    ########## IEEE 14-bus Test Case ##########
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)
    updateBranch!(system14; label = 3, conductance = 0.01)
    updateBranch!(system14; label = 6, conductance = 0.05)

    acModel!(system14)
    pf = newtonRaphson(system14)
    powerFlow!(pf; power = true, current = true)

    monitoring = measurement(system14)

    @testset "IEEE 14: Uncorrelated PMU Measurements" begin
        addPmu!(monitoring, pf)
        testPmuEstimation(monitoring, pf)
    end

    @testset "IEEE 14: QR Factorization" begin
        analysisQR = pmuStateEstimation(monitoring, QR)
        stateEstimation!(analysisQR; power = true)

        teststruct(analysisQR.voltage, pf.voltage; atol = 1e-10)
        teststruct(analysisQR.power, pf.power; atol = 1e-10)
    end

    @testset "IEEE 14: Orthogonal Method" begin
        orthogonal = pmuStateEstimation(monitoring, Orthogonal)
        stateEstimation!(orthogonal; power = true)

        teststruct(orthogonal.voltage, pf.voltage; atol = 1e-10)
        teststruct(orthogonal.power, pf.power; atol = 1e-10)
    end

    @testset "IEEE 14: Correlated PMU Measurements" begin
        monitoring = measurement(system14)

        addPmu!(monitoring, pf; correlated = true)
        testPmuEstimation(monitoring, pf)
    end

    ########## IEEE 30-bus Test Case ##########
    acModel!(system30)
    pf = newtonRaphson(system30)
    powerFlow!(pf; power = true, current = true)

    @testset "IEEE 30: Uncorrelated PMU Measurements" begin
        monitoring = measurement(system30)

        addPmu!(monitoring, pf)
        testPmuEstimation(monitoring, pf)
    end

    @testset "IEEE 30: Correlated PMU Measurements" begin
        monitoring = measurement(system30)

        @pmu(varianceMagnitudeFrom = 1e-4, varianceAngleFrom = 1e-4)
        @pmu(varianceMagnitudeTo = 1e-4, varianceAngleTo = 1e-4)
        addPmu!(monitoring, pf; correlated = true)
        testPmuEstimation(monitoring, pf)
    end
end

system14 = powerSystem(path * "case14test.m")
system30 = powerSystem(path * "case30test.m")
@testset "DC State Estimation" begin
    @default(template)
    @default(unit)

    ########## IEEE 14-bus Test Case ##########
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)

    dcModel!(system14)
    pf = dcPowerFlow(system14)
    powerFlow!(pf; power = true)

    @testset "IEEE 14: Bus Wattmeter Measurements" begin
        monitoring = measurement(system14)

        for (key, idx) in system14.bus.label
            addPmu!(monitoring; bus = key, magnitude = 1.0, angle = pf.voltage.angle[idx])
            addWattmeter!(monitoring; bus = key, active = pf.power.injection.active[idx])
        end
        testDcEstimation(monitoring, pf)
    end

    @testset "IEEE 14: Branch Wattmeter Measurements" begin
        monitoring = measurement(system14)

        for (key, idx) in system14.bus.label
            addPmu!(monitoring; bus = key, magnitude = 1.0, angle = pf.voltage.angle[idx])
        end
        for (key, idx) in system14.branch.label
            addWattmeter!(monitoring; from = key, active = pf.power.from.active[idx])
            addWattmeter!(monitoring; to = key, active = pf.power.to.active[idx])
        end
        testDcEstimation(monitoring, pf)
    end

    monitoring = measurement(system14)

    @testset "IEEE 14: Wattmeter Measurements" begin
        for (key, idx) in system14.bus.label
            addWattmeter!(monitoring; bus = key, active = pf.power.injection.active[idx])
        end
        for (key, idx) in system14.branch.label
            addWattmeter!(monitoring; from = key, active = pf.power.from.active[idx])
            addWattmeter!(monitoring; to = key, active = pf.power.to.active[idx])
        end
        testDcEstimation(monitoring, pf)
    end

    @testset "IEEE 14: QR Factorization" begin
        analysisQR = dcStateEstimation(monitoring, QR)
        solve!(analysisQR)
        @test analysisQR.voltage.angle ≈ pf.voltage.angle
    end

    @testset "IEEE 14: Orthogonal Method" begin
        orthogonal = dcStateEstimation(monitoring, Orthogonal)
        stateEstimation!(orthogonal; power = true)

        @test orthogonal.voltage.angle ≈ pf.voltage.angle
        teststruct(orthogonal.power, pf.power; atol = 1e-10)
    end

    ########## IEEE 30-bus Test Case ##########
    dcModel!(system30)
    pf = dcPowerFlow(system30)
    powerFlow!(pf; power = true)

    monitoring = measurement(system30)

    @testset "IEEE 30: Wattmeter Measurements" begin
        for (key, idx) in system30.bus.label
            addWattmeter!(monitoring; bus = key, active = pf.power.injection.active[idx])
        end
        for (key, idx) in system30.branch.label
            addWattmeter!(monitoring; from = key, active = pf.power.from.active[idx])
            addWattmeter!(monitoring; to = key, active = pf.power.to.active[idx])
        end
        testDcEstimation(monitoring, pf)
    end

    @testset "IEEE 30: Orthogonal Method" begin
        orthogonal = dcStateEstimation(monitoring, Orthogonal)
        stateEstimation!(orthogonal; power = true)

        @test orthogonal.voltage.angle ≈ pf.voltage.angle
        teststruct(orthogonal.power, pf.power; atol = 1e-10)
    end
end

@testset "Print Data in Per-Units" begin
    system, monitoring = ems(path * "case14test.m", "measurement14.h5")

    addPmu!(monitoring; bus = 1, magnitude = 1.0, angle = 0.0)
    addPmu!(monitoring; bus = 3, magnitude = 1.1, angle = -0.3)

    ########## Print AC Data ##########
    analysis = gaussNewton(monitoring)
    stateEstimation!(analysis; power = true, current = true)

    @suppress @testset "Print Voltmeter AC Data" begin
        width = Dict("Voltage Magnitude Residual" => 10)
        show = Dict("Voltage Magnitude Estimate" => false)
        fmt = Dict("Voltage Magnitude" => "%.2f")

        printVoltmeterData(analysis; width, show, fmt, repeat = 10)
        printVoltmeterData(analysis; label = 1, header = true)
        printVoltmeterData(analysis; label = 2, footer = true)
        printVoltmeterData(analysis; style = false)
        printVoltmeterData(monitoring)
    end

    @suppress @testset "Print Ammeter AC Data" begin
        show = Dict("Current Magnitude Status" => false)

        printAmmeterData(analysis; show, repeat = 10)
        printAmmeterData(analysis; label = "From 1", header = true)
        printAmmeterData(analysis; label = "From 2", footer = true)
        printAmmeterData(analysis; style = false)
        printAmmeterData(monitoring)
    end

    @suppress @testset "Print Wattmeter AC Data" begin
        printWattmeterData(analysis; repeat = 10)
        printWattmeterData(analysis; label = 1, header = true)
        printWattmeterData(analysis; label = 4, footer = true)
        printWattmeterData(analysis; style = false)
        printWattmeterData(monitoring)
    end

    @suppress @testset "Print Varmeter AC Data" begin
        printVarmeterData(analysis; repeat = 10)
        printVarmeterData(analysis; label = 1, header = true)
        printVarmeterData(analysis; label = 4, footer = true)
        printVarmeterData(analysis; style = false)
        printVarmeterData(monitoring; style = false)
    end

    @suppress @testset "Print PMU AC Data" begin
        printPmuData(analysis; repeat = 10)
        printPmuData(analysis; label = "From 1", header = true)
        printPmuData(analysis; label = "From 4", footer = true)
        printPmuData(analysis; style = false)
        printPmuData(analysis; label = "From 1", style = false)
        printPmuData(analysis; label = 10, style = false)
        printPmuData(monitoring)
    end

    ########## Print DC Data ##########
    analysis = dcStateEstimation(monitoring)
    stateEstimation!(analysis; power = true)

    @suppress @testset "Print Wattmeter DC Data" begin
        printWattmeterData(analysis; repeat = 10)
        printWattmeterData(analysis; label = 1, header = true)
        printWattmeterData(analysis; label = 4, footer = true)
        printWattmeterData(analysis; style = false)
    end

    @suppress @testset "Print PMU DC Data" begin
        printPmuData(analysis; repeat = 10)
        printPmuData(analysis; label = 10, header = true)
        printPmuData(analysis; label = 12, footer = true)
        printPmuData(analysis; style = false)
    end
end

@testset "Print Data in SI Units" begin
    system, monitoring = ems(path * "case14test.m", "measurement14.h5")

    addPmu!(monitoring; bus = 1, magnitude = 1.0, angle = 0.0)
    addPmu!(monitoring; bus = 3, magnitude = 1.1, angle = -0.3)

    @power(GW, MVAr, MVA)
    @voltage(kV, deg, V)
    @current(MA, deg)

    ########## Print AC Data ##########
    analysis = gaussNewton(monitoring)
    stateEstimation!(analysis; power = true, current = true)

    @suppress @testset "Print Voltmeter AC Data" begin
        printVoltmeterData(analysis)
        printVoltmeterData(analysis; label = 1)
    end

    @suppress @testset "Print Ammeter AC Data" begin
        printAmmeterData(analysis)
        printAmmeterData(analysis; label = "From 1")
    end

    @suppress @testset "Print Wattmeter AC Data" begin
        printWattmeterData(analysis)
        printWattmeterData(analysis; label = 1)
    end

    @suppress @testset "Print Varmeter AC Data" begin
        printVarmeterData(analysis)
        printVarmeterData(analysis; label = 1)
    end

    @suppress @testset "Print PMU AC Data" begin
        printPmuData(analysis)
        printPmuData(analysis; label = "From 1")
        printPmuData(analysis; label = 9)
    end

    ########## Print DC Data ##########
    analysis = dcStateEstimation(monitoring)
    stateEstimation!(analysis; power = true)

    @suppress @testset "Print Wattmeter DC Data" begin
        printWattmeterData(analysis)
        printWattmeterData(analysis; label = 1)
    end

    @suppress @testset "Print PMU DC Data" begin
        printPmuData(analysis)
        printPmuData(analysis; label = 9)
    end
end