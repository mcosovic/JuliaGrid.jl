system14 = powerSystem(path * "case14test.m")
@testset "Reusing Meters AC State Estimation" begin
    @default(template)
    @default(unit)

    ############ IEEE 14-bus Test Case ############
    acModel!(system14)
    pf = newtonRaphson(system14)
    powerFlow!(system14, pf; power = true, current = true)

    V = pf.voltage
    P = pf.power
    I = pf.current

    device = measurement()

    @wattmeter(label = "!")
    @varmeter(label = "!")
    @ammeter(label = "!")
    @pmu(label = "!")

    addVoltmeter!(system14, device, pf)
    updateVoltmeter!(system14, device; label = 1, magnitude = rand())
    updateVoltmeter!(system14, device; label = 3, status = 0)
    updateVoltmeter!(system14, device; label = 5, magnitude = rand(), variance = 1e-5, noise = true)

    addAmmeter!(system14, device, pf)
    updateAmmeter!(system14, device; label = "From 4", magnitude = rand())
    updateAmmeter!(system14, device; label = "From 15", status = 0)
    updateAmmeter!(system14, device; label = "From 17", status = 0)
    updateAmmeter!(system14, device; label = "To 4", magnitude = rand())
    updateAmmeter!(system14, device; label = "To 15", status = 0)
    updateAmmeter!(system14, device; label = "To 17", status = 0)

    addWattmeter!(system14, device, pf)
    updateWattmeter!(system14, device; label = 1, active = rand())
    updateWattmeter!(system14, device; label = 3, status = 0)
    updateWattmeter!(system14, device; label = 5, active = rand(), variance = 1e-5, noise = true)
    updateWattmeter!(system14, device; label = "From 4", active = rand())
    updateWattmeter!(system14, device; label = "From 15", status = 0)
    updateWattmeter!(system14, device; label = "From 17", active = rand(), variance = 1e-5, noise = true)
    updateWattmeter!(system14, device; label = "To 4", active = rand())
    updateWattmeter!(system14, device; label = "To 15", status = 0)
    updateWattmeter!(system14, device; label = "To 17", active = rand(), variance = 1e-5, noise = true)

    addVarmeter!(system14, device, pf)
    updateVarmeter!(system14, device; label = 1, reactive = rand())
    updateVarmeter!(system14, device; label = 3, status = 0)
    updateVarmeter!(system14, device; label = 5, reactive = rand(), variance = 1e-5, noise = true)
    updateVarmeter!(system14, device; label = "From 4", reactive = rand())
    updateVarmeter!(system14, device; label = "From 15", status = 0)
    updateVarmeter!(system14, device; label = "From 17", reactive = rand(), variance = 1e-5, noise = true)
    updateVarmeter!(system14, device; label = "To 4", reactive = rand())
    updateVarmeter!(system14, device; label = "To 15", status = 0)
    updateVarmeter!(system14, device; label = "To 17", reactive = rand(), variance = 1e-5, noise = true)

    addPmu!(system14, device, pf)
    updatePmu!(system14, device; label = 1, angle = rand(), correlated = true)
    updatePmu!(system14, device; label = 3, status = 0)
    updatePmu!(system14, device; label = 5, magnitude = 1, angle = rand(), varianceAngle = 1e-5, noise = true)
    updatePmu!(system14, device; label = 5, correlated = true)
    updatePmu!(system14, device; label = "From 4", angle = 999, polar = true)
    updatePmu!(system14, device; label = "From 17", magnitude = 999)
    updatePmu!(system14, device; label = "To 4", angle = 999, status = 0, polar = true)
    updatePmu!(system14, device; label = "To 17", magnitude = 999, status = 0)

    # Original WLS and LAV Models
    wls = gaussNewton(system14, device)
    lav = acLavStateEstimation(system14, device, Ipopt.Optimizer)

    # Update Devices
    updateVoltmeter!(system14, device; label = 1, status = 0)
    updateVoltmeter!(system14, device; label = 3, status = 1)
    updateVoltmeter!(system14, device; label = 5, magnitude = V.magnitude[5], variance = 1e-2)

    updateAmmeter!(system14, device; label = "From 4", status = 0)
    updateAmmeter!(system14, device; label = "From 15", status = 1)
    updateAmmeter!(system14, device; label = "From 17", variance = 1e-2)
    updateAmmeter!(system14, device; label = "To 4", status = 0)
    updateAmmeter!(system14, device; label = "To 15", status = 1)
    updateAmmeter!(system14, device; label = "To 17", magnitude = I.to.magnitude[17], variance = 1e-2)

    updateWattmeter!(system14, device; label = 1, status = 0)
    updateWattmeter!(system14, device; label = 3, status = 1)
    updateWattmeter!(system14, device; label = 5, active = P.injection.active[5], variance = 1e-2)
    updateWattmeter!(system14, device; label = "From 4", status = 0)
    updateWattmeter!(system14, device; label = "From 15", status = 1)
    updateWattmeter!(system14, device; label = "From 17", active = P.from.active[17], variance = 1e-2)
    updateWattmeter!(system14, device; label = "To 4", status = 0)
    updateWattmeter!(system14, device; label = "To 15", status = 1)
    updateWattmeter!(system14, device; label = "To 17", active = P.to.active[17], variance = 1e-2)

    updateVarmeter!(system14, device; label = 1, status = 0)
    updateVarmeter!(system14, device; label = 3, status = 1)
    updateVarmeter!(system14, device; label = 5, reactive = P.injection.reactive[5], variance = 1e-2)
    updateVarmeter!(system14, device; label = "From 4", status = 0)
    updateVarmeter!(system14, device; label = "From 15", status = 1)
    updateVarmeter!(system14, device; label = "From 17", reactive = P.from.reactive[17], variance = 1e-2)
    updateVarmeter!(system14, device; label = "To 4", status = 0)
    updateVarmeter!(system14, device; label = "To 15", status = 1)
    updateVarmeter!(system14, device; label = "To 17", reactive = P.to.reactive[17], variance = 1e-2)

    updatePmu!(system14, device; label = 1, status = 0, polar = true)
    updatePmu!(system14, device; label = 3, status = 1)
    updatePmu!(system14, device; label = 5, magnitude = V.magnitude[5], angle = V.angle[5], varianceAngle = 1e-5)
    updatePmu!(system14, device; label = 5, polar = true)
    updatePmu!(system14, device; label = "From 4", status = 0, polar = true)
    updatePmu!(system14, device; label = "From 17", magnitude = I.from.magnitude[17])
    updatePmu!(system14, device; label = "To 4", angle = I.to.angle[4], status = 1, polar = false)
    updatePmu!(system14, device; label = "To 17", magnitude = I.to.magnitude[17], status = 1)

    @testset "WLS: Updated only Measurement Model" begin
        analysisWLSUpdate = gaussNewton(system14, device)
        stateEstimation!(system14, analysisWLSUpdate; tolerance = 1e-12)

        compstruct(analysisWLSUpdate.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "LAV: Updated only Measurement Model" begin
        analysisLAVUpdate = acLavStateEstimation(system14, device, Ipopt.Optimizer)
        stateEstimation!(system14, analysisLAVUpdate)

        compstruct(analysisLAVUpdate.voltage, pf.voltage; atol = 1e-10)
    end

    # Update Devices and Original WLS Model
    updateVoltmeter!(system14, device, wls; label = 1, status = 0)
    updateVoltmeter!(system14, device, wls; label = 3, status = 1)
    updateVoltmeter!(system14, device, wls; label = 5, magnitude = V.magnitude[5], variance = 1e-2)

    updateAmmeter!(system14, device, wls; label = "From 4", status = 0)
    updateAmmeter!(system14, device, wls; label = "From 15", status = 1)
    updateAmmeter!(system14, device, wls; label = "From 17", magnitude = I.from.magnitude[17], variance = 1e-2)
    updateAmmeter!(system14, device, wls; label = "To 4", status = 0)
    updateAmmeter!(system14, device, wls; label = "To 15", status = 1)
    updateAmmeter!(system14, device, wls; label = "To 17", magnitude = I.to.magnitude[17], variance = 1e-2)

    updateWattmeter!(system14, device, wls; label = 1, status = 0)
    updateWattmeter!(system14, device, wls; label = 3, status = 1)
    updateWattmeter!(system14, device, wls; label = 5, active = P.injection.active[5], variance = 1e-2)
    updateWattmeter!(system14, device, wls; label = "From 4", status = 0)
    updateWattmeter!(system14, device, wls; label = "From 15", status = 1)
    updateWattmeter!(system14, device, wls; label = "From 17", active = P.from.active[17], variance = 1e-2)
    updateWattmeter!(system14, device, wls; label = "To 4", status = 0)
    updateWattmeter!(system14, device, wls; label = "To 15", status = 1)
    updateWattmeter!(system14, device, wls; label = "To 17", active = P.to.active[17], variance = 1e-2)

    updateVarmeter!(system14, device, wls; label = 1, status = 0)
    updateVarmeter!(system14, device, wls; label = 3, status = 1)
    updateVarmeter!(system14, device, wls; label = 5, reactive = P.injection.reactive[5], variance = 1e-2)
    updateVarmeter!(system14, device, wls; label = "From 4", status = 0)
    updateVarmeter!(system14, device, wls; label = "From 15", status = 1)
    updateVarmeter!(system14, device, wls; label = "From 17", reactive = P.from.reactive[17], variance = 1e-2)
    updateVarmeter!(system14, device, wls; label = "To 4", status = 0)
    updateVarmeter!(system14, device, wls; label = "To 15", status = 1)
    updateVarmeter!(system14, device, wls; label = "To 17", reactive = P.to.reactive[17], variance = 1e-2)

    updatePmu!(system14, device, wls; label = 1, status = 0, polar = true)
    updatePmu!(system14, device, wls; label = 1, status = 1)
    updatePmu!(system14, device, wls; label = 3, status = 1, polar = true)
    updatePmu!(system14, device, wls; label = 5, magnitude = V.magnitude[5], angle = V.angle[5], varianceAngle = 1e-5)
    updatePmu!(system14, device, wls; label = 5, status = 0, polar = true)
    updatePmu!(system14, device, wls; label = 5, status = 1, polar = false)
    updatePmu!(system14, device, wls; label = 5, correlated = true)
    updatePmu!(system14, device, wls; label = "From 4", status = 0, polar = true)
    updatePmu!(system14, device, wls; label = "From 17", magnitude = I.from.magnitude[17])
    updatePmu!(system14, device, wls; label = "To 4", angle = I.to.angle[4], status = 1, polar = false)
    updatePmu!(system14, device, wls; label = "To 17", magnitude = I.to.magnitude[17], status = 1)

    @testset "WLS: Updated Measurement and WLS Model" begin
        stateEstimation!(system14, wls; tolerance = 1e-12)
        compstruct(wls.voltage, pf.voltage; atol = 1e-10)
    end

    # Update Devices and Original LAV Model
    updateVoltmeter!(system14, device, lav; label = 1, status = 0)
    updateVoltmeter!(system14, device, lav; label = 3, status = 1)
    updateVoltmeter!(system14, device, lav; label = 5, magnitude = V.magnitude[5], variance = 1e-2)

    updateAmmeter!(system14, device, lav; label = "From 4", status = 0)
    updateAmmeter!(system14, device, lav; label = "From 15", status = 1)
    updateAmmeter!(system14, device, lav; label = "From 17", magnitude = I.from.magnitude[17], variance = 1e-2)
    updateAmmeter!(system14, device, lav; label = "To 4", status = 0)
    updateAmmeter!(system14, device, lav; label = "To 15", status = 1)
    updateAmmeter!(system14, device, lav; label = "To 17", magnitude = I.to.magnitude[17], variance = 1e-2)

    updateWattmeter!(system14, device, lav; label = 1, status = 0)
    updateWattmeter!(system14, device, lav; label = 3, status = 1)
    updateWattmeter!(system14, device, lav; label = 5, active = P.injection.active[5], variance = 1e-2)
    updateWattmeter!(system14, device, lav; label = "From 4", status = 0)
    updateWattmeter!(system14, device, lav; label = "From 15", status = 1)
    updateWattmeter!(system14, device, lav;label = "From 17", active = P.from.active[17], variance = 1e-2)
    updateWattmeter!(system14, device, lav; label = "To 4", status = 0)
    updateWattmeter!(system14, device, lav; label = "To 15", status = 1)
    updateWattmeter!(system14, device, lav; label = "To 17", active = P.to.active[17], variance = 1e-2)

    updateVarmeter!(system14, device, lav; label = 1, status = 0)
    updateVarmeter!(system14, device, lav; label = 3, status = 1)
    updateVarmeter!(system14, device, lav; label = 5, reactive = P.injection.reactive[5], variance = 1e-2)
    updateVarmeter!(system14, device, lav; label = "From 4", status = 0)
    updateVarmeter!(system14, device, lav; label = "From 15", status = 1)
    updateVarmeter!(system14, device, lav; label = "From 17", reactive = P.from.reactive[17], variance = 1e-2)
    updateVarmeter!(system14, device, lav; label = "To 4", status = 0)
    updateVarmeter!(system14, device, lav; label = "To 15", status = 1)
    updateVarmeter!(system14, device, lav; label = "To 17", reactive = P.to.reactive[17], variance = 1e-2)

    updatePmu!(system14, device, lav; label = 1, status = 0, polar = true)
    updatePmu!(system14, device, lav; label = 3, status = 1, polar = true)
    updatePmu!(system14, device, lav; label = 5, magnitude = V.magnitude[5], angle = V.angle[5], varianceAngle = 1e-5)
    updatePmu!(system14, device, lav; label = 5, polar = true)
    updatePmu!(system14, device, lav; label = 5, status = 0, polar = false)
    updatePmu!(system14, device, lav; label = 5, status = 1)
    updatePmu!(system14, device, lav; label = 5, correlated = true)
    updatePmu!(system14, device, lav; label = "From 4", status = 0, polar = true)
    updatePmu!(system14, device, lav; label = "From 17", magnitude = I.from.magnitude[17])
    updatePmu!(system14, device, lav; label = "To 4", angle = I.to.angle[4], status = 1, polar = false)
    updatePmu!(system14, device, lav; label = "To 17", magnitude = I.to.magnitude[17], status = 1)

    @testset "LAV: Updated Measurement and LAV Model" begin
        stateEstimation!(system14, lav)
        compstruct(lav.voltage, pf.voltage; atol = 1e-8)
    end
end

system14 = powerSystem(path * "case14test.m")
@testset "Reusing Meters PMU State Estimation" begin
    @default(template)
    @default(unit)

    ############ IEEE 14-bus Test Case ############
    acModel!(system14)
    pf = newtonRaphson(system14)
    powerFlow!(system14, pf; current = true)

    V = pf.voltage
    I = pf.current

    device = measurement()

    @pmu(label = "!")
    placement = pmuPlacement!(system14, device, pf, HiGHS.Optimizer)

    updatePmu!(system14, device; label = 4, magnitude = rand(), correlated = true)
    updatePmu!(system14, device; label = 5, angle = rand(), status = 0, correlated = true)
    updatePmu!(system14, device; label = 7, magnitude = rand(), angle = rand(), status = 0)

    updatePmu!(system14, device; label = "From 7", magnitude = rand(), angle = rand())
    updatePmu!(system14, device; label = "From 10", status = 0, correlated = true)
    updatePmu!(system14, device; label = "From 16", angle = rand(), correlated = true)

    updatePmu!(system14, device; label = "To 2", magnitude = rand())
    updatePmu!(system14, device; label = "To 7", angle = rand())
    updatePmu!(system14, device; label = "To 9", status = 0)

    # Original Device, WLS and LAV Models
    deviceWLS = deepcopy(device)
    deviceLAV = deepcopy(device)
    wls = pmuStateEstimation(system14, device)
    lav = pmuLavStateEstimation(system14, device, Ipopt.Optimizer)

    # Update Just PMUs
    updatePmu!(system14, device; label = 4, magnitude = V.magnitude[4])
    updatePmu!(system14, device; label = 5, angle = V.angle[5], status = 1)
    updatePmu!(system14, device; label = 7, magnitude = V.magnitude[7], angle = V.angle[7], status = 1)

    updatePmu!(system14, device; label = "From 7", magnitude = I.from.magnitude[7], angle = I.from.angle[7])
    updatePmu!(system14, device; label = "From 10", status = 1)
    updatePmu!(system14, device; label = "From 16", angle = I.from.angle[16])

    updatePmu!(system14, device; label = "To 2", magnitude = I.to.magnitude[2])
    updatePmu!(system14, device; label = "To 7", angle = I.to.angle[7])
    updatePmu!(system14, device; label = "To 9", status = 1)

    @testset "WLS: Updated Only Measurement Model" begin
        analysisWLSUpdate = pmuStateEstimation(system14, device)
        stateEstimation!(system14, analysisWLSUpdate)

        compstruct(analysisWLSUpdate.voltage, pf.voltage; atol = 1e-10)
    end

    @testset "LAV: Updated Only Measurement Model" begin
        analysisLAVUpdate = pmuLavStateEstimation(system14, device, Ipopt.Optimizer)
        stateEstimation!(system14, analysisLAVUpdate)

        compstruct(analysisLAVUpdate.voltage, pf.voltage; atol = 1e-8)
    end

    # Update Devices and Original WLS Model
    updatePmu!(system14, deviceWLS, wls; label = 4, magnitude = V.magnitude[4])
    updatePmu!(system14, deviceWLS, wls; label = 5, angle = V.angle[5], status = 1)
    updatePmu!(system14, deviceWLS, wls; label = 7, magnitude = V.magnitude[7], angle = V.angle[7], status = 1)
    updatePmu!(system14, deviceWLS, wls; label = 4, status = 0)
    updatePmu!(system14, deviceWLS, wls; label = 4, status = 1)

    updatePmu!(system14, deviceWLS, wls; label = "From 7", magnitude = I.from.magnitude[7], angle = I.from.angle[7])
    updatePmu!(system14, deviceWLS, wls; label = "From 10", status = 1)
    updatePmu!(system14, deviceWLS, wls; label = "From 16", angle = I.from.angle[16])

    updatePmu!(system14, deviceWLS, wls; label = "To 2", magnitude = I.to.magnitude[2])
    updatePmu!(system14, deviceWLS, wls; label = "To 7", angle = I.to.angle[7])
    updatePmu!(system14, deviceWLS, wls; label = "To 9", status = 1)

    @testset "WLS: Updated Measurement and WLS Model" begin
        stateEstimation!(system14, wls)
        compstruct(wls.voltage, pf.voltage; atol = 1e-10)
    end

    # Update Devices and Original LAV Model
    updatePmu!(system14, deviceLAV, lav; label = 4, magnitude = V.magnitude[4])
    updatePmu!(system14, deviceLAV, lav; label = 5, angle = V.angle[5], status = 1)
    updatePmu!(system14, deviceLAV, lav; label = 7, magnitude = V.magnitude[7], angle = V.angle[7], status = 1)
    updatePmu!(system14, deviceLAV, lav; label = 4, status = 0)
    updatePmu!(system14, deviceLAV, lav; label = 4, status = 1)

    updatePmu!(system14, deviceLAV, lav; label = "From 7", magnitude = I.from.magnitude[7], angle = I.from.angle[7])
    updatePmu!(system14, deviceLAV, lav; label = "From 10", status = 1)
    updatePmu!(system14, deviceLAV, lav; label = "From 16", angle = I.from.angle[16])

    updatePmu!(system14, deviceLAV, lav; label = "To 2", magnitude = I.to.magnitude[2])
    updatePmu!(system14, deviceLAV, lav; label = "To 7", angle = I.to.angle[7])
    updatePmu!(system14, deviceLAV, lav; label = "To 9", status = 1)

    @testset "LAV: Updated Measurement and LAV Model" begin
        stateEstimation!(system14, lav)
        compstruct(lav.voltage, pf.voltage; atol = 1e-8)
    end

    @testset "Precision Matrix" begin
        precision = copy(wls.method.precision)

        updatePmu!(system14, deviceWLS, wls; label = 4, correlated = false)
        @test wls.method.precision[1, 2] == 0.0
        @test wls.method.precision[2, 1] == 0.0

        updatePmu!(system14, deviceWLS, wls; label = 4, correlated = true)
        @test (wls.method.precision[1, 1] ≈ precision[1, 1]) != 0.0
        @test (wls.method.precision[1, 2] ≈ precision[1, 2]) != 0.0
        @test (wls.method.precision[2, 2] ≈ precision[2, 2]) != 0.0
        @test (wls.method.precision[2, 1] ≈ precision[2, 1]) != 0.0

        updatePmu!(system14, deviceWLS, wls; label = "From 10", angle = -5.5, correlated = false)
        @test wls.method.precision[17, 18] == 0.0
        @test wls.method.precision[18, 17] == 0.0

        updatePmu!(system14, deviceWLS, wls; label = "From 10", angle = I.from.angle[10], correlated = true)
        @test (wls.method.precision[17, 17] ≈ precision[17, 17]) != 0.0
        @test (wls.method.precision[17, 18] ≈ precision[17, 18]) != 0.0
        @test (wls.method.precision[18, 18] ≈ precision[18, 18]) != 0.0
        @test (wls.method.precision[18, 17] ≈ precision[18, 17]) != 0.0

        updatePmu!(system14, deviceWLS, wls; label = "From 12", correlated = true)
        updatePmu!(system14, deviceWLS, wls; label = "From 12", correlated = false)
        @test wls.method.precision[21, 21] ≈ precision[21, 21]
        @test wls.method.precision[22, 22] ≈ precision[22, 22]
        @test wls.method.precision[21, 22] == 0.0
        @test wls.method.precision[22, 21] == 0.0
    end
end

system14 = powerSystem(path * "case14test.m")
@testset "Reusing Meters DC State Estimation" begin
    @default(template)
    @default(unit)

    ############ IEEE 14-bus Test Case ############
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)
    updateBranch!(system14; label = 7, status = 0)
    updateBranch!(system14; label = 12, status = 0)

    dcModel!(system14)
    pf = dcPowerFlow(system14)
    powerFlow!(system14, pf; power = true)

    V = pf.voltage
    P = pf.power

    device = measurement()
    @wattmeter(label = "!")

    for (key, idx) in system14.bus.label
        if idx == 1
            addWattmeter!(system14, device; bus = key, active = rand())
        elseif idx == 3
            addWattmeter!(system14, device; bus = key, active = P.injection.active[idx], status = 0)
        elseif idx == 5
            addWattmeter!(system14, device; bus = key, active = rand(), variance = 1e-5, noise = true)
        elseif idx == 9
            addWattmeter!(system14, device; bus = key, active = rand(1)[])
        else
            addWattmeter!(system14, device;bus = key, active = P.injection.active[idx])
        end
    end

    for (key, idx) in system14.branch.label
        if idx == 4
            addWattmeter!(system14, device; from = key, active = rand())
        elseif idx == 15
            addWattmeter!(system14, device; from = key, active = P.from.active[idx], status = 0)
        elseif idx == 17
            addWattmeter!(system14, device; from = key, active = rand(), variance = 1e-5, noise = true)
        elseif idx == 20
            addWattmeter!(system14, device; from = key, active = rand(1)[], noise = true)
        else
            addWattmeter!(system14, device; from = key, active = P.from.active[idx])
        end

        if idx == 5
            addWattmeter!(system14, device; to = key, active = rand())
        elseif idx == 8
            addWattmeter!(system14, device; to = key, active = P.to.active[idx], status = 0)
        elseif idx == 11
            addWattmeter!(system14, device; to = key, active = rand(), variance = 1e-5, noise = true)
        elseif idx == 19
            addWattmeter!(system14, device; to = key, active = rand(), noise = true)
        else
            addWattmeter!(system14, device; to = key, active = P.to.active[idx])
        end
    end

    for (key, idx) in system14.bus.label
        if idx == 2
            addPmu!(system14, device; bus = key, magnitude = 1, angle = rand())
        elseif idx == 6
            addPmu!(system14, device; bus = key, magnitude = 1, angle = V.angle[idx], status = 0
                )
        elseif idx == 9
            addPmu!(system14, device; bus = key, magnitude = 1, angle = rand(), noise = true)
        elseif idx == 13
            addPmu!(system14, device; bus = key, magnitude = 1, angle = rand())
        else
            addPmu!(system14, device; bus = key, magnitude = 1, angle = V.angle[idx])
        end
    end

    # Original WLS and LAV Models
    wls = dcStateEstimation(system14, device)
    lav = dcLavStateEstimation(system14, device, Ipopt.Optimizer)

    # Update Devices
    updateWattmeter!(system14, device; label = 1, status = 0)
    updateWattmeter!(system14, device; label = 3, status = 1)
    updateWattmeter!(system14, device; label = 5, active = P.injection.active[5], variance = 1e-2)
    updateWattmeter!(system14, device; label = 9, active = P.injection.active[9])

    updateWattmeter!(system14, device; label = "From 4", status = 0)
    updateWattmeter!(system14, device; label = "From 15", status = 1)
    updateWattmeter!(system14, device; label = "From 17", active = P.from.active[17], variance = 1e-2)
    updateWattmeter!(system14, device; label = "From 20", active = P.from.active[20])

    updateWattmeter!(system14, device; label = "To 5", status = 0)
    updateWattmeter!(system14, device; label = "To 8", status = 1)
    updateWattmeter!(system14, device; label = "To 11", active = P.to.active[11], variance = 1e-2)
    updateWattmeter!(system14, device; label = "To 19", active = P.to.active[19])

    updatePmu!(system14, device; label = 2, status = 0)
    updatePmu!(system14, device; label = 6, status = 1)
    updatePmu!(system14, device; label = 9, angle = V.angle[9], varianceAngle = 1e-5)
    updatePmu!(system14, device; label = 13, angle = V.angle[13])

    @testset "WLS: Updated Only Measurement Model" begin
        analysisWLSUpdate = dcStateEstimation(system14, device)
        stateEstimation!(system14, analysisWLSUpdate)

        @test analysisWLSUpdate.voltage.angle ≈ pf.voltage.angle
    end

    @testset "LAV: Updated Only Measurement Model" begin
        analysisLAVUpdate = dcLavStateEstimation(system14, device, Ipopt.Optimizer)
        stateEstimation!(system14, analysisLAVUpdate)

        @test analysisLAVUpdate.voltage.angle ≈ pf.voltage.angle
    end

    # Update Devices and Original WLS Model
    updateWattmeter!(system14, device, wls; label = 1, status = 0)
    updateWattmeter!(system14, device, wls; label = 3, status = 1)
    updateWattmeter!(system14, device, wls; label = 5, active = P.injection.active[5], variance = 1e-2)
    updateWattmeter!(system14, device, wls; label = 9, active = P.injection.active[9])

    updateWattmeter!(system14, device, wls; label = "From 4", status = 0)
    updateWattmeter!(system14, device, wls; label = "From 15", status = 1)
    updateWattmeter!(system14, device, wls; label = "From 17", active = P.from.active[17], variance = 1e-2)
    updateWattmeter!(system14, device, wls; label = "From 20", active = P.from.active[20])

    updateWattmeter!(system14, device, wls; label = "To 5", status = 0)
    updateWattmeter!(system14, device, wls; label = "To 8", status = 1)
    updateWattmeter!(system14, device, wls; label = "To 11", active = P.to.active[11], variance = 1e-2)
    updateWattmeter!(system14, device, wls; label = "To 19", active = P.to.active[19])

    updatePmu!(system14, device, wls; label = 2, status = 0)
    updatePmu!(system14, device, wls; label = 6, status = 1)
    updatePmu!(system14, device, wls; label = 9, angle = V.angle[9], varianceAngle = 1e-5)
    updatePmu!(system14, device, wls; label = 13, angle = V.angle[13])

    updateWattmeter!(system14, device, wls; label = 4, status = 0)
    updateWattmeter!(system14, device, wls; label = 4, status = 1)
    updateWattmeter!(system14, device, wls; label = "From 2", status = 0)
    updateWattmeter!(system14, device, wls; label = "From 2", status = 1)
    updateWattmeter!(system14, device, wls; label = "To 13", status = 0)
    updateWattmeter!(system14, device, wls; label = "To 13", status = 1)
    updatePmu!(system14, device, wls; label = 10, status = 0)
    updatePmu!(system14, device, wls; label = 10, status = 1)

    @testset "WLS: Updated Measurement and WLS Model" begin
        stateEstimation!(system14, wls)
        @test wls.voltage.angle ≈ pf.voltage.angle
    end

    # Update Devices and Original LAV Model
    updateWattmeter!(system14, device, lav; label = 1, status = 0)
    updateWattmeter!(system14, device, lav; label = 3, status = 1)
    updateWattmeter!(system14, device, lav; label = 5, active = P.injection.active[5], variance = 1e-2)
    updateWattmeter!(system14, device, lav; label = 9, active = P.injection.active[9])

    updateWattmeter!(system14, device, lav; label = "From 4", status = 0)
    updateWattmeter!(system14, device, lav; label = "From 15", status = 1)
    updateWattmeter!(system14, device, lav; label = "From 17", active = P.from.active[17], variance = 1e-2)
    updateWattmeter!(system14, device, lav; label = "From 20", active = P.from.active[20])

    updateWattmeter!(system14, device, lav; label = "To 5", status = 0)
    updateWattmeter!(system14, device, lav; label = "To 8", status = 1)
    updateWattmeter!(system14, device, lav; label = "To 11", active = P.to.active[11], variance = 1e-2)
    updateWattmeter!(system14, device, lav; label = "To 19", active = P.to.active[19])

    updatePmu!(system14, device, lav; label = 2, status = 0)
    updatePmu!(system14, device, lav; label = 6, status = 1)
    updatePmu!(system14, device, lav; label = 9, angle = V.angle[9], varianceAngle = 1e-5)
    updatePmu!(system14, device, lav; label = 13, angle = V.angle[13], noise = false)

    updateWattmeter!(system14, device, lav; label = 4, status = 0)
    updateWattmeter!(system14, device, lav; label = 4, status = 1)
    updateWattmeter!(system14, device, lav; label = "From 2", status = 0)
    updateWattmeter!(system14, device, lav; label = "From 2", status = 1)
    updateWattmeter!(system14, device, lav; label = "To 13", status = 0)
    updateWattmeter!(system14, device, lav; label = "To 13", status = 1)
    updatePmu!(system14, device, lav; label = 10, status = 0)
    updatePmu!(system14, device, lav; label = 10, status = 1)

    @testset "LAV: Updated Measurement and LAV Model" begin
        stateEstimation!(system14, lav)
        @test lav.voltage.angle ≈ pf.voltage.angle
    end
end