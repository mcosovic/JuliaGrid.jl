system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "DC State Estimation" begin
    ############### Modified IEEE 14-bus Test Case ################
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)

    dcModel!(system14)
    analysis = dcPowerFlow(system14)
    solve!(system14, analysis)
    power!(system14, analysis)
    device = measurement()

    ################ Wattmeters ################
    for (key, value) in system14.bus.label
        addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[value], noise = false)
    end
    for (key, value) in system14.branch.label
        addWattmeter!(system14, device; from = key, active = analysis.power.from.active[value], noise = false)
        addWattmeter!(system14, device; to = key, active = analysis.power.to.active[value], noise = false) 
    end

    ####### LU Factorization #######
    analysisLU = dcStateEstimation(system14, device, LU)
    solve!(system14, analysisLU)
    @test analysisLU.voltage.angle ≈ analysis.voltage.angle

    ####### QR Factorization #######
    analysisQR = dcStateEstimation(system14, device, QR)
    solve!(system14, analysisQR)
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle

    ####### LAV #######
    analysisLAV = dcStateEstimation(system14, device, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system14, analysisLAV)
    @test analysisLAV.voltage.angle ≈ analysis.voltage.angle

    ################ PMUs ################
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = 1.0, angle = analysis.voltage.angle[value], noise = false)
    end

    ####### LU Factorization #######
    analysisLU = dcStateEstimation(system14, device, LU)
    solve!(system14, analysisLU)
    @test analysisLU.voltage.angle ≈ analysis.voltage.angle

    ####### QR Factorization #######
    analysisQR = dcStateEstimation(system14, device, QR)
    solve!(system14, analysisQR)
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle

    ####### LAV #######
    analysisLAV = dcStateEstimation(system14, device, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system14, analysisLAV)
    @test analysisLAV.voltage.angle ≈ analysis.voltage.angle

    ################ Modified IEEE 30-bus Test Case ################
    dcModel!(system30)
    analysis = dcPowerFlow(system30)
    solve!(system30, analysis)
    power!(system30, analysis)
    device = measurement()

    ################ Wattmeters ################
    for (key, value) in system30.bus.label
        addWattmeter!(system30, device; bus = key, active = analysis.power.injection.active[value], variance = 1e-6)
    end
    for (key, value) in system30.branch.label
        addWattmeter!(system30, device; from = key, active = analysis.power.from.active[value], variance = 1e-7)
        addWattmeter!(system30, device; to = key, active = analysis.power.to.active[value], variance = 1e-8) 
    end

    ####### LU Factorization #######
    analysisLU = dcStateEstimation(system30, device, LU)
    solve!(system30, analysisLU)
    @test analysisLU.voltage.angle ≈ analysis.voltage.angle atol = 1e-2

    ####### QR Factorization #######
    analysisQR = dcStateEstimation(system30, device, QR)
    solve!(system30, analysisQR)
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle atol = 1e-2

    ####### LAV #######
    analysisLAV = dcStateEstimation(system30, device, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system30, analysisLAV)
    @test analysisLAV.voltage.angle ≈ analysis.voltage.angle atol = 1e-2

    ################ PMUs ################
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = 1.0, angle = analysis.voltage.angle[value], varianceAngle = 1e-9)
    end

    ####### LU Factorization #######
    analysisLU = dcStateEstimation(system30, device, LU)
    solve!(system30, analysisLU)
    @test analysisLU.voltage.angle ≈ analysis.voltage.angle atol = 1e-2

    ####### QR Factorization #######
    analysisQR = dcStateEstimation(system30, device, QR)
    solve!(system30, analysisQR)
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle atol = 1e-2

    ####### LAV #######
    analysisLAV = dcStateEstimation(system30, device, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system30, analysisLAV)
    @test analysisLAV.voltage.angle ≈ analysis.voltage.angle atol = 1e-2

    ############### Modified IEEE 30-bus Test Case ################
    acModel!(system30)
    analysis = newtonRaphson(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
    end
    power!(system30, analysis)
    current!(system30, analysis)

    device = measurement()

    ################ Wattmeters ################
    addWattmeter!(system30, device, analysis; varianceBus = 1e-2, varianceFrom = 1e-3, varianceTo = 1e-4)

    analysisLU = dcStateEstimation(system30, device, LU)
    solve!(system30, analysisLU)
    analysisQR = dcStateEstimation(system30, device, QR)
    solve!(system30, analysisQR)
    @test analysisLU.voltage.angle ≈ analysisQR.voltage.angle

    ################ PMUs ################
    addPmu!(system30, device, analysis; varianceAngleBus = 1e-5)

    analysisLU = dcStateEstimation(system30, device, LU)
    solve!(system30, analysisLU)
    analysisQR = dcStateEstimation(system30, device, QR)
    solve!(system30, analysisQR)
    @test analysisLU.voltage.angle ≈ analysisQR.voltage.angle
end
