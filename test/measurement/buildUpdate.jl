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
    
    addVoltmeter!(system, deviceAll, analysis)
    addAmmeter!(system, deviceAll, analysis)
    addWattmeter!(system, deviceAll, analysis)
    addVarmeter!(system, deviceAll, analysis)
    addPmu!(system, deviceAll, analysis)
    
    for (key, value) in system.bus.label
        addVoltmeter!(system, device; bus = key, magnitude = analysis.voltage.magnitude[value])
        @test device.voltmeter.magnitude.mean[end] ≈ analysis.voltage.magnitude[value] atol = 1e-16
        @test device.voltmeter.magnitude.mean[end] ≈ deviceAll.voltmeter.magnitude.mean[value] atol = 1e-16
        @test device.voltmeter.magnitude.status[end] == 1
    
        addWattmeter!(system, device; bus = key, active = analysis.power.injection.active[value])
        @test device.wattmeter.power.mean[end] ≈ analysis.power.injection.active[value] atol = 1e-16
        @test device.wattmeter.power.mean[end] ≈ deviceAll.wattmeter.power.mean[value] atol = 1e-16
        @test device.wattmeter.power.status[end] == 0
    
        addVarmeter!(system, device; bus = key, reactive = analysis.power.injection.reactive[value])
        @test device.varmeter.power.mean[end] ≈ analysis.power.injection.reactive[value] atol = 1e-16
        @test device.varmeter.power.mean[end] ≈ deviceAll.varmeter.power.mean[value] atol = 1e-16
        @test device.varmeter.power.status[end] == 1
    
        addPmu!(system, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value])
        @test device.pmu.magnitude.mean[end] ≈ analysis.voltage.magnitude[value] atol = 1e-16
        @test device.pmu.magnitude.mean[end] ≈ deviceAll.pmu.magnitude.mean[value] atol = 1e-16
        @test device.pmu.angle.mean[end] ≈ analysis.voltage.angle[value] atol = 1e-16
        @test device.pmu.angle.mean[end] ≈ deviceAll.pmu.angle.mean[value] atol = 1e-16
        @test device.pmu.magnitude.status[end] == 0
        @test device.pmu.angle.status[end] == 1
    end
    
    currentMagnitudeFrom = deviceAll.ammeter.magnitude.mean[deviceAll.ammeter.layout.from]
    currentMagnitudeTo = deviceAll.ammeter.magnitude.mean[deviceAll.ammeter.layout.to]
    activeFrom = deviceAll.wattmeter.power.mean[deviceAll.wattmeter.layout.from]
    activeTo = deviceAll.wattmeter.power.mean[deviceAll.wattmeter.layout.to]
    reactiveFrom = deviceAll.varmeter.power.mean[deviceAll.varmeter.layout.from]
    reactiveTo = deviceAll.varmeter.power.mean[deviceAll.varmeter.layout.to]
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
        @test device.wattmeter.power.mean[end] ≈ analysis.power.from.active[value] atol = 1e-16
        @test device.wattmeter.power.mean[end] ≈ activeFrom[value] atol = 1e-16
        @test device.wattmeter.power.status[end] == 1
    
        addWattmeter!(system, device; from = key, active = analysis.power.to.active[value], noise = false)
        @test device.wattmeter.power.mean[end] == analysis.power.to.active[value]
        @test device.wattmeter.power.mean[end] ≈ activeTo[value] atol = 1e-16
        @test device.wattmeter.power.status[end] == 1
    
        addVarmeter!(system, device; from = key, reactive = analysis.power.from.reactive[value])
        @test device.varmeter.power.mean[end] ≈ analysis.power.from.reactive[value] atol = 1e-16
        @test device.varmeter.power.mean[end] ≈ reactiveFrom[value] atol = 1e-16
        @test device.varmeter.power.status[end] == 1
    
        addVarmeter!(system, device; to = key, reactive = analysis.power.to.reactive[value])
        @test device.varmeter.power.mean[end] ≈ analysis.power.to.reactive[value] atol = 1e-16
        @test device.varmeter.power.mean[end] ≈ reactiveTo[value] atol = 1e-16
        @test device.varmeter.power.status[end] == 0
    
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
    @test device.wattmeter.power.mean[1] == system.bus.demand.active[1]
    @test device.wattmeter.power.variance[1] == system.bus.demand.active[1]
    @test device.wattmeter.power.mean[2] == system.bus.demand.active[1]
    
    addWattmeter!(system, device; from = 1, active = 20.5, variance = 20.5, noise = false)
    addWattmeter!(system, device; from = 1, active = 20.5, variance = 1e-60, noise = true)
    @test device.wattmeter.power.mean[3] == system.bus.demand.active[1]
    @test device.wattmeter.power.variance[3] == system.bus.demand.active[1]
    @test device.wattmeter.power.mean[4] == system.bus.demand.active[1]
    
    addWattmeter!(system, device; to = 1, active = 20.5, variance = 20.5, noise = false)
    addWattmeter!(system, device; to = 1, active = 20.5, variance = 1e-60, noise = true)
    @test device.wattmeter.power.mean[5] == system.bus.demand.active[1]
    @test device.wattmeter.power.variance[5] == system.bus.demand.active[1]
    @test device.wattmeter.power.mean[6] == system.bus.demand.active[1]
    
    ####### Varmeter Data #######
    addVarmeter!(system, device; bus = 1, reactive = 11.2, variance = 11.2, noise = false)
    addVarmeter!(system, device; bus = 1, reactive = 11.2, variance = 1e-60, noise = true)
    @test device.varmeter.power.mean[1] == system.bus.demand.reactive[1]
    @test device.varmeter.power.variance[1] == system.bus.demand.reactive[1]
    @test device.varmeter.power.mean[2] == system.bus.demand.reactive[1]
    
    addVarmeter!(system, device; from = 1, reactive = 11.2, variance = 11.2, noise = false)
    addVarmeter!(system, device; from = 1,reactive = 11.2, variance = 1e-60,  noise = true)
    @test device.varmeter.power.mean[3] == system.bus.demand.reactive[1]
    @test device.varmeter.power.variance[3] == system.bus.demand.reactive[1]
    @test device.varmeter.power.mean[4] == system.bus.demand.reactive[1]
    
    addVarmeter!(system, device; to = 1, reactive = 11.2, variance = 11.2, noise = false)
    addVarmeter!(system, device; to = 1, reactive = 11.2, variance = 1e-60, noise = true)
    @test device.varmeter.power.mean[5] == system.bus.demand.reactive[1]
    @test device.varmeter.power.variance[5] == system.bus.demand.reactive[1]
    @test device.varmeter.power.mean[6] == system.bus.demand.reactive[1]
    
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