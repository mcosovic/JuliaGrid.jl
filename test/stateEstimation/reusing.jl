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
    analysisWLS = dcStateEstimation(system14, device)
    analysisLAV = dcStateEstimation(system14, device, Ipopt.Optimizer)
 
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
    analysisWLSUpdate = dcStateEstimation(system14, device)
    solve!(system14, analysisWLSUpdate)
    @test analysisWLSUpdate.voltage.angle ≈ analysis.voltage.angle
 
    analysisLAVUpdate = dcStateEstimation(system14, device, Ipopt.Optimizer)
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
    updateWattmeter!(system14, device, analysisWLS; label = "To 12", status = 0)
    updateWattmeter!(system14, device, analysisWLS; label = "To 12", status = 1)
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
    updateWattmeter!(system14, device, analysisLAV; label = "To 12", status = 0)
    updateWattmeter!(system14, device, analysisLAV; label = "To 12", status = 1)
    updatePmu!(system14, device, analysisLAV; label = 10, statusAngle = 0)
    updatePmu!(system14, device, analysisLAV; label = 10, statusAngle = 1)
 
    JuMP.set_silent(analysisLAV.method.jump)
    solve!(system14, analysisLAV)
    @test analysisLAV.voltage.angle ≈ analysis.voltage.angle
end