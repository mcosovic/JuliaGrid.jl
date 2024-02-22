@testset "Build and Update Measurements in Per-Units" begin
    @default(template)
    @default(unit)

    system = powerSystem(string(pathData, "case14test.m"))
    device = measurement()
    deviceAll = measurement()
    
    analysis = newtonRaphson(system)
    for iteration = 1:100
        stopping = mismatch!(system, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system, analysis)
    end
    power!(system, analysis)
    current!(system, analysis)
    
    @voltmeter(label = "Voltmeter ?", variance = 1e-60)
    @ammeter(label = "Ammeter ?", varianceFrom = 1e-60, varianceTo = 1e-80, statusFrom = 0)
    @wattmeter(varianceBus = 1e-60, varianceFrom = 1e-60, varianceTo = 1e-60, statusBus = 0)
    @varmeter(varianceBus = 1e-60, varianceFrom = 1e-60, varianceTo = 1e-60, statusTo = 0)
    @pmu(label = "? PMU", varianceMagnitudeBus = 1e-60, varianceAngleBus = 1e-60, 
        varianceMagnitudeFrom = 1e-60, varianceAngleFrom = 1e-60, statusAngleFrom = 0,
        varianceMagnitudeTo = 1e-60, varianceAngleTo = 1e-60, statusMagnitudeBus = 0)
    
    ############### Measurements from AC Power Flow ################
    addVoltmeter!(system, deviceAll, analysis)
    addAmmeter!(system, deviceAll, analysis)
    addWattmeter!(system, deviceAll, analysis)
    addVarmeter!(system, deviceAll, analysis)
    addPmu!(system, deviceAll, analysis)
    
    ############### Bus Measurements ################
    for (key, value) in system.bus.label
        addVoltmeter!(system, device; bus = key, magnitude = analysis.voltage.magnitude[value])
        @test device.voltmeter.magnitude.mean[end] ≈ analysis.voltage.magnitude[value] atol = 1e-16
        @test device.voltmeter.magnitude.mean[end] ≈ deviceAll.voltmeter.magnitude.mean[value] atol = 1e-16
        @test device.voltmeter.magnitude.status[end] == 1
    
        addWattmeter!(system, device; bus = key, active = analysis.power.injection.active[value])
        @test device.wattmeter.active.mean[end] ≈ analysis.power.injection.active[value] atol = 1e-16
        @test device.wattmeter.active.mean[end] ≈ deviceAll.wattmeter.active.mean[value] atol = 1e-16
        @test device.wattmeter.active.status[end] == 0
    
        addVarmeter!(system, device; bus = key, reactive = analysis.power.injection.reactive[value])
        @test device.varmeter.reactive.mean[end] ≈ analysis.power.injection.reactive[value] atol = 1e-16
        @test device.varmeter.reactive.mean[end] ≈ deviceAll.varmeter.reactive.mean[value] atol = 1e-16
        @test device.varmeter.reactive.status[end] == 1
    
        addPmu!(system, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value])
        @test device.pmu.magnitude.mean[end] ≈ analysis.voltage.magnitude[value] atol = 1e-16
        @test device.pmu.magnitude.mean[end] ≈ deviceAll.pmu.magnitude.mean[value] atol = 1e-16
        @test device.pmu.angle.mean[end] ≈ analysis.voltage.angle[value] atol = 1e-16
        @test device.pmu.angle.mean[end] ≈ deviceAll.pmu.angle.mean[value] atol = 1e-16
        @test device.pmu.magnitude.status[end] == 0
        @test device.pmu.angle.status[end] == 1
    end
    
    ############### Branch Measurements ################
    currentMagnitudeFrom = deviceAll.ammeter.magnitude.mean[deviceAll.ammeter.layout.from]
    currentMagnitudeTo = deviceAll.ammeter.magnitude.mean[deviceAll.ammeter.layout.to]
    activeFrom = deviceAll.wattmeter.active.mean[deviceAll.wattmeter.layout.from]
    activeTo = deviceAll.wattmeter.active.mean[deviceAll.wattmeter.layout.to]
    reactiveFrom = deviceAll.varmeter.reactive.mean[deviceAll.varmeter.layout.from]
    reactiveTo = deviceAll.varmeter.reactive.mean[deviceAll.varmeter.layout.to]
    pmuMagnitudeFrom = deviceAll.pmu.magnitude.mean[deviceAll.pmu.layout.from]
    pmuAngleFrom = deviceAll.pmu.angle.mean[deviceAll.pmu.layout.from]
    pmuMagnitudeTo = deviceAll.pmu.magnitude.mean[deviceAll.pmu.layout.to]
    pmuAngleTo = deviceAll.pmu.angle.mean[deviceAll.pmu.layout.to]

    for (key, value) in system.branch.label
            addAmmeter!(system, device; from = key, magnitude = analysis.current.from.magnitude[value], noise = false)
            @test device.ammeter.magnitude.mean[end] == analysis.current.from.magnitude[value]
            @test device.ammeter.magnitude.mean[end] ≈ currentMagnitudeFrom[value] atol = 1e-16
            @test device.ammeter.magnitude.status[end] == 0
    
            addAmmeter!(system, device; to = key, magnitude = analysis.current.to.magnitude[value])
            @test device.ammeter.magnitude.mean[end] ≈ analysis.current.to.magnitude[value] atol = 1e-16
            @test device.ammeter.magnitude.mean[end] ≈ currentMagnitudeTo[value] atol = 1e-16
            @test device.ammeter.magnitude.status[end] == 1
    
            addWattmeter!(system, device; from = key, active = analysis.power.from.active[value])
            @test device.wattmeter.active.mean[end] ≈ analysis.power.from.active[value] atol = 1e-16
            @test device.wattmeter.active.mean[end] ≈ activeFrom[value] atol = 1e-16
            @test device.wattmeter.active.status[end] == 1
    
            addWattmeter!(system, device; from = key, active = analysis.power.to.active[value], noise = false)
            @test device.wattmeter.active.mean[end] == analysis.power.to.active[value]
            @test device.wattmeter.active.mean[end] ≈ activeTo[value] atol = 1e-16
            @test device.wattmeter.active.status[end] == 1
    
            addVarmeter!(system, device; from = key, reactive = analysis.power.from.reactive[value])
            @test device.varmeter.reactive.mean[end] ≈ analysis.power.from.reactive[value] atol = 1e-16
            @test device.varmeter.reactive.mean[end] ≈ reactiveFrom[value] atol = 1e-16
            @test device.varmeter.reactive.status[end] == 1
    
            addVarmeter!(system, device; to = key, reactive = analysis.power.to.reactive[value])
            @test device.varmeter.reactive.mean[end] ≈ analysis.power.to.reactive[value] atol = 1e-16
            @test device.varmeter.reactive.mean[end] ≈ reactiveTo[value] atol = 1e-16
            @test device.varmeter.reactive.status[end] == 0
    
            addPmu!(system, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value])
            @test device.pmu.magnitude.mean[end] ≈ analysis.current.from.magnitude[value] atol = 1e-16
            @test device.pmu.magnitude.mean[end] ≈ pmuMagnitudeFrom[value] atol = 1e-16
            @test device.pmu.angle.mean[end] ≈ analysis.current.from.angle[value] atol = 1e-16
            @test device.pmu.angle.mean[end] ≈ pmuAngleFrom[value] atol = 1e-16
            @test device.pmu.magnitude.status[end] == 1
    
            addPmu!(system, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value])
            @test device.pmu.magnitude.mean[end] ≈ analysis.current.to.magnitude[value] atol = 1e-16
            @test device.pmu.magnitude.mean[end] ≈ pmuMagnitudeTo[value] atol = 1e-16
            @test device.pmu.angle.mean[end] ≈ analysis.current.to.angle[value] atol = 1e-16
            @test device.pmu.angle.mean[end] ≈ pmuAngleTo[value] atol = 1e-16
            @test device.pmu.magnitude.status[end] == 1
    end
    
    ############### Update Voltmeter ################
    updateVoltmeter!(system, device; label = "Voltmeter 3", magnitude = 0.2, variance = 1e-6, status = 0, noise = false)
    @test device.voltmeter.magnitude.mean[3] == 0.2
    @test device.voltmeter.magnitude.variance[3] == 1e-6
    @test device.voltmeter.magnitude.status[3] == 0

    updateVoltmeter!(system, device; label = "Voltmeter 5", magnitude = 0.3, variance = 1e-10, status = 1)
    @test device.voltmeter.magnitude.mean[5] ≈ 0.3 atol = 1e-2
    @test device.voltmeter.magnitude.mean[5] != 0.3
    @test device.voltmeter.magnitude.variance[5] == 1e-10
    @test device.voltmeter.magnitude.status[5] == 1

    ############### Update Ammeter ################
    updateAmmeter!(system, device; label = "Ammeter 3", magnitude = 0.4, variance = 1e-8, status = 0, noise = false)
    @test device.ammeter.magnitude.mean[3] == 0.4
    @test device.ammeter.magnitude.variance[3] == 1e-8
    @test device.ammeter.magnitude.status[3] == 0

    updateAmmeter!(system, device; label = "Ammeter 8", magnitude = 0.6, variance = 1e-10, status = 1)
    @test device.ammeter.magnitude.mean[8] ≈ 0.6 atol = 1e-2
    @test device.ammeter.magnitude.mean[8] != 0.6
    @test device.ammeter.magnitude.variance[8] == 1e-10
    @test device.ammeter.magnitude.status[8] == 1

    ############### Update Wattmeter ################
    updateWattmeter!(system, device; label = "4", active = 0.5, variance = 1e-2, status = 0, noise = false)
    @test device.wattmeter.active.mean[4] == 0.5
    @test device.wattmeter.active.variance[4] == 1e-2
    @test device.wattmeter.active.status[4] == 0

    updateWattmeter!(system, device; label = "14", active = 0.1, variance = 1e-10, status = 1)
    @test device.wattmeter.active.mean[14] ≈ 0.1 atol = 1e-2
    @test device.wattmeter.active.mean[14] != 0.1
    @test device.wattmeter.active.variance[14] == 1e-10
    @test device.wattmeter.active.status[14] == 1

    ############### Update Varmeter ################
    updateVarmeter!(system, device; label = "5", reactive = 1.5, variance = 1e-1, status = 0, noise = false)
    @test device.varmeter.reactive.mean[5] == 1.5
    @test device.varmeter.reactive.variance[5] == 1e-1
    @test device.varmeter.reactive.status[5] == 0

    updateVarmeter!(system, device; label = "16", reactive = 0.9, variance = 1e-10, status = 1)
    @test device.varmeter.reactive.mean[16] ≈ 0.9 atol = 1e-2
    @test device.varmeter.reactive.mean[16] != 0.9
    @test device.varmeter.reactive.variance[16] == 1e-10
    @test device.varmeter.reactive.status[16] == 1

    ############### Update PMU ################
    updatePmu!(system, device; label = "4 PMU", magnitude = 0.1, angle = 0.2, varianceMagnitude = 1e-6, varianceAngle = 1e-7, 
    statusMagnitude = 0, statusAngle = 1, noise = false)
    @test device.pmu.magnitude.mean[4] == 0.1
    @test device.pmu.magnitude.variance[4] == 1e-6
    @test device.pmu.magnitude.status[4] == 0
    @test device.pmu.angle.mean[4] == 0.2
    @test device.pmu.angle.variance[4] == 1e-7
    @test device.pmu.angle.status[4] == 1

    updatePmu!(system, device; label = "5 PMU", magnitude = 0.3, angle = 0.4, varianceMagnitude = 1e-10, varianceAngle = 1e-11, 
    statusMagnitude = 1, statusAngle = 0)
    @test device.pmu.magnitude.mean[5] ≈ 0.3 atol = 1e-2
    @test device.pmu.magnitude.mean[5] != 0.3
    @test device.pmu.magnitude.variance[5] == 1e-10
    @test device.pmu.magnitude.status[5] == 1
    @test device.pmu.angle.mean[5] ≈ 0.4 atol = 1e-2
    @test device.pmu.magnitude.mean[5] != 0.4
    @test device.pmu.angle.variance[5] == 1e-11
    @test device.pmu.angle.status[5] == 0
end

@testset "Build and Update Measurements in SI Units" begin
    @default(template)
    @default(unit)

    @power(kW, MVAr, GVA)
    @voltage(kV, deg, MV)
    @current(A, rad)

    system = powerSystem()
    device = measurement()
    @base(system, MVA, kV)
    
    @bus(base = 0.23)
    @branch(reactance = 0.02)
    addBus!(system; label = 1, active = 20.5, reactive = 11.2, magnitude = 126.5)
    addBus!(system; label = 2, magnitude = 95, angle = 2.4)
    addBranch!(system; label = 1, from = 1, to = 2)
    baseCurrent = system.base.power.value * system.base.power.prefix / (sqrt(3) * 0.23 * 10^6)
    
    ####### Voltmeter Data #######
    addVoltmeter!(system, device; bus = 1, magnitude = 126.5, variance = 126.5, noise = false)
    addVoltmeter!(system, device; bus = 1, magnitude = 126.5, variance = 1e-60, noise = true)
    @test device.voltmeter.magnitude.mean[1] == system.bus.voltage.magnitude[1]
    @test device.voltmeter.magnitude.variance[1] == system.bus.voltage.magnitude[1]
    @test device.voltmeter.magnitude.mean[2] == system.bus.voltage.magnitude[1]
    
    ####### Ammeter Data #######
    addAmmeter!(system, device; from = 1, magnitude = 102.5, variance = 102.5, noise = false)
    addAmmeter!(system, device; from = 1, magnitude = 102.5, variance = 1e-60, noise = true)
    @test device.ammeter.magnitude.mean[1] ≈ (102.5 / baseCurrent) atol = 1e-15
    @test device.ammeter.magnitude.variance[1] ≈ (102.5 / baseCurrent) atol = 1e-15
    @test device.ammeter.magnitude.mean[2] ≈ (102.5 / baseCurrent) atol = 1e-15
    
    addAmmeter!(system, device; to = 1, magnitude = 20, variance = 20, noise = false)
    addAmmeter!(system, device; to = 1, magnitude = 20, variance = 1e-60, noise = true)
    @test device.ammeter.magnitude.mean[3] ≈ (20 / baseCurrent) atol = 1e-15
    @test device.ammeter.magnitude.variance[3] ≈ (20 / baseCurrent) atol = 1e-15
    @test device.ammeter.magnitude.mean[4] ≈ (20 / baseCurrent) atol = 1e-15
    
    ####### Wattmeter Data #######
    addWattmeter!(system, device; bus = 1, active = 20.5, variance = 20.5, noise = false)
    addWattmeter!(system, device; bus = 1, active = 20.5, variance = 1e-60, noise = true)
    @test device.wattmeter.active.mean[1] == system.bus.demand.active[1]
    @test device.wattmeter.active.variance[1] == system.bus.demand.active[1]
    @test device.wattmeter.active.mean[2] == system.bus.demand.active[1]
    
    addWattmeter!(system, device; from = 1, active = 20.5, variance = 20.5, noise = false)
    addWattmeter!(system, device; from = 1, active = 20.5, variance = 1e-60, noise = true)
    @test device.wattmeter.active.mean[3] == system.bus.demand.active[1]
    @test device.wattmeter.active.variance[3] == system.bus.demand.active[1]
    @test device.wattmeter.active.mean[4] == system.bus.demand.active[1]
    
    addWattmeter!(system, device; to = 1, active = 20.5, variance = 20.5, noise = false)
    addWattmeter!(system, device; to = 1, active = 20.5, variance = 1e-60, noise = true)
    @test device.wattmeter.active.mean[5] == system.bus.demand.active[1]
    @test device.wattmeter.active.variance[5] == system.bus.demand.active[1]
    @test device.wattmeter.active.mean[6] == system.bus.demand.active[1]
    
    ####### Varmeter Data #######
    addVarmeter!(system, device; bus = 1, reactive = 11.2, variance = 11.2, noise = false)
    addVarmeter!(system, device; bus = 1, reactive = 11.2, variance = 1e-60, noise = true)
    @test device.varmeter.reactive.mean[1] == system.bus.demand.reactive[1]
    @test device.varmeter.reactive.variance[1] == system.bus.demand.reactive[1]
    @test device.varmeter.reactive.mean[2] == system.bus.demand.reactive[1]
    
    addVarmeter!(system, device; from = 1, reactive = 11.2, variance = 11.2, noise = false)
    addVarmeter!(system, device; from = 1,reactive = 11.2, variance = 1e-60,  noise = true)
    @test device.varmeter.reactive.mean[3] == system.bus.demand.reactive[1]
    @test device.varmeter.reactive.variance[3] == system.bus.demand.reactive[1]
    @test device.varmeter.reactive.mean[4] == system.bus.demand.reactive[1]
    
    addVarmeter!(system, device; to = 1, reactive = 11.2, variance = 11.2, noise = false)
    addVarmeter!(system, device; to = 1, reactive = 11.2, variance = 1e-60, noise = true)
    @test device.varmeter.reactive.mean[5] == system.bus.demand.reactive[1]
    @test device.varmeter.reactive.variance[5] == system.bus.demand.reactive[1]
    @test device.varmeter.reactive.mean[6] == system.bus.demand.reactive[1]
    
    ####### PMU Data #######
    addPmu!(system, device; bus = 2, magnitude = 95, angle = 2.4, varianceMagnitude = 95, varianceAngle = 2.4, noise = false)
    addPmu!(system, device; bus = 2, magnitude = 95, angle = 2.4, varianceMagnitude = 1e-60, varianceAngle = 1e-60, noise = true)
    @test device.pmu.magnitude.mean[1] == system.bus.voltage.magnitude[2]
    @test device.pmu.magnitude.variance[1] == system.bus.voltage.magnitude[2]
    @test device.pmu.magnitude.mean[2] == system.bus.voltage.magnitude[2]
    @test device.pmu.angle.mean[1] == system.bus.voltage.angle[2]
    @test device.pmu.angle.variance[1] == system.bus.voltage.angle[2]
    @test device.pmu.angle.mean[2] == system.bus.voltage.angle[2]
    
    addPmu!(system, device; from = 1, magnitude = 40, angle = 0.1, varianceMagnitude = 40, varianceAngle = 0.1, noise = false)
    addPmu!(system, device; from = 1, magnitude = 40, angle = 0.1, varianceMagnitude = 1e-60, varianceAngle = 1e-60, noise = true)
    @test device.pmu.magnitude.mean[3] ≈ (40 / baseCurrent) atol = 1e-15
    @test device.pmu.magnitude.variance[3] ≈ (40 / baseCurrent) atol = 1e-15
    @test device.pmu.magnitude.mean[4] ≈ (40 / baseCurrent) atol = 1e-15
    @test device.pmu.angle.mean[3] == 0.1
    @test device.pmu.angle.variance[3] == 0.1
    @test device.pmu.angle.mean[4] == 0.1
    
    addPmu!(system, device; to = 1, magnitude = 60, angle = 3, varianceMagnitude = 60, varianceAngle = 3, noise = false)
    addPmu!(system, device; to = 1, magnitude = 60, angle = 3, varianceMagnitude = 1e-60, varianceAngle = 1e-60, noise = true)
    @test device.pmu.magnitude.mean[5] ≈ (60 / baseCurrent) atol = 1e-15
    @test device.pmu.magnitude.variance[5] ≈ (60 / baseCurrent) atol = 1e-15
    @test device.pmu.magnitude.mean[6] ≈ (60 / baseCurrent) atol = 1e-15
    @test device.pmu.angle.mean[5] == 3
    @test device.pmu.angle.variance[5] == 3
    @test device.pmu.angle.mean[6] == 3
end

@testset "Measurement Set" begin
    system = powerSystem(string(pathData, "case14test.m"))
    device = measurement()
    
    analysis = newtonRaphson(system)
    for iteration = 1:100
        stopping = mismatch!(system, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system, analysis)
    end
    power!(system, analysis)
    current!(system, analysis)
    
    stateVariable = 2 * system.bus.number - 1

    ############### Voltmeter Set ################
    addVoltmeter!(system, device, analysis)
    
    statusVoltmeter!(system, device; inservice = 10)
    @test sum(device.voltmeter.magnitude.status) == 10
    
    statusVoltmeter!(system, device; outservice = 5)
    @test sum(device.voltmeter.magnitude.status) == 9
    
    statusVoltmeter!(system, device; redundancy = 0.5)
    @test sum(device.voltmeter.magnitude.status) == round(0.5 * stateVariable)
    
    ############### Ammeter Set ################
    addAmmeter!(system, device, analysis)
    
    statusAmmeter!(system, device; inservice = 18)
    @test sum(device.ammeter.magnitude.status) == 18
    
    statusAmmeter!(system, device; outservice = 4)
    @test sum(device.ammeter.magnitude.status) == 36
    
    statusAmmeter!(system, device; redundancy = 1.1)
    @test sum(device.ammeter.magnitude.status) == round(1.1 * stateVariable)
    
    layout = device.ammeter.layout
    statusAmmeter!(system, device; inserviceFrom = 10, inserviceTo = 4)
    @test sum(device.ammeter.magnitude.status[layout.from]) == 10
    @test sum(device.ammeter.magnitude.status[layout.to]) == 4
    
    statusAmmeter!(system, device; outserviceFrom = 5, outserviceTo = 3)
    @test sum(device.ammeter.magnitude.status[layout.from]) == 15
    @test sum(device.ammeter.magnitude.status[layout.to]) == 17
    
    statusAmmeter!(system, device; redundancyFrom = 0.5, redundancyTo = 0.2)
    @test sum(device.ammeter.magnitude.status[layout.from]) == round(0.5 * stateVariable)
    @test sum(device.ammeter.magnitude.status[layout.to]) == round(0.2 * stateVariable)
    
    ############### Wattmeter Set ################
    addWattmeter!(system, device, analysis)
    
    statusWattmeter!(system, device; inservice = 14)
    @test sum(device.wattmeter.active.status) == 14
    
    statusWattmeter!(system, device; outservice = 40)
    @test sum(device.wattmeter.active.status) == 14
    
    statusWattmeter!(system, device; redundancy = 1.8)
    @test sum(device.wattmeter.active.status) == round(1.8 * stateVariable)
    
    layout = device.wattmeter.layout
    statusWattmeter!(system, device; inserviceBus = 10, inserviceFrom = 12, inserviceTo = 8)
    @test sum(device.wattmeter.active.status[layout.bus]) == 10
    @test sum(device.wattmeter.active.status[layout.from]) == 12
    @test sum(device.wattmeter.active.status[layout.to]) == 8
    
    statusWattmeter!(system, device; outserviceBus = 14, outserviceFrom = 15, outserviceTo = 17)
    @test sum(device.wattmeter.active.status[layout.bus]) == 0
    @test sum(device.wattmeter.active.status[layout.from]) == 5
    @test sum(device.wattmeter.active.status[layout.to]) == 3
    
    statusWattmeter!(system, device; redundancyBus = 0.1, redundancyFrom = 0.3, redundancyTo = 0.4)
    @test sum(device.wattmeter.active.status[layout.bus]) == round(0.1 * stateVariable)
    @test sum(device.wattmeter.active.status[layout.from]) == round(0.3 * stateVariable)
    @test sum(device.wattmeter.active.status[layout.to]) == round(0.4 * stateVariable)
    
    ############### Varmeter Set ################
    addVarmeter!(system, device, analysis)
    
    statusVarmeter!(system, device; inservice = 1)
    @test sum(device.varmeter.reactive.status) == 1
    
    statusVarmeter!(system, device; outservice = 30)
    @test sum(device.varmeter.reactive.status) == 24
    
    statusVarmeter!(system, device; redundancy = 1.2)
    @test sum(device.varmeter.reactive.status) == round(1.2 * stateVariable)
    
    layout = device.varmeter.layout
    statusVarmeter!(system, device; inserviceBus = 0, inserviceFrom = 18, inserviceTo = 4)
    @test sum(device.varmeter.reactive.status[layout.bus]) == 0
    @test sum(device.varmeter.reactive.status[layout.from]) == 18
    @test sum(device.varmeter.reactive.status[layout.to]) == 4
    
    statusVarmeter!(system, device; outserviceBus = 0, outserviceFrom = 10, outserviceTo = 2)
    @test sum(device.varmeter.reactive.status[layout.bus]) == 14
    @test sum(device.varmeter.reactive.status[layout.from]) == 10
    @test sum(device.varmeter.reactive.status[layout.to]) == 18
    
    statusVarmeter!(system, device; redundancyBus = 0.2, redundancyFrom = 0.1, redundancyTo = 0.3)
    @test sum(device.varmeter.reactive.status[layout.bus]) == round(0.2 * stateVariable)
    @test sum(device.varmeter.reactive.status[layout.from]) == round(0.1 * stateVariable)
    @test sum(device.varmeter.reactive.status[layout.to]) == round(0.3 * stateVariable)
    
    ############### PMU Set ################
    addPmu!(system, device, analysis)
    
    statusPmu!(system, device; inservice = 10)
    @test device.pmu.magnitude.status == device.pmu.angle.status
    @test sum(device.pmu.magnitude.status) == 10
    
    statusPmu!(system, device; outservice = 40)
    @test device.pmu.magnitude.status == device.pmu.angle.status
    @test sum(device.pmu.magnitude.status) == 14
    
    statusPmu!(system, device; redundancy = 0.2)
    @test device.pmu.magnitude.status == device.pmu.angle.status
    @test sum(device.pmu.magnitude.status) == round(0.2 * stateVariable)
    
    layout = device.pmu.layout
    statusPmu!(system, device; inserviceBus = 10, inserviceFrom = 15, inserviceTo = 16)
    @test device.pmu.magnitude.status == device.pmu.angle.status
    @test sum(device.pmu.magnitude.status[layout.bus]) == 10
    @test sum(device.pmu.magnitude.status[layout.from]) == 15
    @test sum(device.pmu.magnitude.status[layout.to]) == 16
    
    statusPmu!(system, device; outserviceBus = 6, outserviceFrom = 10, outserviceTo = 15)
    @test device.pmu.magnitude.status == device.pmu.angle.status
    @test sum(device.pmu.magnitude.status[layout.bus]) == 8
    @test sum(device.pmu.magnitude.status[layout.from]) == 10
    @test sum(device.pmu.magnitude.status[layout.to]) == 5
    
    statusPmu!(system, device; redundancyBus = 0.3, redundancyFrom = 0.2, redundancyTo = 0.4)
    @test device.pmu.magnitude.status == device.pmu.angle.status
    @test sum(device.pmu.magnitude.status[layout.bus]) == round(0.3 * stateVariable)
    @test sum(device.pmu.magnitude.status[layout.from]) == round(0.2 * stateVariable)
    @test sum(device.pmu.magnitude.status[layout.to]) == round(0.4 * stateVariable)
    
    ############### Measurement Set ################
    status!(system, device; inservice = 40)
    @test device.pmu.magnitude.status == device.pmu.angle.status
    @test sum(device.voltmeter.magnitude.status) + sum(device.ammeter.magnitude.status) +
    sum(device.wattmeter.active.status) + sum(device.varmeter.reactive.status) + 
    sum(device.pmu.magnitude.status) == 40
    
    status!(system, device; outservice = 100)    
    @test device.pmu.magnitude.status == device.pmu.angle.status
    @test sum(device.voltmeter.magnitude.status) + sum(device.ammeter.magnitude.status) +
    sum(device.wattmeter.active.status) + sum(device.varmeter.reactive.status) + 
    sum(device.pmu.magnitude.status) == 116    
    
    status!(system, device; redundancy = 3.1)
    @test device.pmu.magnitude.status == device.pmu.angle.status
    @test sum(device.voltmeter.magnitude.status) + sum(device.ammeter.magnitude.status) +
    sum(device.wattmeter.active.status) + sum(device.varmeter.reactive.status) + 
    sum(device.pmu.magnitude.status) == round(3.1 * stateVariable)    
end