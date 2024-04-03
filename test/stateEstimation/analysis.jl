system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "AC State Estimation" begin
    @default(template)
    @default(unit)

    ############### Modified IEEE 14-bus Test Case ################
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.25)
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

    device = measurement()
    for (key, value) in system14.bus.label
        addVoltmeter!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], noise = false)
        addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[value], noise = false)
        addVarmeter!(system14, device; bus = key, reactive = analysis.power.injection.reactive[value], noise = false)
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], noise = false)
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], noise = false, polar = false)
    end

    for (key, value) in system14.branch.label
        addWattmeter!(system14, device; from = key, active = analysis.power.from.active[value], noise = false)
        addWattmeter!(system14, device; to = key, active = analysis.power.to.active[value], noise = false)
        addVarmeter!(system14, device; from = key, reactive = analysis.power.from.reactive[value], noise = false)
        addVarmeter!(system14, device; to = key, reactive = analysis.power.to.reactive[value], noise = false)
        addAmmeter!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], noise = false)
        addAmmeter!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], noise = false)
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], noise = false, statusAngle = 0)
        addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], noise = false, statusAngle = 0)
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], noise = false, polar = false)
        addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], noise = false, polar = false)
    end

    ####### LU Factorization #######
    analysisLU = gaussNewton(system14, device, LU)
    for iteration = 1:20
        stopping = solve!(system14, analysisLU)
        if stopping < 1e-8
            break
        end
    end
    @test analysisLU.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisLU.voltage.angle ≈ analysis.voltage.angle

    ###### QR Factorization #######
    analysisQR = gaussNewton(system14, device, QR)
    for iteration = 1:100
        stopping = solve!(system14, analysisQR)
        if stopping < 1e-8
            break
        end
    end
    solve!(system14, analysisQR)
    @test analysisQR.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle

    ####### Orthogonal Method #######
    analysisOrt = gaussNewton(system14, device, Orthogonal)
    for iteration = 1:100
        stopping = solve!(system14, analysisOrt)
        if stopping < 1e-8
            break
        end
    end
    solve!(system14, analysisOrt)
    @test analysisOrt.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisOrt.voltage.angle ≈ analysis.voltage.angle

    ####### LAV #######
    analysisLAV = acLavStateEstimation(system14, device, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system14, analysisLAV)
    @test analysisLAV.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisLAV.voltage.angle ≈ analysis.voltage.angle

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

    device = measurement()
    for (key, value) in system30.bus.label
        addVoltmeter!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], noise = false)
        addWattmeter!(system30, device; bus = key, active = analysis.power.injection.active[value], noise = false)
        addVarmeter!(system30, device; bus = key, reactive = analysis.power.injection.reactive[value], noise = false)
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], noise = false)
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], noise = false, polar = false)
    end

    for (key, value) in system30.branch.label
        addWattmeter!(system30, device; from = key, active = analysis.power.from.active[value], noise = false)
        addWattmeter!(system30, device; to = key, active = analysis.power.to.active[value], noise = false)
        addVarmeter!(system30, device; from = key, reactive = analysis.power.from.reactive[value], noise = false)
        addVarmeter!(system30, device; to = key, reactive = analysis.power.to.reactive[value], noise = false)
        addAmmeter!(system30, device; from = key, magnitude = analysis.current.from.magnitude[value], noise = false)
        addAmmeter!(system30, device; to = key, magnitude = analysis.current.to.magnitude[value], noise = false)
        addPmu!(system30, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], noise = false)
        addPmu!(system30, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], noise = false)
        addPmu!(system30, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], noise = false, polar = false)
        addPmu!(system30, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], noise = false, polar = false)
    end

    ####### LU Factorization #######
    analysisLU = gaussNewton(system30, device, LU)
    for iteration = 1:200
        stopping = solve!(system30, analysisLU)
        if stopping < 1e-12
            break
        end
    end
    @test analysisLU.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisLU.voltage.angle ≈ analysis.voltage.angle

    ###### QR Factorization #######
    analysisQR = gaussNewton(system30, device, QR)
    for iteration = 1:200
        stopping = solve!(system30, analysisQR)
        if stopping < 1e-12
            break
        end
    end
    solve!(system30, analysisQR)
    @test analysisQR.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle

    ####### Orthogonal Method #######
    device = measurement()
    for (key, value) in system30.bus.label
        addVoltmeter!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], noise = false)
        addWattmeter!(system30, device; bus = key, active = analysis.power.injection.active[value], noise = false)
        addVarmeter!(system30, device; bus = key, reactive = analysis.power.injection.reactive[value], noise = false)
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], noise = false)
    end

    for (key, value) in system30.branch.label
        addWattmeter!(system30, device; from = key, active = analysis.power.from.active[value], noise = false)
        addWattmeter!(system30, device; to = key, active = analysis.power.to.active[value], noise = false)
        addVarmeter!(system30, device; from = key, reactive = analysis.power.from.reactive[value], noise = false)
        addVarmeter!(system30, device; to = key, reactive = analysis.power.to.reactive[value], noise = false)
        addAmmeter!(system30, device; from = key, magnitude = analysis.current.from.magnitude[value], noise = false)
        addAmmeter!(system30, device; to = key, magnitude = analysis.current.to.magnitude[value], noise = false)
        addPmu!(system30, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], noise = false, varianceAngle = 1e-1, varianceMagnitude = 1e-1)
        addPmu!(system30, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], noise = false, varianceAngle = 1e-1, varianceMagnitude = 1e-1)
    end

    analysisOrt = gaussNewton(system30, device, Orthogonal)
    for iteration = 1:200
        stopping = solve!(system30, analysisOrt)
        if stopping < 1e-12
            break
        end
    end
    @test analysisOrt.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisOrt.voltage.angle ≈ analysis.voltage.angle


    ####### LAV #######
    device = measurement()
    for (key, value) in system30.bus.label
        addVoltmeter!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], noise = false)
        addWattmeter!(system30, device; bus = key, active = analysis.power.injection.active[value], noise = false)
        addVarmeter!(system30, device; bus = key, reactive = analysis.power.injection.reactive[value], noise = false)
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], noise = false)
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], noise = false, polar = false)
    end

    for (key, value) in system30.branch.label
        addWattmeter!(system30, device; from = key, active = analysis.power.from.active[value], noise = false)
        addWattmeter!(system30, device; to = key, active = analysis.power.to.active[value], noise = false)
        addVarmeter!(system30, device; from = key, reactive = analysis.power.from.reactive[value], noise = false)
        addVarmeter!(system30, device; to = key, reactive = analysis.power.to.reactive[value], noise = false)
        addPmu!(system30, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], noise = false, polar = false)
        addPmu!(system30, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], noise = false, polar = false)
    end

    analysisLAV = acLavStateEstimation(system30, device, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system30, analysisLAV)
    @test analysisLAV.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisLAV.voltage.angle ≈ analysis.voltage.angle
end

system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "PMU State Estimation" begin
    @default(template)
    @default(unit)

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

    device = measurement()
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], noise = false)
    end
    for (key, value) in system14.branch.label
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], noise = false)
        addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], noise = false)
    end

    ####### LU Factorization #######
    analysisLU = pmuWlsStateEstimation(system14, device, LU)
    solve!(system14, analysisLU)
    @test analysisLU.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisLU.voltage.angle ≈ analysis.voltage.angle

    ###### QR Factorization #######
    analysisQR = pmuWlsStateEstimation(system14, device, QR)
    solve!(system14, analysisQR)
    @test analysisQR.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle

    ####### Orthogonal Method #######
    analysisOrt = pmuWlsStateEstimation(system14, device, Orthogonal)
    solve!(system14, analysisOrt)
    @test analysisOrt.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisOrt.voltage.angle ≈ analysis.voltage.angle

    ####### LAV #######
    analysisLAV = pmuLavStateEstimation(system14, device, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system14, analysisLAV)
    @test analysisLAV.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisLAV.voltage.angle ≈ analysis.voltage.angle

    ####### Compare Powers #######
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

    ####### Compare Bus Powers #######
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

    ####### Compare Branch Powers #######
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

    device = measurement()
    for (key, value) in system30.bus.label
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], varianceAngle = 1e-6, varianceMagnitude = varianceAngle = 1e-5, correlated = true)
    end
    for (key, value) in system30.branch.label
        addPmu!(system30, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], varianceAngle = 1e-7, varianceMagnitude = varianceAngle = 1e-6, correlated = true)
        addPmu!(system30, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], varianceAngle = 1e-4, varianceMagnitude = varianceAngle = 1e-5)
    end

    ####### LU Factorization #######
    analysisLU = pmuWlsStateEstimation(system30, device, LU)
    solve!(system30, analysisLU)
    @test analysisLU.voltage.magnitude ≈ analysis.voltage.magnitude atol = 1e-2
    @test analysisLU.voltage.angle ≈ analysis.voltage.angle atol = 1e-2

    ####### LAV #######
    analysisLAV = pmuLavStateEstimation(system30, device, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system30, analysisLAV)
    @test analysisLAV.voltage.magnitude ≈ analysis.voltage.magnitude atol = 1e-1
    @test analysisLAV.voltage.angle ≈ analysis.voltage.angle atol = 1e-1
end


system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "DC State Estimation" begin
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
    for (key, value) in system14.bus.label
        addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[value], noise = false)
    end
    for (key, value) in system14.branch.label
        addWattmeter!(system14, device; from = key, active = analysis.power.from.active[value], noise = false)
        addWattmeter!(system14, device; to = key, active = analysis.power.to.active[value], noise = false)
    end

    ####### LU Factorization #######
    analysisLU = dcWlsStateEstimation(system14, device, LU)
    solve!(system14, analysisLU)
    @test analysisLU.voltage.angle ≈ analysis.voltage.angle

    ###### QR Factorization #######
    analysisQR = dcWlsStateEstimation(system14, device, QR)
    solve!(system14, analysisQR)
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle

    ####### Orthogonal Method #######
    analysisOrt = dcWlsStateEstimation(system14, device, Orthogonal)
    solve!(system14, analysisOrt)
    @test analysisOrt.voltage.angle ≈ analysis.voltage.angle

    ####### LAV #######
    analysisLAV = dcLavStateEstimation(system14, device, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system14, analysisLAV)
    @test analysisLAV.voltage.angle ≈ analysis.voltage.angle

    ################ PMUs ################
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = 1.0, angle = analysis.voltage.angle[value], noise = false)
    end

    ####### LU Factorization #######
    analysisLU = dcWlsStateEstimation(system14, device, LU)
    solve!(system14, analysisLU)
    @test analysisLU.voltage.angle ≈ analysis.voltage.angle

    ####### QR Factorization #######
    analysisQR = dcWlsStateEstimation(system14, device, QR)
    solve!(system14, analysisQR)
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle

    ####### Orthogonal Method #######
    analysisOrt = dcWlsStateEstimation(system14, device, Orthogonal)
    solve!(system14, analysisOrt)
    @test analysisOrt.voltage.angle ≈ analysis.voltage.angle

    ####### LAV #######
    analysisLAV = dcLavStateEstimation(system14, device, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system14, analysisLAV)
    @test analysisLAV.voltage.angle ≈ analysis.voltage.angle

    ####### Compare Powers #######
    power!(system14, analysisLAV)
    @test analysisLAV.power.injection.active ≈ analysis.power.injection.active
    @test analysisLAV.power.supply.active ≈ analysis.power.supply.active
    @test analysisLAV.power.from.active ≈ analysis.power.from.active
    @test analysisLAV.power.to.active ≈ analysis.power.to.active

    ####### Compare Bus Powers #######
    for (key, value) in system14.bus.label
        @test injectionPower(system14, analysisLAV; label = key) ≈ analysis.power.injection.active[value] atol = 1e-6
        @test supplyPower(system14, analysisLAV; label = key) ≈ analysis.power.supply.active[value] atol = 1e-6
    end

    ####### Compare Branch Powers #######
    for (key, value) in system14.branch.label
        @test fromPower(system14, analysisLAV; label = key) ≈ analysis.power.from.active[value] atol = 1e-6
        @test toPower(system14, analysisLAV; label = key) ≈ analysis.power.to.active[value] atol = 1e-6
    end

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
    analysisLU = dcWlsStateEstimation(system30, device, LU)
    solve!(system30, analysisLU)
    @test analysisLU.voltage.angle ≈ analysis.voltage.angle atol = 1e-2

    ####### QR Factorization #######
    analysisQR = dcWlsStateEstimation(system30, device, QR)
    solve!(system30, analysisQR)
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle atol = 1e-2

    ####### Orthogonal Method #######
    analysisOrt = dcWlsStateEstimation(system30, device, Orthogonal)
    solve!(system30, analysisOrt)
    @test analysisOrt.voltage.angle ≈ analysis.voltage.angle atol = 1e-2

    ####### LAV #######
    analysisLAV = dcLavStateEstimation(system30, device, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system30, analysisLAV)
    @test analysisLAV.voltage.angle ≈ analysis.voltage.angle atol = 1e-2

    ################ PMUs ################
    for (key, value) in system14.bus.label
        addPmu!(system14, device; bus = key, magnitude = 1.0, angle = analysis.voltage.angle[value], varianceAngle = 1e-9)
    end

    ####### LU Factorization #######
    analysisLU = dcWlsStateEstimation(system30, device, LU)
    solve!(system30, analysisLU)
    @test analysisLU.voltage.angle ≈ analysis.voltage.angle atol = 1e-2

    ####### QR Factorization #######
    analysisQR = dcWlsStateEstimation(system30, device, QR)
    solve!(system30, analysisQR)
    @test analysisQR.voltage.angle ≈ analysis.voltage.angle atol = 1e-2

    ####### Orthogonal Method #######
    analysisOrt = dcWlsStateEstimation(system30, device, Orthogonal)
    solve!(system30, analysisOrt)
    @test analysisOrt.voltage.angle ≈ analysis.voltage.angle atol = 1e-2

    ####### LAV #######
    analysisLAV = dcLavStateEstimation(system30, device, Ipopt.Optimizer)
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

    analysisLU = dcWlsStateEstimation(system30, device, LU)
    solve!(system30, analysisLU)

    analysisQR = dcWlsStateEstimation(system30, device, QR)
    solve!(system30, analysisQR)
    @test analysisLU.voltage.angle ≈ analysisQR.voltage.angle

    analysisOrt = dcWlsStateEstimation(system30, device, Orthogonal)
    solve!(system30, analysisOrt)
    @test analysisLU.voltage.angle ≈ analysisOrt.voltage.angle

    ################ PMUs ################
    addPmu!(system30, device, analysis; varianceAngleBus = 1e-5)

    analysisLU = dcWlsStateEstimation(system30, device, LU)
    solve!(system30, analysisLU)

    analysisQR = dcWlsStateEstimation(system30, device, QR)
    solve!(system30, analysisQR)
    @test analysisLU.voltage.angle ≈ analysisQR.voltage.angle

    analysisOrt = dcWlsStateEstimation(system30, device, Orthogonal)
    solve!(system30, analysisOrt)
    @test analysisLU.voltage.angle ≈ analysisOrt.voltage.angle
end

system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "DC State Estimation: Incomplete Set" begin
    @default(template)
    @default(unit)

    ############### Modified IEEE 14-bus Test Case ################
    dcModel!(system14)
    updateBranch!(system14; label = 4, status = 0)
    updateBranch!(system14; label = 15, status = 0)
    analysis = dcPowerFlow(system14)
    solve!(system14, analysis)
    power!(system14, analysis)

    deviceAll = measurement()
    devicePart = measurement()

    ################ Wattmeters ################
    for (key, value) in system14.bus.label
        if value in [1; 5; 8]
            addWattmeter!(system14, deviceAll; bus = key, active = analysis.power.injection.active[value], noise = false, status = 0)
        else
            addWattmeter!(system14, deviceAll; bus = key, active = analysis.power.injection.active[value], noise = false)
            addWattmeter!(system14, devicePart; bus = key, active = analysis.power.injection.active[value], noise = false)
        end
    end

    for (key, value) in system14.branch.label
        if value in [4; 15; 19]
            addWattmeter!(system14, deviceAll; from = key, active = analysis.power.from.active[value], noise = false, status = 0)
        else
            addWattmeter!(system14, deviceAll; from = key, active = analysis.power.from.active[value], noise = false)
            addWattmeter!(system14, devicePart; from = key, active = analysis.power.from.active[value], noise = false)
        end
        if value in [4; 16; 20]
            addWattmeter!(system14, deviceAll; to = key, active = analysis.power.to.active[value], noise = false, status = 0)
        else
            addWattmeter!(system14, deviceAll; to = key, active = analysis.power.to.active[value], noise = false)
            addWattmeter!(system14, devicePart; to = key, active = analysis.power.to.active[value], noise = false)
        end
    end

    analysisAll = dcWlsStateEstimation(system14, deviceAll)
    solve!(system14, analysisAll)

    analysisLU = dcWlsStateEstimation(system14, devicePart)
    solve!(system14, analysisLU)
    @test analysisAll.voltage.angle ≈ analysisLU.voltage.angle

    analysisOrt = dcWlsStateEstimation(system14, devicePart, Orthogonal)
    solve!(system14, analysisOrt)
    @test analysisAll.voltage.angle ≈ analysisOrt.voltage.angle

    ################ PMUs ################
    for (key, value) in system14.bus.label
        if value in [1; 6; 10; 14]
            addPmu!(system14, deviceAll; bus = key, magnitude = 1.0, angle = analysis.voltage.angle[value], noise = false, statusAngle = 0)
        else
            addPmu!(system14, deviceAll; bus = key, magnitude = 1.0, angle = analysis.voltage.angle[value], noise = false)
            addPmu!(system14, devicePart; bus = key, magnitude = 1.0, angle = analysis.voltage.angle[value], noise = false)
        end
    end

    analysisAll = dcWlsStateEstimation(system14, deviceAll)
    solve!(system14, analysisAll)

    analysisLU = dcWlsStateEstimation(system14, devicePart)
    solve!(system14, analysisLU)
    @test analysisAll.voltage.angle ≈ analysisLU.voltage.angle

    analysisOrt = dcWlsStateEstimation(system14, devicePart, Orthogonal)
    solve!(system14, analysisOrt)
    @test analysisAll.voltage.angle ≈ analysisOrt.voltage.angle

    analysisLAV = dcLavStateEstimation(system14, devicePart, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system14, analysisLAV)
    @test analysisAll.voltage.angle ≈ analysisLAV.voltage.angle

    ############### Modified IEEE 30-bus Test Case ################
    dcModel!(system30)
    updateBranch!(system30; label = 2, status = 0)
    updateBranch!(system30; label = 21, status = 0)
    analysis = dcPowerFlow(system30)
    solve!(system30, analysis)
    power!(system30, analysis)

    ################ Measurements ################
    device = measurement()
    for (key, value) in system30.bus.label
        addWattmeter!(system30, device; bus = key, active = analysis.power.injection.active[value], noise = false)
    end
    for (key, value) in system30.branch.label
        addWattmeter!(system30, device; from = key, active = analysis.power.from.active[value], noise = false)
        addWattmeter!(system30, device; to = key, active = analysis.power.to.active[value], noise = false)
    end
    for (key, value) in system30.bus.label
        addPmu!(system30, device; bus = key, magnitude = 1.0, angle = analysis.voltage.angle[value], noise = false)
    end
    status!(system30, device; inservice = 100)

    analysisLU = dcWlsStateEstimation(system30, device)
    solve!(system30, analysisLU)
    @test analysis.voltage.angle ≈ analysisLU.voltage.angle

    analysisOrt = dcWlsStateEstimation(system30, device, Orthogonal)
    solve!(system30, analysisOrt)
    @test analysis.voltage.angle ≈ analysisOrt.voltage.angle

    analysisLAV = dcLavStateEstimation(system30, device, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system30, analysisLAV)
    @test analysis.voltage.angle ≈ analysisLAV.voltage.angle
end