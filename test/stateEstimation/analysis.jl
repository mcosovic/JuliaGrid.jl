system14 = powerSystem(path * "case14test.m")
system30 = powerSystem(path * "case30test.m")
@testset "AC State Estimation" begin
    @default(template)
    @default(unit)

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
    pf = newtonRaphson(system14)
    powerFlow!(system14, pf; power = true, current = true)

    device = measurement()
    @pmu(varianceMagnitudeBus = 1e-4, varianceAngleBus = 1e-4)
    addPmu!(system14, device, pf; statusFrom = -1, statusTo = -1, polar = true)

    @testset "IEEE 14: Voltmeter Measurements" begin
        meter = deepcopy(device)

        @voltmeter(variance = 1e-4)
        addVoltmeter!(system14, meter, pf)
        testEstimation(system14, meter, pf)
    end

    @testset "IEEE 14: Ammeter Measurements" begin
        meter = deepcopy(device)

        @ammeter(varianceFrom = 1e-4, varianceTo = 1e-4)
        addAmmeter!(system14, meter, pf)
        testEstimation(system14, meter, pf)
    end

    @testset "IEEE 14: Bus Wattmeter Measurements" begin
        meter = deepcopy(device)

        @wattmeter(varianceBus = 1e-4)
        addWattmeter!(system14, meter, pf; statusFrom = -1, statusTo = -1)
        testEstimation(system14, meter, pf)
    end

    @testset "IEEE 14: Branch Wattmeter Measurements" begin
        meter = deepcopy(device)

        @wattmeter(varianceFrom = 1e-4, varianceTo = 1e-4)
        addWattmeter!(system14, meter, pf; statusBus = -1)
        testEstimation(system14, meter, pf)
    end

    @testset "IEEE 14: Bus Varmeter Measurements" begin
        meter = deepcopy(device)

        @varmeter(varianceBus = 1e-4)
        addVarmeter!(system14, meter, pf; statusFrom = -1, statusTo = -1)
        testEstimation(system14, meter, pf)
    end

    @testset "IEEE 14: Branch Varmeter Measurements" begin
        meter = deepcopy(device)

        @varmeter(varianceFrom = 1e-4, varianceTo = 1e-4)
        addVarmeter!(system14, meter, pf; statusBus = -1)
        testEstimation(system14, meter, pf)
    end

    @testset "IEEE 14: Bus Rectangular PMU Measurements" begin
        device = measurement()

        addPmu!(system14, device, pf; statusFrom = -1, statusTo = -1, correlated = true)
        addPmuBus(system14, device, pf)
        testEstimation(system14, device, pf)
    end

    @testset "IEEE 14: Branch Rectangular PMU Measurements" begin
        device = measurement()

        @pmu(varianceMagnitudeFrom = 1e-4, varianceAngleFrom = 1e-4)
        @pmu(varianceMagnitudeTo = 1e-4, varianceAngleTo = 1e-4)
        addPmu!(system14, device, pf; statusBus = -1)
        addPmuBus(system14, device, pf)
        testEstimation(system14, device, pf)
    end

    @testset "IEEE 14: Branch Rectangular Correlated PMU Measurements" begin
        device = measurement()

        addPmu!(system14, device, pf; statusBus = -1, correlated = true)
        addPmuBus(system14, device, pf)
        testEstimation(system14, device, pf)
    end

    @testset "IEEE 14: From-Branch Polar PMU Measurements" begin
        device = measurement()

        addPmu!(system14, device, pf; statusBus = -1, statusTo = -1, polar = true)
        addPmuBus(system14, device, pf)

        device.pmu.magnitude.status[[5, 7, 15, 19, 20]] .= 0
        device.pmu.angle.status[[5, 7, 15, 19, 20]] .= 0

        testEstimation(system14, device, pf)
    end

    @testset "IEEE 14: To-Branch Polar PMU Measurements" begin
        device = measurement()

        addPmu!(system14, device, pf; statusBus = -1, statusFrom = -1, polar = true)
        addPmuBus(system14, device, pf)

        device.pmu.magnitude.status[[2, 3, 4, 6, 8, 11, 12, 16, 18, 20]] .= 0
        device.pmu.angle.status[[2, 3, 4, 6, 8, 11, 12, 16, 18, 20]] .= 0

        testEstimation(system14, device, pf; warm = true)
    end

    device = measurement()
    @testset "IEEE 14: All Measurements" begin
        addVoltmeter!(system14, device, pf)
        addAmmeter!(system14, device, pf)
        addWattmeter!(system14, device, pf)
        addVarmeter!(system14, device, pf)
        addPmu!(system14, device, pf)
        testEstimation(system14, device, pf)
    end

    @testset "IEEE 14: QR Factorization" begin
        analysisQR = gaussNewton(system14, device, QR)
        stateEstimation!(system14, analysisQR)

        compstruct(analysisQR.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "IEEE 14: Orthogonal Method" begin
        orthogonal = gaussNewton(system14, device, Orthogonal)
        stateEstimation!(system14, orthogonal; power = true, current = true)

        compstruct(orthogonal.voltage, pf.voltage; atol = 1e-10)
        compstruct(orthogonal.power, pf.power; atol = 1e-10)
    end

    ########## IEEE 30-bus Test Case ##########
    acModel!(system30)
    pf = newtonRaphson(system30)
    powerFlow!(system30, pf; power = true, current = true)

    device = measurement()
    addPmu!(system30, device, pf; statusFrom = -1, statusTo = -1, polar = true)

    @testset "IEEE 30: Voltmeter Measurements" begin
        meter = deepcopy(device)

        addVoltmeter!(system30, meter, pf; variance = 1e-4)
        testEstimation(system30, meter, pf)
    end

    @testset "IEEE 30: Wattmeter Measurements" begin
        meter = deepcopy(device)

        addWattmeter!(system30, meter, pf)
        testEstimation(system30, meter, pf)
    end

    @testset "IEEE 30: Varmeter Measurements" begin
        meter = deepcopy(device)

        addVarmeter!(system30, meter, pf)
        testEstimation(system30, meter, pf)
    end

    @testset "IEEE 30: Rectangular PMU Measurements" begin
        device = measurement()

        addPmu!(system30, device, pf; correlated = true)
        addPmuBus(system30, device, pf)
        testEstimation(system30, device, pf)
    end

    device = measurement()

    @testset "IEEE 30: All Measurements" begin
        addVoltmeter!(system30, device, pf)
        addWattmeter!(system30, device, pf)
        addVarmeter!(system30, device, pf)
        addPmu!(system30, device, pf)
        testEstimation(system30, device, pf)
    end

    @testset "IEEE 30: Orthogonal Method" begin
        orthogonal = gaussNewton(system30, device, Orthogonal)
        stateEstimation!(system30, orthogonal; tolerance = 1e-10, power = true)

        compstruct(orthogonal.voltage, pf.voltage; atol = 1e-8)
        compstruct(orthogonal.power, pf.power; atol = 1e-8)
    end

    @testset "IEEE 30: Covariance Matrix" begin
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
    powerFlow!(system14, pf; power = true, current = true)

    device = measurement()

    @testset "IEEE 14: Uncorrelated PMU Measurements" begin
        addPmu!(system14, device, pf)
        testPmuEstimation(system14, device, pf)
    end

    @testset "IEEE 14: QR Factorization" begin
        analysisQR = pmuStateEstimation(system14, device, QR)
        stateEstimation!(system14, analysisQR; power = true)

        compstruct(analysisQR.voltage, pf.voltage; atol = 1e-10)
        compstruct(analysisQR.power, pf.power; atol = 1e-10)
    end

    @testset "IEEE 14: Orthogonal Method" begin
        orthogonal = pmuStateEstimation(system14, device, Orthogonal)
        stateEstimation!(system14, orthogonal; power = true)

        compstruct(orthogonal.voltage, pf.voltage; atol = 1e-10)
        compstruct(orthogonal.power, pf.power; atol = 1e-10)
    end

    @testset "IEEE 14: Correlated PMU Measurements" begin
        device = measurement()

        addPmu!(system14, device, pf; correlated = true)
        testPmuEstimation(system14, device, pf)
    end

    ########## IEEE 30-bus Test Case ##########
    acModel!(system30)
    pf = newtonRaphson(system30)
    powerFlow!(system30, pf; power = true, current = true)

    @testset "IEEE 30: Uncorrelated PMU Measurements" begin
        device = measurement()

        addPmu!(system30, device, pf)
        testPmuEstimation(system30, device, pf)
    end

    @testset "IEEE 30: Correlated PMU Measurements" begin
        device = measurement()

        @pmu(varianceMagnitudeFrom = 1e-4, varianceAngleFrom = 1e-4)
        @pmu(varianceMagnitudeTo = 1e-4, varianceAngleTo = 1e-4)
        addPmu!(system30, device, pf; correlated = true)
        testPmuEstimation(system30, device, pf)
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
    powerFlow!(system14, pf; power = true)

    device = measurement()

    @testset "IEEE 14: Bus Wattmeter Measurements" begin
        device = measurement()

        for (key, idx) in system14.bus.label
            addPmu!(system14, device; bus = key, magnitude = 1.0, angle = pf.voltage.angle[idx])
            addWattmeter!(system14, device; bus = key, active = pf.power.injection.active[idx])
        end
        testDCEstimation(system14, device, pf)
    end

    @testset "IEEE 14: Branch Wattmeter Measurements" begin
        device = measurement()

        for (key, idx) in system14.bus.label
            addPmu!(system14, device; bus = key, magnitude = 1.0, angle = pf.voltage.angle[idx])
        end
        for (key, idx) in system14.branch.label
            addWattmeter!(system14, device; from = key, active = pf.power.from.active[idx])
            addWattmeter!(system14, device; to = key, active = pf.power.to.active[idx])
        end
        testDCEstimation(system14, device, pf)
    end

    device = measurement()

    @testset "IEEE 14: Wattmeter Measurements" begin
        for (key, idx) in system14.bus.label
            addWattmeter!(system14, device; bus = key, active = pf.power.injection.active[idx])
        end
        for (key, idx) in system14.branch.label
            addWattmeter!(system14, device; from = key, active = pf.power.from.active[idx])
            addWattmeter!(system14, device; to = key, active = pf.power.to.active[idx])
        end
        testDCEstimation(system14, device, pf)
    end

    @testset "IEEE 14: QR Factorization" begin
        analysisQR = dcStateEstimation(system14, device, QR)
        solve!(system14, analysisQR)
        @test analysisQR.voltage.angle ≈ pf.voltage.angle
    end

    @testset "IEEE 14: Orthogonal Method" begin
        orthogonal = dcStateEstimation(system14, device, Orthogonal)
        stateEstimation!(system14, orthogonal; power = true)

        @test orthogonal.voltage.angle ≈ pf.voltage.angle
        compstruct(orthogonal.power, pf.power; atol = 1e-10)
    end

    ########## IEEE 30-bus Test Case ##########
    dcModel!(system30)
    pf = dcPowerFlow(system30)
    powerFlow!(system30, pf; power = true)

    device = measurement()

    @testset "IEEE 30: Wattmeter Measurements" begin
        for (key, idx) in system30.bus.label
            addWattmeter!(system30, device; bus = key, active = pf.power.injection.active[idx])
        end
        for (key, idx) in system30.branch.label
            addWattmeter!(system30, device; from = key, active = pf.power.from.active[idx])
            addWattmeter!(system30, device; to = key, active = pf.power.to.active[idx])
        end
        testDCEstimation(system30, device, pf)
    end

    @testset "IEEE 30: Orthogonal Method" begin
        orthogonal = dcStateEstimation(system30, device, Orthogonal)
        stateEstimation!(system30, orthogonal; power = true)

        @test orthogonal.voltage.angle ≈ pf.voltage.angle
        compstruct(orthogonal.power, pf.power; atol = 1e-10)
    end
end

@testset "Print Data in Per-Units" begin
    system = powerSystem(path * "case14test.m")
    device = measurement("measurement14.h5")
    addPmu!(system, device; bus = 1, magnitude = 1.0, angle = 0.0)
    addPmu!(system, device; bus = 3, magnitude = 1.1, angle = -0.3)

    ########## Print AC Data ##########
    analysis = gaussNewton(system, device)
    stateEstimation!(system, analysis; power = true, current = true)

    @suppress @testset "Print Voltmeter AC Data" begin
        width = Dict("Voltage Magnitude Residual" => 10)
        show = Dict("Voltage Magnitude Estimate" => false)
        fmt = Dict("Voltage Magnitude" => "%.2f")

        printVoltmeterData(system, device, analysis; width, show, fmt, repeat = 10)
        printVoltmeterData(system, device, analysis; label = 1, header = true)
        printVoltmeterData(system, device, analysis; label = 2, footer = true)
        printVoltmeterData(system, device, analysis; style = false)
    end

    @suppress @testset "Print Ammeter AC Data" begin
        show = Dict("Current Magnitude Status" => false)

        printAmmeterData(system, device, analysis; show, repeat = 10)
        printAmmeterData(system, device, analysis; label = "From 1", header = true)
        printAmmeterData(system, device, analysis; label = "From 2", footer = true)
        printAmmeterData(system, device, analysis; style = false)
    end

    @suppress @testset "Print Wattmeter AC Data" begin
        printWattmeterData(system, device, analysis; repeat = 10)
        printWattmeterData(system, device, analysis; label = 1, header = true)
        printWattmeterData(system, device, analysis; label = 4, footer = true)
        printWattmeterData(system, device, analysis; style = false)
    end

    @suppress @testset "Print Varmeter AC Data" begin
        printVarmeterData(system, device, analysis; repeat = 10)
        printVarmeterData(system, device, analysis; label = 1, header = true)
        printVarmeterData(system, device, analysis; label = 4, footer = true)
        printVarmeterData(system, device, analysis; style = false)
    end

    @suppress @testset "Print PMU AC Data" begin
        printPmuData(system, device, analysis; repeat = 10)
        printPmuData(system, device, analysis; label = "From 1", header = true)
        printPmuData(system, device, analysis; label = "From 4", footer = true)
        printPmuData(system, device, analysis; style = false)
        printPmuData(system, device, analysis; label = "From 1", style = false)
        printPmuData(system, device, analysis; label = 41, style = false)
    end

    ########## Print DC Data ##########
    analysis = dcStateEstimation(system, device)
    stateEstimation!(system, analysis; power = true)

    @suppress @testset "Print Wattmeter DC Data" begin
        printWattmeterData(system, device, analysis; repeat = 10)
        printWattmeterData(system, device, analysis; label = 1, header = true)
        printWattmeterData(system, device, analysis; label = 4, footer = true)
        printWattmeterData(system, device, analysis; style = false)
    end

    @suppress @testset "Print PMU DC Data" begin
        printPmuData(system, device, analysis; repeat = 10)
        printPmuData(system, device, analysis; label = 41, header = true)
        printPmuData(system, device, analysis; label = 42, footer = true)
        printPmuData(system, device, analysis; style = false)
    end
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
    stateEstimation!(system, analysis; power = true, current = true)

    @suppress @testset "Print Voltmeter AC Data" begin
        printVoltmeterData(system, device, analysis)
        printVoltmeterData(system, device, analysis; label = 1)
    end

    @suppress @testset "Print Ammeter AC Data" begin
        printAmmeterData(system, device, analysis)
        printAmmeterData(system, device, analysis; label = "From 1")
    end

    @suppress @testset "Print Wattmeter AC Data" begin
        printWattmeterData(system, device, analysis)
        printWattmeterData(system, device, analysis; label = 1)
    end

    @suppress @testset "Print Varmeter AC Data" begin
        printVarmeterData(system, device, analysis)
        printVarmeterData(system, device, analysis; label = 1)
    end

    @suppress @testset "Print PMU AC Data" begin
        printPmuData(system, device, analysis)
        printPmuData(system, device, analysis; label = "From 1")
        printPmuData(system, device, analysis; label = 41)
    end

    ########## Print DC Data ##########
    analysis = dcStateEstimation(system, device)
    stateEstimation!(system, analysis; power = true)

    @suppress @testset "Print Wattmeter DC Data" begin
        printWattmeterData(system, device, analysis)
        printWattmeterData(system, device, analysis; label = 1)
    end

    @suppress @testset "Print PMU DC Data" begin
        printPmuData(system, device, analysis)
        printPmuData(system, device, analysis; label = 41)
    end
end