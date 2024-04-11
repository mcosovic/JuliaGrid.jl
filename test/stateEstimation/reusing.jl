system14 = powerSystem(string(pathData, "case14test.m"))
@testset "Reusing Meters AC State Estimation" begin
    @default(template)
    @default(unit)

    ################ Modified IEEE 14-bus Test Case ################
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

    ####### Measurements #######
    device = measurement()

    @wattmeter(label = "!")
    @varmeter(label = "!")
    @ammeter(label = "!")
    for (key, value) in system14.bus.label
        if value == 1
            addVoltmeter!(system14, device; bus = key, magnitude = rand(1)[], noise = false)
            addWattmeter!(system14, device; bus = key, active = rand(1)[], noise = false)
            addVarmeter!(system14, device; bus = key, reactive = rand(1)[], noise = false)
            addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = rand(1)[], noise = false)
        elseif value == 3
            addVoltmeter!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], noise = false, status = 0)
            addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[value], noise = false, status = 0)
            addVarmeter!(system14, device; bus = key, reactive = analysis.power.injection.reactive[value], noise = false, status = 0)
            addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], noise = false, statusAngle = 0)
        elseif value == 5
            addVoltmeter!(system14, device; bus = key, magnitude = rand(1)[], variance = 1e-5)
            addWattmeter!(system14, device; bus = key, active = rand(1)[], variance = 1e-5)
            addVarmeter!(system14, device; bus = key, reactive = rand(1)[], variance = 1e-5)
            addPmu!(system14, device; bus = key, magnitude = 1, angle = rand(1)[], varianceAngle = 1e-5)
        else
            addVoltmeter!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], noise = false)
            addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[value], noise = false)
            addVarmeter!(system14, device; bus = key, reactive = analysis.power.injection.reactive[value], noise = false)
            addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], noise = false)
        end
    end

    for (key, value) in system14.bus.label
        if value == 1
            addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = rand(1)[], polar = false, correlated = true, noise = false)
        elseif value == 3
            addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], polar = false, noise = false, statusAngle = 0)
        elseif value == 5
            addPmu!(system14, device; bus = key, magnitude = 1, angle = rand(1)[], varianceAngle = 1e-5, polar = false, correlated = true)
        else
            addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], polar = false, noise = false)
        end
    end

    for (key, value) in system14.branch.label
        if value == 4
            addWattmeter!(system14, device; from = key, active = rand(1)[], noise = false)
            addVarmeter!(system14, device; from = key, reactive = rand(1)[], noise = false)
            addAmmeter!(system14, device; from = key, magnitude = rand(1)[], noise = false)
            addPmu!(system14, device; label = "PMU 4", from = key, magnitude = analysis.current.from.magnitude[value], angle = 999, noise = false)
        elseif value == 15
            addWattmeter!(system14, device; from = key, active = analysis.power.from.active[value], noise = false, status = 0)
            addVarmeter!(system14, device; from = key, reactive = analysis.power.from.reactive[value], noise = false, status = 0)
            addAmmeter!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], noise = false, status = 0)
            addPmu!(system14, device; label = "PMU 15", from = key, magnitude = analysis.current.from.magnitude[value], angle = 999, polar = false, noise = false)
        elseif value == 17
            addWattmeter!(system14, device; from = key, active = rand(1)[], variance = 1e-5)
            addVarmeter!(system14, device; from = key, reactive = rand(1)[], variance = 1e-5)
            addAmmeter!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], noise = false, status = 0)
            addPmu!(system14, device; label = "PMU 17", from = key, magnitude = 999, angle = analysis.current.from.angle[value], noise = false)
        else
            addWattmeter!(system14, device; from = key, active = analysis.power.from.active[value], noise = false)
            addVarmeter!(system14, device; from = key, reactive = analysis.power.from.reactive[value], noise = false)
            addAmmeter!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], noise = false, status = 0)
            addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], polar = false, noise = false)
        end

        if value == 4
            addWattmeter!(system14, device; to = key, active = rand(1)[], noise = false)
            addVarmeter!(system14, device; to = key, reactive = rand(1)[], noise = false)
            addAmmeter!(system14, device; to = key, magnitude = rand(1)[], noise = false)
            addPmu!(system14, device; label = "PMU 4 To", to = key, magnitude = analysis.current.to.magnitude[value], angle = 999, noise = false)
        elseif value == 15
            addWattmeter!(system14, device; to = key, active = analysis.power.to.active[value], noise = false, status = 0)
            addVarmeter!(system14, device; to = key, reactive = analysis.power.to.reactive[value], noise = false, status = 0)
            addAmmeter!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], noise = false, status = 0)
            addPmu!(system14, device; label = "PMU 15 To", to = key, magnitude = analysis.current.to.magnitude[value], angle = 999, polar = false, noise = false)
        elseif value == 17
            addWattmeter!(system14, device; to = key, active = rand(1)[], variance = 1e-5)
            addVarmeter!(system14, device; to = key, reactive = rand(1)[], variance = 1e-5)
            addAmmeter!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], noise = false, status = 0)
            addPmu!(system14, device; label = "PMU 17 To", to = key, magnitude = 999, angle = analysis.current.to.angle[value], noise = false)
        else
            addWattmeter!(system14, device; to = key, active = analysis.power.to.active[value], noise = false)
            addVarmeter!(system14, device; to = key, reactive = analysis.power.to.reactive[value], noise = false)
            addAmmeter!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], noise = false, status = 0)
            addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], polar = false, noise = false)
        end
    end


    ####### Original WLS and LAV Models #######
    analysisWLS = gaussNewton(system14, device)
    analysisLAV = acLavStateEstimation(system14, device, Ipopt.Optimizer)

    ####### Update Only Devices #######
    updateVoltmeter!(system14, device; label = 1, status = 0)
    updateVoltmeter!(system14, device; label = 3, status = 1)
    updateVoltmeter!(system14, device; label = 5, magnitude = analysis.voltage.magnitude[5], variance = 1e-2, noise = false)

    updateWattmeter!(system14, device; label = 1, status = 0)
    updateWattmeter!(system14, device; label = 3, status = 1)
    updateWattmeter!(system14, device; label = 5, active = analysis.power.injection.active[5], variance = 1e-2, noise = false)

    updateVarmeter!(system14, device; label = 1, status = 0)
    updateVarmeter!(system14, device; label = 3, status = 1)
    updateVarmeter!(system14, device; label = 5, reactive = analysis.power.injection.reactive[5], variance = 1e-2, noise = false)

    updatePmu!(system14, device; label = 1, statusAngle = 0)
    updatePmu!(system14, device; label = 3, statusAngle = 1, polar = false)
    updatePmu!(system14, device; label = 5, magnitude = analysis.voltage.magnitude[5], angle = analysis.voltage.angle[5], varianceAngle = 1e-5, noise = false)

    updatePmu!(system14, device; label = 15, statusAngle = 0)
    updatePmu!(system14, device; label = 17, statusAngle = 1, polar = true)
    updatePmu!(system14, device; label = 19, magnitude = analysis.voltage.magnitude[5], angle = analysis.voltage.angle[5], varianceAngle = 1e-5, noise = false, correlated = true)

    updateWattmeter!(system14, device; label = "From 4", status = 0)
    updateWattmeter!(system14, device; label = "From 15", status = 1)
    updateWattmeter!(system14, device; label = "From 17", active = analysis.power.from.active[17], variance = 1e-2, noise = false)

    updateVarmeter!(system14, device; label = "From 4", status = 0)
    updateVarmeter!(system14, device; label = "From 15", status = 1)
    updateVarmeter!(system14, device; label = "From 17", reactive = analysis.power.from.reactive[17], variance = 1e-2, noise = false)

    updateAmmeter!(system14, device; label = "From 4", status = 0)
    updateAmmeter!(system14, device; label = "From 15", status = 1)
    updateAmmeter!(system14, device; label = "From 17", magnitude = analysis.current.from.magnitude[17], variance = 1e-2, noise = false)

    updatePmu!(system14, device; label = "PMU 4", statusAngle = 0)
    updatePmu!(system14, device; label = "PMU 15", angle = analysis.current.from.angle[15], noise = false)
    updatePmu!(system14, device; label = "PMU 17", magnitude = analysis.current.from.magnitude[17], noise = false)

    updateWattmeter!(system14, device; label = "To 4", status = 0)
    updateWattmeter!(system14, device; label = "To 15", status = 1)
    updateWattmeter!(system14, device; label = "To 17", active = analysis.power.to.active[17], variance = 1e-2, noise = false)

    updateVarmeter!(system14, device; label = "To 4", status = 0)
    updateVarmeter!(system14, device; label = "To 15", status = 1)
    updateVarmeter!(system14, device; label = "To 17", reactive = analysis.power.to.reactive[17], variance = 1e-2, noise = false)

    updateAmmeter!(system14, device; label = "To 4", status = 0)
    updateAmmeter!(system14, device; label = "To 15", status = 1)
    updateAmmeter!(system14, device; label = "To 17", magnitude = analysis.current.to.magnitude[17], variance = 1e-2, noise = false)

    updatePmu!(system14, device; label = "PMU 4 To", statusAngle = 0)
    updatePmu!(system14, device; label = "PMU 15 To", angle = analysis.current.to.angle[15], noise = false)
    updatePmu!(system14, device; label = "PMU 17 To", magnitude = analysis.current.to.magnitude[17], noise = false)

    ####### Solve Updated WLS and LAV Models #######
    analysisWLSUpdate = gaussNewton(system14, device)
    for iteration = 1:40
        stopping = solve!(system14, analysisWLSUpdate)
        if stopping < 1e-12
            break
        end
    end
    @test analysisWLSUpdate.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisWLSUpdate.voltage.angle ≈ analysis.voltage.angle

    analysisLAVUpdate = acLavStateEstimation(system14, device, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAVUpdate.method.jump)
    solve!(system14, analysisLAVUpdate)
    @test analysisLAVUpdate.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisLAVUpdate.voltage.angle ≈ analysis.voltage.angle


    ##### Update Devices and Original WLS Model #######
    updateVoltmeter!(system14, device, analysisWLS; label = 1, status = 0)
    updateVoltmeter!(system14, device, analysisWLS; label = 3, status = 1)
    updateVoltmeter!(system14, device, analysisWLS; label = 5, magnitude = analysis.voltage.magnitude[5], variance = 1e-2, noise = false)

    updateWattmeter!(system14, device, analysisWLS; label = 1, status = 0)
    updateWattmeter!(system14, device, analysisWLS; label = 3, status = 1)
    updateWattmeter!(system14, device, analysisWLS; label = 5, active = analysis.power.injection.active[5], variance = 1e-2, noise = false)

    updateVarmeter!(system14, device, analysisWLS; label = 1, status = 0)
    updateVarmeter!(system14, device, analysisWLS; label = 3, status = 1)
    updateVarmeter!(system14, device, analysisWLS; label = 5, reactive = analysis.power.injection.reactive[5], variance = 1e-2, noise = false)

    updatePmu!(system14, device, analysisWLS; label = 1, statusAngle = 0)
    updatePmu!(system14, device, analysisWLS; label = 3, statusAngle = 1)
    updatePmu!(system14, device, analysisWLS; label = 5, magnitude = analysis.voltage.magnitude[5], angle = analysis.voltage.angle[5], varianceAngle = 1e-5, noise = false)

    updatePmu!(system14, device, analysisWLS; label = 15, statusAngle = 0)
    updatePmu!(system14, device, analysisWLS; label = 17, statusAngle = 1, polar = true)
    updatePmu!(system14, device, analysisWLS; label = 19, magnitude = analysis.voltage.magnitude[5], angle = analysis.voltage.angle[5], varianceAngle = 1e-5, noise = false, correlated = true)

    updateWattmeter!(system14, device, analysisWLS; label = "From 4", status = 0)
    updateWattmeter!(system14, device, analysisWLS; label = "From 15", status = 1)
    updateWattmeter!(system14, device, analysisWLS; label = "From 17", active = analysis.power.from.active[17], variance = 1e-2, noise = false)

    updateVarmeter!(system14, device, analysisWLS; label = "From 4", status = 0)
    updateVarmeter!(system14, device, analysisWLS; label = "From 15", status = 1)
    updateVarmeter!(system14, device, analysisWLS; label = "From 17", reactive = analysis.power.from.reactive[17], variance = 1e-2, noise = false)

    updateAmmeter!(system14, device, analysisWLS; label = "From 4", status = 0)
    updateAmmeter!(system14, device, analysisWLS; label = "From 15", status = 1)
    updateAmmeter!(system14, device, analysisWLS; label = "From 17", magnitude = analysis.current.from.magnitude[17], variance = 1e-2, noise = false)

    updatePmu!(system14, device, analysisWLS; label = "PMU 4", statusAngle = 0)
    updatePmu!(system14, device, analysisWLS; label = "PMU 15", angle = analysis.current.from.angle[15], noise = false)
    updatePmu!(system14, device, analysisWLS; label = "PMU 17", magnitude = analysis.current.from.magnitude[17], noise = false)

    updateWattmeter!(system14, device, analysisWLS; label = "To 4", status = 0)
    updateWattmeter!(system14, device, analysisWLS; label = "To 15", status = 1)
    updateWattmeter!(system14, device, analysisWLS; label = "To 17", active = analysis.power.to.active[17], variance = 1e-2, noise = false)

    updateVarmeter!(system14, device, analysisWLS; label = "To 4", status = 0)
    updateVarmeter!(system14, device, analysisWLS; label = "To 15", status = 1)
    updateVarmeter!(system14, device, analysisWLS; label = "To 17", reactive = analysis.power.to.reactive[17], variance = 1e-2, noise = false)

    updateAmmeter!(system14, device, analysisWLS; label = "To 4", status = 0)
    updateAmmeter!(system14, device, analysisWLS; label = "To 15", status = 1)
    updateAmmeter!(system14, device, analysisWLS; label = "To 17", magnitude = analysis.current.to.magnitude[17], variance = 1e-2, noise = false)

    updatePmu!(system14, device, analysisWLS; label = "PMU 4 To", statusAngle = 0)
    updatePmu!(system14, device, analysisWLS; label = "PMU 15 To", angle = analysis.current.to.angle[15], noise = false)
    updatePmu!(system14, device, analysisWLS; label = "PMU 17 To", magnitude = analysis.current.to.magnitude[17], noise = false)

    analysisWLS = gaussNewton(system14, device)
    for iteration = 1:20
        stopping = solve!(system14, analysisWLS)
        if stopping < 1e-12
            break
        end
    end
    @test analysisWLS.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisWLS.voltage.angle ≈ analysis.voltage.angle

    #### Update Devices and Original LAV Model #######
    updateVoltmeter!(system14, device, analysisLAV; label = 1, status = 0)
    updateVoltmeter!(system14, device, analysisLAV; label = 3, status = 1)
    updateVoltmeter!(system14, device, analysisLAV; label = 5, magnitude = analysis.voltage.magnitude[5], variance = 1e-2, noise = false)

    updateWattmeter!(system14, device, analysisLAV; label = 1, status = 0)
    updateWattmeter!(system14, device, analysisLAV; label = 3, status = 1)
    updateWattmeter!(system14, device, analysisLAV; label = 5, active = analysis.power.injection.active[5], variance = 1e-2, noise = false)

    updateVarmeter!(system14, device, analysisLAV; label = 1, status = 0)
    updateVarmeter!(system14, device, analysisLAV; label = 3, status = 1)
    updateVarmeter!(system14, device, analysisLAV; label = 5, reactive = analysis.power.injection.reactive[5], variance = 1e-2, noise = false)

    updatePmu!(system14, device, analysisLAV; label = 1, statusAngle = 0)
    updatePmu!(system14, device, analysisLAV; label = 3, statusAngle = 1)
    updatePmu!(system14, device, analysisLAV; label = 5, magnitude = analysis.voltage.magnitude[5], angle = analysis.voltage.angle[5], varianceAngle = 1e-5, noise = false)

    updatePmu!(system14, device, analysisLAV; label = 15, statusAngle = 0)
    updatePmu!(system14, device, analysisLAV; label = 17, statusAngle = 1, polar = true)
    updatePmu!(system14, device, analysisLAV; label = 19, magnitude = analysis.voltage.magnitude[5], angle = analysis.voltage.angle[5], varianceAngle = 1e-5, noise = false, correlated = true)

    updateWattmeter!(system14, device, analysisLAV; label = "From 4", status = 0)
    updateWattmeter!(system14, device, analysisLAV; label = "From 15", status = 1)
    updateWattmeter!(system14, device, analysisLAV; label = "From 17", active = analysis.power.from.active[17], variance = 1e-2, noise = false)

    updateVarmeter!(system14, device, analysisLAV; label = "From 4", status = 0)
    updateVarmeter!(system14, device, analysisLAV; label = "From 15", status = 1)
    updateVarmeter!(system14, device, analysisLAV; label = "From 17", reactive = analysis.power.from.reactive[17], variance = 1e-2, noise = false)

    updateAmmeter!(system14, device, analysisLAV; label = "From 4", status = 0)
    updateAmmeter!(system14, device, analysisLAV; label = "From 15", status = 1)
    updateAmmeter!(system14, device, analysisLAV; label = "From 17", magnitude = analysis.current.from.magnitude[17], variance = 1e-2, noise = false)

    updatePmu!(system14, device, analysisLAV; label = "PMU 4", statusAngle = 0)
    updatePmu!(system14, device, analysisLAV; label = "PMU 15", angle = analysis.current.from.angle[15], noise = false)
    updatePmu!(system14, device, analysisLAV; label = "PMU 17", magnitude = analysis.current.from.magnitude[17], noise = false)

    updateWattmeter!(system14, device, analysisLAV; label = "To 4", status = 0)
    updateWattmeter!(system14, device, analysisLAV; label = "To 15", status = 1)
    updateWattmeter!(system14, device, analysisLAV; label = "To 17", active = analysis.power.to.active[17], variance = 1e-2, noise = false)

    updateVarmeter!(system14, device, analysisLAV; label = "To 4", status = 0)
    updateVarmeter!(system14, device, analysisLAV; label = "To 15", status = 1)
    updateVarmeter!(system14, device, analysisLAV; label = "To 17", reactive = analysis.power.to.reactive[17], variance = 1e-2, noise = false)

    updateAmmeter!(system14, device, analysisLAV; label = "To 4", status = 0)
    updateAmmeter!(system14, device, analysisLAV; label = "To 15", status = 1)
    updateAmmeter!(system14, device, analysisLAV; label = "To 17", magnitude = analysis.current.to.magnitude[17], variance = 1e-2, noise = false)

    updatePmu!(system14, device, analysisLAV; label = "PMU 4 To", statusAngle = 0)
    updatePmu!(system14, device, analysisLAV; label = "PMU 15 To", angle = analysis.current.to.angle[15], noise = false)
    updatePmu!(system14, device, analysisLAV; label = "PMU 17 To", magnitude = analysis.current.to.magnitude[17], noise = false)

    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system14, analysisLAV)
    @test analysisLAV.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisLAV.voltage.angle ≈ analysis.voltage.angle
end

system14 = powerSystem(string(pathData, "case14test.m"))
@testset "Reusing Meters PMU State Estimation" begin
    @default(template)
    @default(unit)

    ################ Modified IEEE 14-bus Test Case ################
    acModel!(system14)
    analysis = newtonRaphson(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, analysis)
    end
    current!(system14, analysis)

    ####### Measurements #######
    device = measurement()

    placement = pmuPlacement(system14, GLPK.Optimizer)
    device = measurement()
    @pmu(label = "!")
    for (key, value) in placement.bus
        if value == 1
            addPmu!(system14, device; bus = key, magnitude = rand(1)[], angle = analysis.voltage.angle[value], noise = false)
        elseif value == 4
            addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = rand(1)[], statusMagnitude = 0, noise = false, correlated = true)
        elseif value == 6
            addPmu!(system14, device; bus = key, magnitude = rand(1)[], angle = rand(1)[], statusAngle = 0, noise = false)
        else
            addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], noise = false)
        end
    end

    for (key, value) in placement.from
        if value == 8
            addPmu!(system14, device; from = key, magnitude = rand(1)[], angle = rand(1)[], noise = false)
        elseif value == 9
            addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], statusAngle = 0, statusMagnitude = 0, noise = false)
        elseif value == 12
            addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = rand(1)[], noise = false, correlated = true)
        else
            addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], noise = false)
        end
    end
    for (key, value) in placement.to
        if value == 4
            addPmu!(system14, device; to = key, magnitude = rand(1)[], angle = analysis.current.to.angle[value], noise = false)
        elseif value == 10
            addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = rand(1)[], noise = false)
        elseif value == 15
            addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value],  statusAngle = 0, noise = false)
        else
            addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], noise = false)
        end
    end

    ####### Original Device, WLS and LAV Models #######
    deviceWLS = deepcopy(device)
    deviceLAV = deepcopy(device)
    analysisWLS = pmuWlsStateEstimation(system14, device)
    analysisLAV = pmuLavStateEstimation(system14, device, Ipopt.Optimizer)

    ####### Update Just PMUs #######
    updatePmu!(system14, device; label = 1, magnitude = analysis.voltage.magnitude[1], noise = false)
    updatePmu!(system14, device; label = 4, angle = analysis.voltage.angle[4], statusMagnitude = 1, noise = false)
    updatePmu!(system14, device; label = 16,  magnitude = analysis.voltage.magnitude[6], angle = analysis.voltage.angle[6], statusAngle = 1, noise = false)

    updatePmu!(system14, device; label = "From 8", magnitude = analysis.current.from.magnitude[8], angle = analysis.current.from.angle[8], noise = false)
    updatePmu!(system14, device; label = "From 9", statusAngle = 1, statusMagnitude = 1)
    updatePmu!(system14, device; label = "From 12", angle = analysis.current.from.angle[12], noise = false)

    updatePmu!(system14, device; label = "To 4", magnitude = analysis.current.to.magnitude[4], noise = false)
    updatePmu!(system14, device; label = "To 10", angle = analysis.current.to.angle[10], noise = false)
    updatePmu!(system14, device; label = "To 15", statusAngle = 1)

    ####### Solve Updated WLS and LAV Models #######
    analysisWLSUpdate = pmuWlsStateEstimation(system14, device)
    solve!(system14, analysisWLSUpdate)
    @test analysisWLSUpdate.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisWLSUpdate.voltage.angle ≈ analysis.voltage.angle

    analysisLAVUpdate = pmuLavStateEstimation(system14, device, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAVUpdate.method.jump)
    solve!(system14, analysisLAVUpdate)
    @test analysisLAVUpdate.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisLAVUpdate.voltage.angle ≈ analysis.voltage.angle

    ##### Update Devices and Original WLS Model #######
    updatePmu!(system14, deviceWLS, analysisWLS; label = 1, magnitude = analysis.voltage.magnitude[1], noise = false)
    updatePmu!(system14, deviceWLS, analysisWLS; label = 4, angle = analysis.voltage.angle[4], statusMagnitude = 1, noise = false)
    updatePmu!(system14, deviceWLS, analysisWLS; label = 16,  magnitude = analysis.voltage.magnitude[6], angle = analysis.voltage.angle[6], statusAngle = 1, noise = false)

    updatePmu!(system14, deviceWLS, analysisWLS; label = "From 8", magnitude = analysis.current.from.magnitude[8], angle = analysis.current.from.angle[8], noise = false)
    updatePmu!(system14, deviceWLS, analysisWLS; label = "From 9", statusAngle = 1, statusMagnitude = 1)
    updatePmu!(system14, deviceWLS, analysisWLS; label = "From 12", angle = analysis.current.from.angle[12], noise = false)

    updatePmu!(system14, deviceWLS, analysisWLS; label = "To 4", magnitude = analysis.current.to.magnitude[4], noise = false)
    updatePmu!(system14, deviceWLS, analysisWLS; label = "To 10", angle = analysis.current.to.angle[10], noise = false)
    updatePmu!(system14, deviceWLS, analysisWLS; label = "To 15", statusAngle = 1)

    solve!(system14, analysisWLS)
    @test analysisWLS.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisWLS.voltage.angle ≈ analysis.voltage.angle

    #### Update Devices and Original LAV Model #######
    updatePmu!(system14, deviceLAV, analysisLAV; label = 1, magnitude = analysis.voltage.magnitude[1], noise = false)
    updatePmu!(system14, deviceLAV, analysisLAV; label = 4, angle = analysis.voltage.angle[4], statusMagnitude = 1, noise = false)
    updatePmu!(system14, deviceLAV, analysisLAV; label = 16,  magnitude = analysis.voltage.magnitude[6], angle = analysis.voltage.angle[6], statusAngle = 1, noise = false)

    updatePmu!(system14, deviceLAV, analysisLAV; label = "From 8", magnitude = analysis.current.from.magnitude[8], angle = analysis.current.from.angle[8], noise = false)
    updatePmu!(system14, deviceLAV, analysisLAV; label = "From 9", statusAngle = 1, statusMagnitude = 1)
    updatePmu!(system14, deviceLAV, analysisLAV; label = "From 12", angle = analysis.current.from.angle[12], noise = false)

    updatePmu!(system14, deviceLAV, analysisLAV; label = "To 4", magnitude = analysis.current.to.magnitude[4], noise = false)
    updatePmu!(system14, deviceLAV, analysisLAV; label = "To 10", angle = analysis.current.to.angle[10], noise = false)
    updatePmu!(system14, deviceLAV, analysisLAV; label = "To 15", statusAngle = 1)

    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system14, analysisLAV)
    @test analysisLAV.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisLAV.voltage.angle ≈ analysis.voltage.angle

    ####### Check Precision Matrix #######
    precision = copy(analysisWLS.method.precision)

    updatePmu!(system14, deviceWLS, analysisWLS; label = 4, correlated = false)
    @test analysisWLS.method.precision[5, 4] == 0.0
    @test analysisWLS.method.precision[4, 5] == 0.0

    updatePmu!(system14, deviceWLS, analysisWLS; label = 4, correlated = true)
    @test analysisWLS.method.precision[4, 4] ≈ precision[4, 4]
    @test analysisWLS.method.precision[4, 5] ≈ precision[4, 5]
    @test analysisWLS.method.precision[5, 5] ≈ precision[5, 5]
    @test analysisWLS.method.precision[5, 4] ≈ precision[5, 4]

    updatePmu!(system14, deviceWLS, analysisWLS; label = "From 12", angle = -5.5, correlated = false)
    @test analysisWLS.method.precision[23, 24] == 0.0
    @test analysisWLS.method.precision[24, 23] == 0.0

    updatePmu!(system14, deviceWLS, analysisWLS; label = "From 12", angle = analysis.current.from.angle[12], noise = false, correlated = true)
    @test analysisWLS.method.precision[23, 23] ≈ precision[23, 23]
    @test analysisWLS.method.precision[23, 24] ≈ precision[23, 24]
    @test analysisWLS.method.precision[24, 24] ≈ precision[24, 24]
    @test analysisWLS.method.precision[24, 23] ≈ precision[24, 23]

    updatePmu!(system14, deviceWLS, analysisWLS; label = "From 11", correlated = true)
    updatePmu!(system14, deviceWLS, analysisWLS; label = "From 11", correlated = false)
    @test analysisWLS.method.precision[21, 21] ≈ precision[21, 21]
    @test analysisWLS.method.precision[22, 22] ≈ precision[22, 22]
    @test analysisWLS.method.precision[21, 22] == 0.0
    @test analysisWLS.method.precision[22, 21] == 0.0
end

system14 = powerSystem(string(pathData, "case14test.m"))
@testset "Reusing Meters DC State Estimation" begin
    @default(template)
    @default(unit)

    ############### Modified IEEE 14-bus Test Case ################
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)
    updateBranch!(system14; label = 7, status = 0)
    updateBranch!(system14; label = 12, status = 0)

    dcModel!(system14)
    analysis = dcPowerFlow(system14)
    solve!(system14, analysis)
    power!(system14, analysis)

    ####### Measurements #######
    device = measurement()

    @wattmeter(label = "!")
    for (key, value) in system14.bus.label
        if value == 1
            addWattmeter!(system14, device; bus = key, active = rand(1)[], noise = false)
        elseif value == 3
            addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[value], noise = false, status = 0)
        elseif value == 5
            addWattmeter!(system14, device; bus = key, active = rand(1)[], variance = 1e-5)
        elseif value == 9
            addWattmeter!(system14, device; bus = key, active = rand(1)[], noise = false)
        else
            addWattmeter!(system14, device; bus = key, active = analysis.power.injection.active[value], noise = false)
        end
    end

    for (key, value) in system14.branch.label
        if value == 4
            addWattmeter!(system14, device; from = key, active = rand(1)[], noise = false)
        elseif value == 15
            addWattmeter!(system14, device; from = key, active = analysis.power.from.active[value], noise = false, status = 0)
        elseif value == 17
            addWattmeter!(system14, device; from = key, active = rand(1)[], variance = 1e-5)
        elseif value == 20
            addWattmeter!(system14, device; from = key, active = rand(1)[])
        else
            addWattmeter!(system14, device; from = key, active = analysis.power.from.active[value], noise = false)
        end

        if value == 5
            addWattmeter!(system14, device; to = key, active = rand(1)[], noise = false)
        elseif value == 8
            addWattmeter!(system14, device; to = key, active = analysis.power.to.active[value], noise = false, status = 0)
        elseif value == 11
            addWattmeter!(system14, device; to = key, active = rand(1)[], variance = 1e-5)
        elseif value == 19
            addWattmeter!(system14, device; to = key, active = rand(1)[])
        else
            addWattmeter!(system14, device; to = key, active = analysis.power.to.active[value], noise = false)
        end
    end

    for (key, value) in system14.bus.label
        if value == 2
            addPmu!(system14, device; bus = key, magnitude = 1, angle = rand(1)[], noise = false)
        elseif value == 6
            addPmu!(system14, device; bus = key, magnitude = 1, angle = analysis.voltage.angle[value], noise = false, statusAngle = 0)
        elseif value == 9
            addPmu!(system14, device; bus = key, magnitude = 1, angle = rand(1)[], varianceAngle = 1e-5)
        elseif value == 13
            addPmu!(system14, device; bus = key, magnitude = 1, angle = rand(1)[], noise = false)
        else
            addPmu!(system14, device; bus = key, magnitude = 1, angle = analysis.voltage.angle[value], noise = false)
        end
    end

    ####### Original WLS and LAV Models #######
    analysisWLS = dcWlsStateEstimation(system14, device)
    analysisLAV = dcLavStateEstimation(system14, device, Ipopt.Optimizer)

    ####### Update Only Devices #######
    updateWattmeter!(system14, device; label = 1, status = 0)
    updateWattmeter!(system14, device; label = 3, status = 1)
    updateWattmeter!(system14, device; label = 5, active = analysis.power.injection.active[5], variance = 1e-2, noise = false)
    updateWattmeter!(system14, device; label = 9, active = analysis.power.injection.active[9], noise = false)

    updateWattmeter!(system14, device; label = "From 4", status = 0)
    updateWattmeter!(system14, device; label = "From 15", status = 1)
    updateWattmeter!(system14, device; label = "From 17", active = analysis.power.from.active[17], variance = 1e-2, noise = false)
    updateWattmeter!(system14, device; label = "From 20", active = analysis.power.from.active[20], noise = false)

    updateWattmeter!(system14, device; label = "To 5", status = 0)
    updateWattmeter!(system14, device; label = "To 8", status = 1)
    updateWattmeter!(system14, device; label = "To 11", active = analysis.power.to.active[11], variance = 1e-2, noise = false)
    updateWattmeter!(system14, device; label = "To 19", active = analysis.power.to.active[19], noise = false)

    updatePmu!(system14, device; label = 2, statusAngle = 0)
    updatePmu!(system14, device; label = 6, statusAngle = 1)
    updatePmu!(system14, device; label = 9, angle = analysis.voltage.angle[9], varianceAngle = 1e-5, noise = false)
    updatePmu!(system14, device; label = 13, angle = analysis.voltage.angle[13], noise = false)

    ####### Solve Updated WLS and LAV Models #######
    analysisWLSUpdate = dcWlsStateEstimation(system14, device)
    solve!(system14, analysisWLSUpdate)
    @test analysisWLSUpdate.voltage.angle ≈ analysis.voltage.angle

    analysisLAVUpdate = dcLavStateEstimation(system14, device, Ipopt.Optimizer)
    JuMP.set_silent(analysisLAVUpdate.method.jump)
    solve!(system14, analysisLAVUpdate)
    @test analysisLAVUpdate.voltage.angle ≈ analysis.voltage.angle

    ##### Update Devices and Original WLS Model #######
    updateWattmeter!(system14, device, analysisWLS; label = 1, status = 0)
    updateWattmeter!(system14, device, analysisWLS; label = 3, status = 1)
    updateWattmeter!(system14, device, analysisWLS; label = 5, active = analysis.power.injection.active[5], variance = 1e-2, noise = false)
    updateWattmeter!(system14, device, analysisWLS; label = 9, active = analysis.power.injection.active[9], noise = false)

    updateWattmeter!(system14, device, analysisWLS; label = "From 4", status = 0)
    updateWattmeter!(system14, device, analysisWLS; label = "From 15", status = 1)
    updateWattmeter!(system14, device, analysisWLS; label = "From 17", active = analysis.power.from.active[17], variance = 1e-2, noise = false)
    updateWattmeter!(system14, device, analysisWLS; label = "From 20", active = analysis.power.from.active[20], noise = false)

    updateWattmeter!(system14, device, analysisWLS; label = "To 5", status = 0)
    updateWattmeter!(system14, device, analysisWLS; label = "To 8", status = 1)
    updateWattmeter!(system14, device, analysisWLS; label = "To 11", active = analysis.power.to.active[11], variance = 1e-2, noise = false)
    updateWattmeter!(system14, device, analysisWLS; label = "To 19", active = analysis.power.to.active[19], noise = false)

    updatePmu!(system14, device, analysisWLS; label = 2, statusAngle = 0)
    updatePmu!(system14, device, analysisWLS; label = 6, statusAngle = 1)
    updatePmu!(system14, device, analysisWLS; label = 9, angle = analysis.voltage.angle[9], varianceAngle = 1e-5, noise = false)
    updatePmu!(system14, device, analysisWLS; label = 13, angle = analysis.voltage.angle[13], noise = false)

    updateWattmeter!(system14, device, analysisWLS; label = 4, status = 0)
    updateWattmeter!(system14, device, analysisWLS; label = 4, status = 1)
    updateWattmeter!(system14, device, analysisWLS; label = "From 2", status = 0)
    updateWattmeter!(system14, device, analysisWLS; label = "From 2", status = 1)
    updateWattmeter!(system14, device, analysisWLS; label = "To 13", status = 0)
    updateWattmeter!(system14, device, analysisWLS; label = "To 13", status = 1)
    updatePmu!(system14, device, analysisWLS; label = 10, statusAngle = 0)
    updatePmu!(system14, device, analysisWLS; label = 10, statusAngle = 1)

    solve!(system14, analysisWLS)
    @test analysisWLS.voltage.angle ≈ analysis.voltage.angle

    #### Update Devices and Original LAV Model #######
    updateWattmeter!(system14, device, analysisLAV; label = 1, status = 0)
    updateWattmeter!(system14, device, analysisLAV; label = 3, status = 1)
    updateWattmeter!(system14, device, analysisLAV; label = 5, active = analysis.power.injection.active[5], variance = 1e-2, noise = false)
    updateWattmeter!(system14, device, analysisLAV; label = 9, active = analysis.power.injection.active[9], noise = false)

    updateWattmeter!(system14, device, analysisLAV; label = "From 4", status = 0)
    updateWattmeter!(system14, device, analysisLAV; label = "From 15", status = 1)
    updateWattmeter!(system14, device, analysisLAV; label = "From 17", active = analysis.power.from.active[17], variance = 1e-2, noise = false)
    updateWattmeter!(system14, device, analysisLAV; label = "From 20", active = analysis.power.from.active[20], noise = false)

    updateWattmeter!(system14, device, analysisLAV; label = "To 5", status = 0)
    updateWattmeter!(system14, device, analysisLAV; label = "To 8", status = 1)
    updateWattmeter!(system14, device, analysisLAV; label = "To 11", active = analysis.power.to.active[11], variance = 1e-2, noise = false)
    updateWattmeter!(system14, device, analysisLAV; label = "To 19", active = analysis.power.to.active[19], noise = false)

    updatePmu!(system14, device, analysisLAV; label = 2, statusAngle = 0)
    updatePmu!(system14, device, analysisLAV; label = 6, statusAngle = 1)
    updatePmu!(system14, device, analysisLAV; label = 9, angle = analysis.voltage.angle[9], varianceAngle = 1e-5, noise = false)
    updatePmu!(system14, device, analysisLAV; label = 13, angle = analysis.voltage.angle[13], noise = false)

    updateWattmeter!(system14, device, analysisLAV; label = 4, status = 0)
    updateWattmeter!(system14, device, analysisLAV; label = 4, status = 1)
    updateWattmeter!(system14, device, analysisLAV; label = "From 2", status = 0)
    updateWattmeter!(system14, device, analysisLAV; label = "From 2", status = 1)
    updateWattmeter!(system14, device, analysisLAV; label = "To 13", status = 0)
    updateWattmeter!(system14, device, analysisLAV; label = "To 13", status = 1)
    updatePmu!(system14, device, analysisLAV; label = 10, statusAngle = 0)
    updatePmu!(system14, device, analysisLAV; label = 10, statusAngle = 1)

    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system14, analysisLAV)
    @test analysisLAV.voltage.angle ≈ analysis.voltage.angle
end