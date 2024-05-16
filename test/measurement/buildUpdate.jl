@testset "Build and Update Measurement Data in Per-Units" begin
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
    @ammeter(label = "Ammeter ?", varianceFrom = 1e-2, varianceTo = 1e-3, statusFrom = 0)
    @wattmeter(varianceBus = 1e-3, varianceFrom = 1e-2, varianceTo = 1e-4, statusBus = 0)
    @varmeter(varianceBus = 1e-2, varianceFrom = 1e-2, varianceTo = 1e-1, statusTo = 0)
    @pmu(label = "? PMU", varianceMagnitudeBus = 1e-3, varianceAngleBus = 1e-5,
    varianceMagnitudeFrom = 1e-5, varianceAngleFrom = 1e-6, statusAngleFrom = 0,
    varianceMagnitudeTo = 1e-2, varianceAngleTo = 1e-3, statusMagnitudeBus = 0)

    ############### Generate Measurement Data from AC Power Flow ###############
    addVoltmeter!(system, deviceAll, analysis; noise = true)
    addAmmeter!(system, deviceAll, analysis)
    addWattmeter!(system, deviceAll, analysis)
    addVarmeter!(system, deviceAll, analysis)
    addPmu!(system, deviceAll, analysis)

    ####### Test Bus Measurements #######
    for (key, value) in system.bus.label
        addVoltmeter!(system, device; bus = key, magnitude = analysis.voltage.magnitude[value])
        @test device.voltmeter.magnitude.mean[end] ≈ analysis.voltage.magnitude[value] atol = 1e-16
        @test device.voltmeter.magnitude.mean[end] ≈ deviceAll.voltmeter.magnitude.mean[value] atol = 1e-16
        @test device.voltmeter.magnitude.status[end] == 1

        addWattmeter!(system, device; bus = key, active = analysis.power.injection.active[value])
        @test device.wattmeter.active.mean[end] == analysis.power.injection.active[value]
        @test device.wattmeter.active.mean[end] == deviceAll.wattmeter.active.mean[value]
        @test device.wattmeter.active.status[end] == 0

        addVarmeter!(system, device; bus = key, reactive = analysis.power.injection.reactive[value])
        @test device.varmeter.reactive.mean[end] == analysis.power.injection.reactive[value]
        @test device.varmeter.reactive.mean[end] == deviceAll.varmeter.reactive.mean[value]
        @test device.varmeter.reactive.status[end] == 1

        addPmu!(system, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value])
        @test device.pmu.magnitude.mean[end] == analysis.voltage.magnitude[value]
        @test device.pmu.magnitude.mean[end] == deviceAll.pmu.magnitude.mean[value]
        @test device.pmu.angle.mean[end] == analysis.voltage.angle[value]
        @test device.pmu.angle.mean[end] == deviceAll.pmu.angle.mean[value]
        @test device.pmu.magnitude.status[end] == 0
        @test device.pmu.angle.status[end] == 1
    end

    ####### Test Branch Measurements #######
    cnt = 1
    for (key, value) in system.branch.label
        if system.branch.layout.status[value] == 1
            addAmmeter!(system, device; from = key, magnitude = analysis.current.from.magnitude[value])
            @test device.ammeter.magnitude.mean[end] == analysis.current.from.magnitude[value]
            @test device.ammeter.magnitude.mean[end] == deviceAll.ammeter.magnitude.mean[cnt]
            @test device.ammeter.magnitude.status[end] == 0

            addAmmeter!(system, device; to = key, magnitude = analysis.current.to.magnitude[value])
            @test device.ammeter.magnitude.mean[end] == analysis.current.to.magnitude[value]
            @test device.ammeter.magnitude.mean[end] == deviceAll.ammeter.magnitude.mean[cnt + 1]
            @test device.ammeter.magnitude.status[end] == 1

            addWattmeter!(system, device; from = key, active = analysis.power.from.active[value])
            @test device.wattmeter.active.mean[end] == analysis.power.from.active[value]
            @test device.wattmeter.active.mean[end] == deviceAll.wattmeter.active.mean[system.bus.number + cnt]
            @test device.wattmeter.active.status[end] == 1

            addWattmeter!(system, device; from = key, active = analysis.power.to.active[value])
            @test device.wattmeter.active.mean[end] == analysis.power.to.active[value]
            @test device.wattmeter.active.mean[end] == deviceAll.wattmeter.active.mean[system.bus.number + cnt + 1]
            @test device.wattmeter.active.status[end] == 1

            addVarmeter!(system, device; from = key, reactive = analysis.power.from.reactive[value])
            @test device.varmeter.reactive.mean[end] == analysis.power.from.reactive[value]
            @test device.varmeter.reactive.mean[end] == deviceAll.varmeter.reactive.mean[system.bus.number + cnt]
            @test device.varmeter.reactive.status[end] == 1

            addVarmeter!(system, device; to = key, reactive = analysis.power.to.reactive[value])
            @test device.varmeter.reactive.mean[end] == analysis.power.to.reactive[value]
            @test device.varmeter.reactive.mean[end] == deviceAll.varmeter.reactive.mean[system.bus.number + cnt + 1]
            @test device.varmeter.reactive.status[end] == 0

            addPmu!(system, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value])
            @test device.pmu.magnitude.mean[end] == analysis.current.from.magnitude[value]
            @test device.pmu.magnitude.mean[end] == deviceAll.pmu.magnitude.mean[system.bus.number + cnt]
            @test device.pmu.angle.mean[end] == analysis.current.from.angle[value]
            @test device.pmu.angle.mean[end] == deviceAll.pmu.angle.mean[system.bus.number + cnt]
            @test device.pmu.magnitude.status[end] == 1

            addPmu!(system, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value])
            @test device.pmu.magnitude.mean[end] == analysis.current.to.magnitude[value]
            @test device.pmu.magnitude.mean[end] == deviceAll.pmu.magnitude.mean[system.bus.number + cnt + 1]
            @test device.pmu.angle.mean[end] == analysis.current.to.angle[value]
            @test device.pmu.angle.mean[end] == deviceAll.pmu.angle.mean[system.bus.number + cnt + 1]
            @test device.pmu.magnitude.status[end] == 1

            cnt += 2
        end
    end

    ####### Test Update Voltmeter #######
    updateVoltmeter!(system, device; label = "Voltmeter 3", magnitude = 0.2, variance = 1e-6, status = 0)
    @test device.voltmeter.magnitude.mean[3] == 0.2
    @test device.voltmeter.magnitude.variance[3] == 1e-6
    @test device.voltmeter.magnitude.status[3] == 0

    updateVoltmeter!(system, device; label = "Voltmeter 5", magnitude = 0.3, variance = 1e-10, status = 1, noise = true)
    @test device.voltmeter.magnitude.mean[5] ≈ 0.3 atol = 1e-2
    @test device.voltmeter.magnitude.mean[5] != 0.3
    @test device.voltmeter.magnitude.variance[5] == 1e-10
    @test device.voltmeter.magnitude.status[5] == 1

    ####### Test Update Ammeter #######
    updateAmmeter!(system, device; label = "Ammeter 3", magnitude = 0.4, variance = 1e-8, status = 0)
    @test device.ammeter.magnitude.mean[3] == 0.4
    @test device.ammeter.magnitude.variance[3] == 1e-8
    @test device.ammeter.magnitude.status[3] == 0

    updateAmmeter!(system, device; label = "Ammeter 8", magnitude = 0.6, variance = 1e-10, status = 1, noise = true)
    @test device.ammeter.magnitude.mean[8] ≈ 0.6 atol = 1e-2
    @test device.ammeter.magnitude.mean[8] != 0.6
    @test device.ammeter.magnitude.variance[8] == 1e-10
    @test device.ammeter.magnitude.status[8] == 1

    ####### Test Update Wattmeter #######
    updateWattmeter!(system, device; label = "4", active = 0.5, variance = 1e-2, status = 0)
    @test device.wattmeter.active.mean[4] == 0.5
    @test device.wattmeter.active.variance[4] == 1e-2
    @test device.wattmeter.active.status[4] == 0

    updateWattmeter!(system, device; label = "14", active = 0.1, variance = 1e-10, status = 1, noise = true)
    @test device.wattmeter.active.mean[14] ≈ 0.1 atol = 1e-2
    @test device.wattmeter.active.mean[14] != 0.1
    @test device.wattmeter.active.variance[14] == 1e-10
    @test device.wattmeter.active.status[14] == 1

    ####### Test Update Varmeter #######
    updateVarmeter!(system, device; label = "5", reactive = 1.5, variance = 1e-1, status = 0)
    @test device.varmeter.reactive.mean[5] == 1.5
    @test device.varmeter.reactive.variance[5] == 1e-1
    @test device.varmeter.reactive.status[5] == 0

    updateVarmeter!(system, device; label = "16", reactive = 0.9, variance = 1e-10, status = 1, noise = true)
    @test device.varmeter.reactive.mean[16] ≈ 0.9 atol = 1e-2
    @test device.varmeter.reactive.mean[16] != 0.9
    @test device.varmeter.reactive.variance[16] == 1e-10
    @test device.varmeter.reactive.status[16] == 1

    ####### Test Update PMU #######
    updatePmu!(system, device; label = "4 PMU", magnitude = 0.1, angle = 0.2, varianceMagnitude = 1e-6, varianceAngle = 1e-7, statusMagnitude = 0, statusAngle = 1)
    @test device.pmu.magnitude.mean[4] == 0.1
    @test device.pmu.magnitude.variance[4] == 1e-6
    @test device.pmu.magnitude.status[4] == 0
    @test device.pmu.angle.mean[4] == 0.2
    @test device.pmu.angle.variance[4] == 1e-7
    @test device.pmu.angle.status[4] == 1

    updatePmu!(system, device; label = "5 PMU", magnitude = 0.3, angle = 0.4, varianceMagnitude = 1e-10, varianceAngle = 1e-11, statusMagnitude = 1, statusAngle = 0, noise = true)
    @test device.pmu.magnitude.mean[5] ≈ 0.3 atol = 1e-2
    @test device.pmu.magnitude.mean[5] != 0.3
    @test device.pmu.magnitude.variance[5] == 1e-10
    @test device.pmu.magnitude.status[5] == 1
    @test device.pmu.angle.mean[5] ≈ 0.4 atol = 1e-2
    @test device.pmu.magnitude.mean[5] != 0.4
    @test device.pmu.angle.variance[5] == 1e-11
    @test device.pmu.angle.status[5] == 0
end

@testset "Build and Update Measurement Data in SI Units" begin
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

    ####### Test Voltmeter Data #######
    addVoltmeter!(system, device; bus = 1, magnitude = 126.5, variance = 126.5)
    addVoltmeter!(system, device; bus = 1, magnitude = 126.5, variance = 1e-60, noise = true)
    @test device.voltmeter.magnitude.mean[1] == system.bus.voltage.magnitude[1]
    @test device.voltmeter.magnitude.variance[1] == system.bus.voltage.magnitude[1]
    @test device.voltmeter.magnitude.mean[2] == system.bus.voltage.magnitude[1]

    ####### Test Ammeter Data #######
    addAmmeter!(system, device; from = 1, magnitude = 102.5, variance = 102.5)
    addAmmeter!(system, device; from = 1, magnitude = 102.5, variance = 1e-60, noise = true)
    @test device.ammeter.magnitude.mean[1] ≈ (102.5 / baseCurrent) atol = 1e-15
    @test device.ammeter.magnitude.variance[1] ≈ (102.5 / baseCurrent) atol = 1e-15
    @test device.ammeter.magnitude.mean[2] ≈ (102.5 / baseCurrent) atol = 1e-15

    addAmmeter!(system, device; to = 1, magnitude = 20, variance = 20)
    addAmmeter!(system, device; to = 1, magnitude = 20, variance = 1e-60, noise = true)
    @test device.ammeter.magnitude.mean[3] ≈ (20 / baseCurrent) atol = 1e-15
    @test device.ammeter.magnitude.variance[3] ≈ (20 / baseCurrent) atol = 1e-15
    @test device.ammeter.magnitude.mean[4] ≈ (20 / baseCurrent) atol = 1e-15

    ####### Test Wattmeter Data #######
    addWattmeter!(system, device; bus = 1, active = 20.5, variance = 20.5)
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

    ####### Test Varmeter Data #######
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

    addVarmeter!(system, device; to = 1, reactive = 11.2, variance = 11.2)
    addVarmeter!(system, device; to = 1, reactive = 11.2, variance = 1e-60, noise = true)
    @test device.varmeter.reactive.mean[5] == system.bus.demand.reactive[1]
    @test device.varmeter.reactive.variance[5] == system.bus.demand.reactive[1]
    @test device.varmeter.reactive.mean[6] == system.bus.demand.reactive[1]

    ####### Test PMU Data #######
    addPmu!(system, device; bus = 2, magnitude = 95, angle = 2.4, varianceMagnitude = 95, varianceAngle = 2.4, noise = false)
    addPmu!(system, device; bus = 2, magnitude = 95, angle = 2.4, varianceMagnitude = 1e-60, varianceAngle = 1e-60, noise = true)
    @test device.pmu.magnitude.mean[1] == system.bus.voltage.magnitude[2]
    @test device.pmu.magnitude.variance[1] == system.bus.voltage.magnitude[2]
    @test device.pmu.magnitude.mean[2] == system.bus.voltage.magnitude[2]
    @test device.pmu.angle.mean[1] == system.bus.voltage.angle[2]
    @test device.pmu.angle.variance[1] == system.bus.voltage.angle[2]
    @test device.pmu.angle.mean[2] == system.bus.voltage.angle[2]

    addPmu!(system, device; from = 1, magnitude = 40, angle = 0.1, varianceMagnitude = 40, varianceAngle = 0.1)
    addPmu!(system, device; from = 1, magnitude = 40, angle = 0.1, varianceMagnitude = 1e-60, varianceAngle = 1e-60, noise = true)
    @test device.pmu.magnitude.mean[3] ≈ (40 / baseCurrent) atol = 1e-15
    @test device.pmu.magnitude.variance[3] ≈ (40 / baseCurrent) atol = 1e-15
    @test device.pmu.magnitude.mean[4] ≈ (40 / baseCurrent) atol = 1e-15
    @test device.pmu.angle.mean[3] == 0.1
    @test device.pmu.angle.variance[3] == 0.1
    @test device.pmu.angle.mean[4] == 0.1

    addPmu!(system, device; to = 1, magnitude = 60, angle = 3, varianceMagnitude = 60, varianceAngle = 3)
    addPmu!(system, device; to = 1, magnitude = 60, angle = 3, varianceMagnitude = 1e-60, varianceAngle = 1e-60, noise = true)
    @test device.pmu.magnitude.mean[5] ≈ (60 / baseCurrent) atol = 1e-15
    @test device.pmu.magnitude.variance[5] ≈ (60 / baseCurrent) atol = 1e-15
    @test device.pmu.magnitude.mean[6] ≈ (60 / baseCurrent) atol = 1e-15
    @test device.pmu.angle.mean[5] == 3
    @test device.pmu.angle.variance[5] == 3
    @test device.pmu.angle.mean[6] == 3

    ####### Test Multiple Labels #######
    device = measurement()

    @voltmeter(label = "!")
    addVoltmeter!(system, device; bus = 1, magnitude = 1)
    addVoltmeter!(system, device; bus = 1, magnitude = 1)
    addVoltmeter!(system, device; bus = 1, magnitude = 1)

    labels = collect(keys(device.voltmeter.label))
    @test labels[1] == "1"
    @test labels[2] == "1 (1)"
    @test labels[3] == "1 (2)"
end

@testset "Build Random Measurement Set" begin
    ############### Generate Measurement Data from AC Power Flow ###############
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

    ####### Test Set of Voltmeters #######
    addVoltmeter!(system, device, analysis)

    statusVoltmeter!(system, device; inservice = 10)
    @test sum(device.voltmeter.magnitude.status) == 10

    statusVoltmeter!(system, device; outservice = 5)
    @test sum(device.voltmeter.magnitude.status) == 9

    statusVoltmeter!(system, device; redundancy = 0.5)
    @test sum(device.voltmeter.magnitude.status) == round(0.5 * stateVariable)

    ####### Test Set of Ammeters #######
    addAmmeter!(system, device, analysis; noise = true)

    statusAmmeter!(system, device; inservice = 18)
    @test sum(device.ammeter.magnitude.status) == 18

    statusAmmeter!(system, device; outservice = 4)
    @test sum(device.ammeter.magnitude.status) == 32

    statusAmmeter!(system, device; redundancy = 1.1)
    @test sum(device.ammeter.magnitude.status) == round(1.1 * stateVariable)

    layout = device.ammeter.layout
    statusAmmeter!(system, device; inserviceFrom = 10, inserviceTo = 4)
    @test sum(device.ammeter.magnitude.status[layout.from]) == 10
    @test sum(device.ammeter.magnitude.status[layout.to]) == 4

    statusAmmeter!(system, device; outserviceFrom = 5, outserviceTo = 3)
    @test sum(device.ammeter.magnitude.status[layout.from]) == 13
    @test sum(device.ammeter.magnitude.status[layout.to]) == 15

    statusAmmeter!(system, device; redundancyFrom = 0.5, redundancyTo = 0.2)
    @test sum(device.ammeter.magnitude.status[layout.from]) == round(0.5 * stateVariable)
    @test sum(device.ammeter.magnitude.status[layout.to]) == round(0.2 * stateVariable)

    ####### Test Set of Wattmeters #######
    addWattmeter!(system, device, analysis; noise = true)

    statusWattmeter!(system, device; inservice = 14)
    @test sum(device.wattmeter.active.status) == 14

    statusWattmeter!(system, device; outservice = 40)
    @test sum(device.wattmeter.active.status) == 10

    statusWattmeter!(system, device; redundancy = 1.8)
    @test sum(device.wattmeter.active.status) == round(1.8 * stateVariable)

    layout = device.wattmeter.layout
    statusWattmeter!(system, device; inserviceBus = 10, inserviceFrom = 12, inserviceTo = 8)
    @test sum(device.wattmeter.active.status[layout.bus]) == 10
    @test sum(device.wattmeter.active.status[layout.from]) == 12
    @test sum(device.wattmeter.active.status[layout.to]) == 8

    statusWattmeter!(system, device; outserviceBus = 14, outserviceFrom = 15, outserviceTo = 17)
    @test sum(device.wattmeter.active.status[layout.bus]) == 0
    @test sum(device.wattmeter.active.status[layout.from]) == 3
    @test sum(device.wattmeter.active.status[layout.to]) == 1

    statusWattmeter!(system, device; redundancyBus = 0.1, redundancyFrom = 0.3, redundancyTo = 0.4)
    @test sum(device.wattmeter.active.status[layout.bus]) == round(0.1 * stateVariable)
    @test sum(device.wattmeter.active.status[layout.from]) == round(0.3 * stateVariable)
    @test sum(device.wattmeter.active.status[layout.to]) == round(0.4 * stateVariable)

    ####### Test Set of Varmeters #######
    addVarmeter!(system, device, analysis; noise = true)

    statusVarmeter!(system, device; inservice = 1)
    @test sum(device.varmeter.reactive.status) == 1

    statusVarmeter!(system, device; outservice = 30)
    @test sum(device.varmeter.reactive.status) == 20

    statusVarmeter!(system, device; redundancy = 1.2)
    @test sum(device.varmeter.reactive.status) == round(1.2 * stateVariable)

    layout = device.varmeter.layout
    statusVarmeter!(system, device; inserviceBus = 0, inserviceFrom = 18, inserviceTo = 4)
    @test sum(device.varmeter.reactive.status[layout.bus]) == 0
    @test sum(device.varmeter.reactive.status[layout.from]) == 18
    @test sum(device.varmeter.reactive.status[layout.to]) == 4

    statusVarmeter!(system, device; outserviceBus = 0, outserviceFrom = 10, outserviceTo = 2)
    @test sum(device.varmeter.reactive.status[layout.bus]) == 14
    @test sum(device.varmeter.reactive.status[layout.from]) == 8
    @test sum(device.varmeter.reactive.status[layout.to]) == 16

    statusVarmeter!(system, device; redundancyBus = 0.2, redundancyFrom = 0.1, redundancyTo = 0.3)
    @test sum(device.varmeter.reactive.status[layout.bus]) == round(0.2 * stateVariable)
    @test sum(device.varmeter.reactive.status[layout.from]) == round(0.1 * stateVariable)
    @test sum(device.varmeter.reactive.status[layout.to]) == round(0.3 * stateVariable)

    ####### Test Set of PMUs #######
    addPmu!(system, device, analysis; noise = true)

    statusPmu!(system, device; inservice = 10)
    @test device.pmu.magnitude.status == device.pmu.angle.status
    @test sum(device.pmu.magnitude.status) == 10

    statusPmu!(system, device; outservice = 40)
    @test device.pmu.magnitude.status == device.pmu.angle.status
    @test sum(device.pmu.magnitude.status) == 10

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
    @test sum(device.pmu.magnitude.status[layout.from]) == 8
    @test sum(device.pmu.magnitude.status[layout.to]) == 3

    statusPmu!(system, device; redundancyBus = 0.3, redundancyFrom = 0.2, redundancyTo = 0.4)
    @test device.pmu.magnitude.status == device.pmu.angle.status
    @test sum(device.pmu.magnitude.status[layout.bus]) == round(0.3 * stateVariable)
    @test sum(device.pmu.magnitude.status[layout.from]) == round(0.2 * stateVariable)
    @test sum(device.pmu.magnitude.status[layout.to]) == round(0.4 * stateVariable)

    ####### Test Measurement #######
    status!(system, device; inservice = 40)
    @test device.pmu.magnitude.status == device.pmu.angle.status
    @test sum(device.voltmeter.magnitude.status) + sum(device.ammeter.magnitude.status) +
    sum(device.wattmeter.active.status) + sum(device.varmeter.reactive.status) +
    sum(device.pmu.magnitude.status) == 40

    status!(system, device; outservice = 100)
    @test device.pmu.magnitude.status == device.pmu.angle.status
    @test sum(device.voltmeter.magnitude.status) + sum(device.ammeter.magnitude.status) +
    sum(device.wattmeter.active.status) + sum(device.varmeter.reactive.status) +
    sum(device.pmu.magnitude.status) == 100

    status!(system, device; redundancy = 3.1)
    @test device.pmu.magnitude.status == device.pmu.angle.status
    @test sum(device.voltmeter.magnitude.status) + sum(device.ammeter.magnitude.status) +
    sum(device.wattmeter.active.status) + sum(device.varmeter.reactive.status) +
    sum(device.pmu.magnitude.status) == round(3.1 * stateVariable)
end

@testset "Build Measurement Data in Per-Units Using Macros" begin
    @default(template)
    @default(unit)

    system = powerSystem()
    device = measurement()

    addBus!(system; label = "Bus 1")
    addBus!(system; label = "Bus 2")
    addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

    ################ Voltmeter Macro ################
    @voltmeter(label = "Voltmeter ?", variance = 1e-2, status = 0, noise = true)

    ####### Test Voltmeter Data #######
    addVoltmeter!(system, device; bus = "Bus 1", magnitude = 1.0)
    @test device.voltmeter.label["Voltmeter 1"] == 1
    @test device.voltmeter.magnitude.mean[1] != 1.0
    @test device.voltmeter.magnitude.variance[1] == 1e-2
    @test device.voltmeter.magnitude.status[1] == 0

    addVoltmeter!(system, device; bus = "Bus 2", magnitude = 2.0, variance = 1e-3, status = 1, noise = false)
    @test device.voltmeter.label["Voltmeter 2"] == 2
    @test device.voltmeter.magnitude.mean[2] == 2.0
    @test device.voltmeter.magnitude.variance[2] == 1e-3
    @test device.voltmeter.magnitude.status[2] == 1

    ################ Ammeter Macro ################
    @ammeter(label = "Ammeter ?", varianceFrom = 1e-2, varianceTo = 1e-3, statusFrom = 1, statusTo = 0, noise = true)

    ####### Test From-bus Ammeter Data #######
    addAmmeter!(system, device; from = "Branch 1", magnitude = 1.0)
    @test device.ammeter.label["Ammeter 1"] == 1
    @test device.ammeter.magnitude.mean[1] != 1.0
    @test device.ammeter.magnitude.variance[1] == 1e-2
    @test device.ammeter.magnitude.status[1] == 1

    addAmmeter!(system, device; from = "Branch 1", magnitude = 3.0, variance = 1e-4, status = 0, noise = false)
    @test device.ammeter.label["Ammeter 2"] == 2
    @test device.ammeter.magnitude.mean[2] == 3.0
    @test device.ammeter.magnitude.variance[2] == 1e-4
    @test device.ammeter.magnitude.status[2] == 0

    ####### Test To-bus Ammeter Data #######
    addAmmeter!(system, device; to = "Branch 1", magnitude = 2.0)
    @test device.ammeter.label["Ammeter 3"] == 3
    @test device.ammeter.magnitude.mean[3] != 2.0
    @test device.ammeter.magnitude.variance[3] == 1e-3
    @test device.ammeter.magnitude.status[3] == 0

    addAmmeter!(system, device; to = "Branch 1", magnitude = 4.0, variance = 1e-5, status = 1, noise = false)
    @test device.ammeter.label["Ammeter 4"] == 4
    @test device.ammeter.magnitude.mean[4] == 4.0
    @test device.ammeter.magnitude.variance[4] == 1e-5
    @test device.ammeter.magnitude.status[4] == 1

    ################ Wattmeter Macro ################
    @wattmeter(label = "Wattmeter ?", varianceBus = 1e-1, varianceFrom = 1e-2, varianceTo = 1e-3, statusBus = 0, statusFrom = 1, statusTo = 0, noise = true)

    ####### Test Bus Wattmeter Data #######
    addWattmeter!(system, device; bus = "Bus 1", active = 1.0)
    @test device.wattmeter.label["Wattmeter 1"] == 1
    @test device.wattmeter.active.mean[1] != 1.0
    @test device.wattmeter.active.variance[1] == 1e-1
    @test device.wattmeter.active.status[1] == 0

    addWattmeter!(system, device; bus = "Bus 1", active = 2.0, variance = 1, status = 1, noise = false)
    @test device.wattmeter.label["Wattmeter 2"] == 2
    @test device.wattmeter.active.mean[2] == 2.0
    @test device.wattmeter.active.variance[2] == 1
    @test device.wattmeter.active.status[2] == 1

    ####### Test From-bus Wattmeter Data #######
    addWattmeter!(system, device; from = "Branch 1", active = 5.0)
    @test device.wattmeter.label["Wattmeter 3"] == 3
    @test device.wattmeter.active.mean[3] != 5.0
    @test device.wattmeter.active.variance[3] == 1e-2
    @test device.wattmeter.active.status[3] == 1

    addWattmeter!(system, device; from = "Branch 1", active = 6.0, variance = 2, status = 0, noise = false)
    @test device.wattmeter.label["Wattmeter 4"] == 4
    @test device.wattmeter.active.mean[4] == 6.0
    @test device.wattmeter.active.variance[4] == 2
    @test device.wattmeter.active.status[4] == 0

    ####### Test To-bus Wattmeter Data #######
    addWattmeter!(system, device; to = "Branch 1", active = 6.0)
    @test device.wattmeter.label["Wattmeter 5"] == 5
    @test device.wattmeter.active.mean[5] != 6.0
    @test device.wattmeter.active.variance[5] == 1e-3
    @test device.wattmeter.active.status[5] == 0

    addWattmeter!(system, device; to = "Branch 1", active = 7.0, variance = 3, status = 1, noise = false)
    @test device.wattmeter.label["Wattmeter 6"] == 6
    @test device.wattmeter.active.mean[6] == 7.0
    @test device.wattmeter.active.variance[6] == 3
    @test device.wattmeter.active.status[6] == 1

    ################ Varmeter Macro ################
    @varmeter(label = "Varmeter ?", varianceBus = 1, varianceFrom = 2, varianceTo = 3, statusBus = 1, statusFrom = 0, statusTo = 1, noise = true)

    ####### Test Bus Varmeter Data #######
    addVarmeter!(system, device; bus = "Bus 1", reactive = 1.1)
    @test device.varmeter.label["Varmeter 1"] == 1
    @test device.varmeter.reactive.mean[1] != 1.1
    @test device.varmeter.reactive.variance[1] == 1
    @test device.varmeter.reactive.status[1] == 1

    addVarmeter!(system, device; bus = "Bus 1", reactive = 2.1, variance = 10, status = 0, noise = false)
    @test device.varmeter.label["Varmeter 2"] == 2
    @test device.varmeter.reactive.mean[2] == 2.1
    @test device.varmeter.reactive.variance[2] == 10
    @test device.varmeter.reactive.status[2] == 0

    ####### Test From-bus Varmeter Data #######
    addVarmeter!(system, device; from = "Branch 1", reactive = 5.1)
    @test device.varmeter.label["Varmeter 3"] == 3
    @test device.varmeter.reactive.mean[3] != 5.1
    @test device.varmeter.reactive.variance[3] == 2
    @test device.varmeter.reactive.status[3] == 0

    addVarmeter!(system, device; from = "Branch 1", reactive = 6.1, variance = 20, status = 1, noise = false)
    @test device.varmeter.label["Varmeter 4"] == 4
    @test device.varmeter.reactive.mean[4] == 6.1
    @test device.varmeter.reactive.variance[4] == 20
    @test device.varmeter.reactive.status[4] == 1

    ####### Test To-bus Varmeter Data #######
    addVarmeter!(system, device; to = "Branch 1", reactive = 6.1)
    @test device.varmeter.label["Varmeter 5"] == 5
    @test device.varmeter.reactive.mean[5] != 6.1
    @test device.varmeter.reactive.variance[5] == 3
    @test device.varmeter.reactive.status[5] == 1

    addVarmeter!(system, device; to = "Branch 1", reactive = 7.1, variance = 30, status = 0, noise = false)
    @test device.varmeter.label["Varmeter 6"] == 6
    @test device.varmeter.reactive.mean[6] == 7.1
    @test device.varmeter.reactive.variance[6] == 30
    @test device.varmeter.reactive.status[6] == 0

    ################ PMU Macro ################
    @pmu(label = "PMU ?", noise = true, polar = true, correlated = true,
    varianceMagnitudeBus = 10, varianceAngleBus = 20,
    statusMagnitudeBus = 0, statusAngleBus = 1,
    varianceMagnitudeFrom = 30, varianceAngleFrom = 40,
    statusMagnitudeFrom = 1, statusAngleFrom = 0,
    varianceMagnitudeTo = 50, varianceAngleTo = 60,
    statusMagnitudeTo = 0, statusAngleTo = 0)

    ####### Test Bus PMU Data #######
    addPmu!(system, device; bus = "Bus 1", magnitude = 2, angle = 1)
    @test device.pmu.label["PMU 1"] == 1
    @test device.pmu.magnitude.mean[1] != 2
    @test device.pmu.magnitude.variance[1] == 10
    @test device.pmu.magnitude.status[1] == 0
    @test device.pmu.angle.mean[1] != 1
    @test device.pmu.angle.variance[1] == 20
    @test device.pmu.angle.status[1] == 1
    @test device.pmu.layout.polar[1] == true
    @test device.pmu.layout.correlated[1] == true

    addPmu!(system, device; bus = "Bus 1", noise = false, polar = false, correlated = false,
    magnitude = 3, varianceMagnitude = 1e-1, statusMagnitude = 1, angle = 4, varianceAngle = 1e-2, statusAngle = 0)
    @test device.pmu.label["PMU 2"] == 2
    @test device.pmu.magnitude.mean[2] == 3
    @test device.pmu.magnitude.variance[2] == 1e-1
    @test device.pmu.magnitude.status[2] == 1
    @test device.pmu.angle.mean[2] == 4
    @test device.pmu.angle.variance[2] == 1e-2
    @test device.pmu.angle.status[2] == 0
    @test device.pmu.layout.polar[2] == false
    @test device.pmu.layout.correlated[2] == false

    ####### Test From-bus PMU Data #######
    addPmu!(system, device; from = "Branch 1", magnitude = 5, angle = 6)
    @test device.pmu.label["PMU 3"] == 3
    @test device.pmu.magnitude.mean[3] != 5
    @test device.pmu.magnitude.variance[3] == 30
    @test device.pmu.magnitude.status[3] == 1
    @test device.pmu.angle.mean[3] != 6
    @test device.pmu.angle.variance[3] == 40
    @test device.pmu.angle.status[3] == 0
    @test device.pmu.layout.polar[3] == true
    @test device.pmu.layout.correlated[3] == true

    addPmu!(system, device; from = "Branch 1", noise = false, polar = false, correlated = false,
    magnitude = 7, varianceMagnitude = 2e-1, statusMagnitude = 0, angle = 8, varianceAngle = 2e-2, statusAngle = 1)
    @test device.pmu.label["PMU 4"] == 4
    @test device.pmu.magnitude.mean[4] == 7
    @test device.pmu.magnitude.variance[4] == 2e-1
    @test device.pmu.magnitude.status[4] == 0
    @test device.pmu.angle.mean[4] == 8
    @test device.pmu.angle.variance[4] == 2e-2
    @test device.pmu.angle.status[4] == 1
    @test device.pmu.layout.polar[4] == false
    @test device.pmu.layout.correlated[4] == false

    ####### Test To-bus PMU Data #######
    addPmu!(system, device; to = "Branch 1", magnitude = 500, angle = 600)
    @test device.pmu.label["PMU 5"] == 5
    @test device.pmu.magnitude.mean[5] != 500
    @test device.pmu.magnitude.variance[5] == 50
    @test device.pmu.magnitude.status[5] == 0
    @test device.pmu.angle.mean[5] != 600
    @test device.pmu.angle.variance[5] == 60
    @test device.pmu.angle.status[5] == 0
    @test device.pmu.layout.polar[5] == true
    @test device.pmu.layout.correlated[5] == true

    addPmu!(system, device; to = "Branch 1", noise = false, polar = false, correlated = false,
    magnitude = 9, varianceMagnitude = 3e-1, statusMagnitude = 1, angle = 10, varianceAngle = 3e-2, statusAngle = 1)
    @test device.pmu.label["PMU 6"] == 6
    @test device.pmu.magnitude.mean[6] == 9
    @test device.pmu.magnitude.variance[6] == 3e-1
    @test device.pmu.magnitude.status[6] == 1
    @test device.pmu.angle.mean[6] == 10
    @test device.pmu.angle.variance[6] == 3e-2
    @test device.pmu.angle.status[6] == 1
    @test device.pmu.layout.polar[6] == false
    @test device.pmu.layout.correlated[6] == false
end

@testset "Build Measurement Data in SI Units Using Macros" begin
    @default(unit)
    @default(template)

    ################ Build Power System ################
    @power(MW, MVAr, GVA)
    @voltage(kV, deg, kV)
    @current(A, deg)

    system = powerSystem()
    device = measurement()
    @base(system, MVA, kV)

    addBus!(system; label = "Bus 1", base = 100)
    addBus!(system; label = "Bus 2", base = 100)
    addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

    ################ Test Voltmeter Macro ################
    @voltmeter(label = "Voltmeter ?", variance = 1)

    addVoltmeter!(system, device; bus = "Bus 1", magnitude = 100)
    @test device.voltmeter.magnitude.mean[1] == 1.0
    @test device.voltmeter.magnitude.variance[1] == 1e-2

    ################ Test Ammeter Macro ################
    @ammeter(label = "Ammeter ?", varianceFrom = 1e-2 * ((100 * 10^6) / (sqrt(3) * 100 * 10^3)))

    addAmmeter!(system, device; from = "Branch 1", magnitude = (100 * 10^6) / (sqrt(3) * 100 * 10^3))
    @test device.ammeter.magnitude.mean[1] ≈ 1.0
    @test device.ammeter.magnitude.variance[1] ≈ 1e-2

    ################ Test Wattmeter Macro ################
    @wattmeter(label = "Wattmeter ?", varianceBus = 10)

    addWattmeter!(system, device; bus = "Bus 1", active = 100)
    @test device.wattmeter.active.mean[1] == 1.0
    @test device.wattmeter.active.variance[1] == 1e-1

    ################ Test Varmeter Macro ################
    @varmeter(label = "Varmeter ?", varianceBus = 100)

    addVarmeter!(system, device; bus = "Bus 1", reactive = 110)
    @test device.varmeter.reactive.mean[1] == 1.1
    @test device.varmeter.reactive.variance[1] == 1

    ################ Test PMU Macro ################
    @pmu(label = "PMU ?", varianceMagnitudeBus = 1e3, varianceAngleBus = 20 * 180 / pi,
    varianceMagnitudeFrom = 30 * ((100 * 10^6) / (sqrt(3) * 100 * 10^3)), varianceAngleFrom = 40 * 180 / pi)

    addPmu!(system, device; bus = "Bus 1", magnitude = 2e2, angle = 1 * 180 / pi)
    @test device.pmu.magnitude.mean[1] == 2
    @test device.pmu.magnitude.variance[1] == 10
    @test device.pmu.angle.mean[1] == 1
    @test device.pmu.angle.variance[1] == 20

    addPmu!(system, device; from = "Branch 1", magnitude = 5 * ((100 * 10^6) / (sqrt(3) * 100 * 10^3)), angle = 6 * 180 / pi)
    @test device.pmu.magnitude.mean[2] ≈ 5
    @test device.pmu.magnitude.variance[2] ≈ 30
    @test device.pmu.angle.mean[2] ≈ 6
    @test device.pmu.angle.variance[2] ≈ 40
end

@testset "Test Errors and Messages" begin
    @default(unit)
    @default(template)
    system = powerSystem()
    device = measurement()

    addBus!(system; label = "Bus 1", type = 3)
    addBus!(system; label = "Bus 2")
    addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)
    addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.2)

    analysis = newtonRaphson(system)
    for iteration = 1:5
        mismatch!(system, analysis)
        solve!(system, analysis)
    end

    addVoltmeter!(system, device; label = "Voltmeter 1", bus = "Bus 1", magnitude = 1)
    addAmmeter!(system, device; label = "Ammeter 1", from = "Branch 1", magnitude = 1)
    addWattmeter!(system, device; label = "Wattmeter 1", from = "Branch 1", active = 1)
    addVarmeter!(system, device; label = "Varmeter 1", from = "Branch 1", reactive = 1)
    addPmu!(system, device; label = "PMU 1", bus = "Bus 1", magnitude = 1, angle = 1)

    ####### Test Voltmeter Errors #######
    @test_throws ErrorException("The label Voltmeter 1 is not unique.") addVoltmeter!(system, device; label = "Voltmeter 1", bus = "Bus 1", magnitude = 1)
    @test_throws ErrorException("The status 2 is not allowed; it should be either in-service (1) or out-of-service (0).") addVoltmeter!(system, device; label = "Voltmeter 2", bus = "Bus 1", magnitude = 1, status = 2)

    @test_throws LoadError @eval @voltmeter(label = "Voltmeter ?", means = 1)

    ####### Test Ammeter Errors #######
    @test_throws ErrorException("The label Ammeter 1 is not unique.") addAmmeter!(system, device; label = "Ammeter 1", from = "Branch 1", magnitude = 1)
    @test_throws ErrorException("At least one of the location keywords must be provided.") addAmmeter!(system, device; label = "Ammeter 1", magnitude = 1)
    @test_throws ErrorException("The concurrent definition of the location keywords is not allowed.") addAmmeter!(system, device; label = "Ammeter 1", from = "Branch 1", to = "Branch 1", magnitude = 1)
    @test_throws ErrorException("The currents cannot be found.") addAmmeter!(system, device, analysis)

    @test_throws LoadError @eval @ammeter(label = "Ammeter ?", means = 1)

    ####### Test Wattmeter Errors #######
    @test_throws ErrorException("The label Wattmeter 1 is not unique.") addWattmeter!(system, device; label = "Wattmeter 1", from = "Branch 1", active = 1)
    @test_throws ErrorException("The concurrent definition of the location keywords is not allowed.") addWattmeter!(system, device; label = "Wattmeter 1", from = "Branch 1", to = "Branch 1", active = 1)
    @test_throws ErrorException("At least one of the location keywords must be provided.") addWattmeter!(system, device; label = "Wattmeter 1", active = 1)
    @test_throws ErrorException("The powers cannot be found.") addWattmeter!(system, device, analysis)

    @test_throws LoadError @eval @wattmeter(label = "Wattmeter ?", means = 1)

    ####### Test Varmeter Errors #######
    @test_throws ErrorException("The label Varmeter 1 is not unique.") addVarmeter!(system, device; label = "Varmeter 1", from = "Branch 1", reactive = 1)
    @test_throws ErrorException("The concurrent definition of the location keywords is not allowed.") addVarmeter!(system, device; label = "Varmeter 1", from = "Branch 1", to = "Branch 1", bus = "Bus 1", reactive = 1)
    @test_throws ErrorException("The powers cannot be found.") addVarmeter!(system, device, analysis)

    @test_throws LoadError @eval @varmeter(label = "Varmeter ?", means = 1)

    ####### Test PMU Errors #######
    @test_throws ErrorException("The label PMU 1 is not unique.") addPmu!(system, device; label = "PMU 1", bus = "Bus 1", magnitude = 1, angle = 1)
    @test_throws ErrorException("The currents cannot be found.") addPmu!(system, device, analysis)

    @test_throws LoadError @eval @pmu(label = "PMU ?", means = 1)

    ####### Test Configuration Errors #######
    @test_throws ErrorException("The total number of available devices is less than the requested number for a status change.") status!(system, device; inservice = 12)
    @test_throws ErrorException("The total number of available devices is less than the requested number for a status change.") statusVoltmeter!(system, device; inservice = 12)
    @test_throws ErrorException("The total number of available devices is less than the requested number for a status change.") statusPmu!(system, device; inservice = 12)
    @test_throws ErrorException("The total number of available devices is less than the requested number for a status change.") statusAmmeter!(system, device; inserviceFrom = 12)
    @test_throws ErrorException("The total number of available devices is less than the requested number for a status change.") statusPmu!(system, device; inserviceBus = 12)

    ####### Test Load Errors #######
    @test_throws DomainError(".m", "The extension .m is not supported.") measurement("case14.m")
end