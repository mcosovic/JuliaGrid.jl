@testset "Build and Update Measurements in Per-Units" begin
    @default(template)
    @default(unit)

    system = powerSystem(path * "case14test.m")
    monitoring = measurement(system)
    fully = measurement(system)

    pf = newtonRaphson(system)
    powerFlow!(pf; power = true, current = true)

    @voltmeter(label = "?", variance = 1e-60)
    @ammeter(label = "Amm ?", varianceFrom = 1e-2, varianceTo = 1e-3, statusFrom = 0)
    @wattmeter(varianceBus = 1e-3, varianceFrom = 1e-2, varianceTo = 1e-4, statusBus = 0)
    @varmeter(varianceBus = 1e-2, varianceFrom = 1e-2, varianceTo = 1e-1, statusTo = 0)
    @pmu(label = "? PMU", varianceMagnitudeBus = 1e-3, varianceAngleBus = 1e-5)
    @pmu(varianceMagnitudeFrom = 1e-5, varianceAngleFrom = 1e-6, statusFrom = 0)
    @pmu(varianceMagnitudeTo = 1e-2, varianceAngleTo = 1e-3)

    ########## Generate Measurements from AC Power Flow ##########
    addVoltmeter!(fully, pf; noise = true)
    addAmmeter!(fully, pf)
    addWattmeter!(fully, pf)
    addVarmeter!(fully, pf)
    addPmu!(fully, pf)

    volt = monitoring.voltmeter
    amp = monitoring.ammeter
    watt = monitoring.wattmeter
    var = monitoring.varmeter
    pmu = monitoring.pmu

    @testset "Bus Measurements" begin
        for (key, idx) in system.bus.label
            addVoltmeter!(monitoring; bus = key, magnitude = pf.voltage.magnitude[idx])
            testDevice(volt.magnitude, fully.voltmeter.magnitude, idx, 1)

            addWattmeter!(monitoring; bus = key, active = pf.power.injection.active[idx])
            testDevice(watt.active, fully.wattmeter.active, idx, 0)

            addVarmeter!(monitoring; bus = key, reactive = pf.power.injection.reactive[idx])
            testDevice(var.reactive, fully.varmeter.reactive, idx, 1)

            addPmu!(monitoring; bus = key, magnitude = pf.voltage.magnitude[idx], angle = pf.voltage.angle[idx])
            testDevice(pmu.magnitude, fully.pmu.magnitude, idx, 1)
            testDevice(pmu.angle, fully.pmu.angle, idx, 1)
        end
    end

    @testset "Branch Measurements" begin
        cnt = 1
        for (key, idx) in system.branch.label
            if system.branch.layout.status[idx] == 0
                continue
            end
            cnt1 = system.bus.number + cnt

            addAmmeter!(monitoring; from = key, magnitude = pf.current.from.magnitude[idx])
            testDevice(amp.magnitude, fully.ammeter.magnitude, cnt, 0)

            addAmmeter!(monitoring; to = key, magnitude = pf.current.to.magnitude[idx])
            testDevice(amp.magnitude, fully.ammeter.magnitude, cnt + 1, 1)

            addWattmeter!(monitoring; from = key, active = pf.power.from.active[idx])
            testDevice(watt.active, fully.wattmeter.active, cnt1, 1)

            addWattmeter!(monitoring; from = key, active = pf.power.to.active[idx])
            testDevice(watt.active, fully.wattmeter.active, cnt1 + 1, 1)

            addVarmeter!(monitoring; from = key, reactive = pf.power.from.reactive[idx])
            testDevice(var.reactive, fully.varmeter.reactive, cnt1, 1)

            addVarmeter!(monitoring; to = key, reactive = pf.power.to.reactive[idx])
            testDevice(var.reactive, fully.varmeter.reactive, cnt1 + 1, 0)

            addPmu!(
                monitoring; from = key,
                magnitude = pf.current.from.magnitude[idx], angle = pf.current.from.angle[idx]
            )
            testDevice(pmu.magnitude, fully.pmu.magnitude, cnt1, 0)
            testDevice(pmu.angle, fully.pmu.angle, cnt1, 0)

            addPmu!(
                monitoring; to = key,
                magnitude = pf.current.to.magnitude[idx], angle = pf.current.to.angle[idx]
            )
            testDevice(pmu.magnitude, fully.pmu.magnitude, cnt1 + 1, 1)
            testDevice(pmu.angle, fully.pmu.angle, cnt1 + 1, 1)

            cnt += 2
        end
    end

    @testset "Update Voltmeters" begin
        updateVoltmeter!(monitoring; label = "3", magnitude = 0.2, status = 0)
        updateVoltmeter!(monitoring; label = "3", variance = 1e-6)

        @test monitoring.voltmeter.magnitude.mean[3] == 0.2
        @test monitoring.voltmeter.magnitude.variance[3] == 1e-6
        @test monitoring.voltmeter.magnitude.status[3] == 0

        updateVoltmeter!(monitoring; label = "5", magnitude = 0.3, variance = 1e-10, noise = true)
        updateVoltmeter!(monitoring; label = "5", status = 1)

        @test monitoring.voltmeter.magnitude.mean[5] ≈ 0.3 atol = 1e-2
        @test monitoring.voltmeter.magnitude.mean[5] != 0.3
        @test monitoring.voltmeter.magnitude.variance[5] == 1e-10
        @test monitoring.voltmeter.magnitude.status[5] == 1
    end

    @testset "Update Ammeters" begin
        updateAmmeter!(monitoring; label = "Amm 3", magnitude = 0.4, variance = 1e-8)
        updateAmmeter!(monitoring; label = "Amm 3", status = 0)

        @test monitoring.ammeter.magnitude.mean[3] == 0.4
        @test monitoring.ammeter.magnitude.variance[3] == 1e-8
        @test monitoring.ammeter.magnitude.status[3] == 0

        updateAmmeter!(monitoring; label = "Amm 8", magnitude = 0.6, variance = 1e-10, noise = true)
        updateAmmeter!(monitoring; label = "Amm 8", status = 1)

        @test monitoring.ammeter.magnitude.mean[8] ≈ 0.6 atol = 1e-2
        @test monitoring.ammeter.magnitude.mean[8] != 0.6
        @test monitoring.ammeter.magnitude.variance[8] == 1e-10
        @test monitoring.ammeter.magnitude.status[8] == 1
    end

    @testset "Update Wattmeters" begin
        updateWattmeter!(monitoring; label = "4", active = 0.5, variance = 1e-2, status = 0)

        @test monitoring.wattmeter.active.mean[4] == 0.5
        @test monitoring.wattmeter.active.variance[4] == 1e-2
        @test monitoring.wattmeter.active.status[4] == 0

        updateWattmeter!(monitoring; label = "14", active = 0.1, variance = 1e-10, noise = true)
        updateWattmeter!(monitoring;label = "14", status = 1)

        @test monitoring.wattmeter.active.mean[14] ≈ 0.1 atol = 1e-2
        @test monitoring.wattmeter.active.mean[14] != 0.1
        @test monitoring.wattmeter.active.variance[14] == 1e-10
        @test monitoring.wattmeter.active.status[14] == 1
    end

    @testset "Update Varmeters" begin
        updateVarmeter!(monitoring; label = "5", reactive = 1.5, variance = 1e-1, status = 0)

        @test monitoring.varmeter.reactive.mean[5] == 1.5
        @test monitoring.varmeter.reactive.variance[5] == 1e-1
        @test monitoring.varmeter.reactive.status[5] == 0

        updateVarmeter!(monitoring; label = "16", reactive = 0.9, variance = 1e-10, noise = true)
        updateVarmeter!(monitoring; label = "16", status = 1)

        @test monitoring.varmeter.reactive.mean[16] ≈ 0.9 atol = 1e-2
        @test monitoring.varmeter.reactive.mean[16] != 0.9
        @test monitoring.varmeter.reactive.variance[16] == 1e-10
        @test monitoring.varmeter.reactive.status[16] == 1
    end

    @testset "Update PMUs" begin
        updatePmu!(monitoring; label = "4 PMU", magnitude = 0.1, angle = 0.2)
        updatePmu!(monitoring; label = "4 PMU", varianceMagnitude = 1e-6, varianceAngle = 1e-7)
        updatePmu!(monitoring; label = "4 PMU", status = 1)

        @test monitoring.pmu.magnitude.mean[4] == 0.1
        @test monitoring.pmu.magnitude.variance[4] == 1e-6
        @test monitoring.pmu.magnitude.status[4] == 1
        @test monitoring.pmu.angle.mean[4] == 0.2
        @test monitoring.pmu.angle.variance[4] == 1e-7
        @test monitoring.pmu.angle.status[4] == 1

        updatePmu!(monitoring; label = "5 PMU", magnitude = 0.3, varianceMagnitude = 1e-10, noise = true)
        updatePmu!(monitoring; label = "5 PMU", angle = 0.4, varianceAngle = 1e-11, noise = true)
        updatePmu!(monitoring; label = "5 PMU", status = 0)

        @test monitoring.pmu.magnitude.mean[5] ≈ 0.3 atol = 1e-2
        @test monitoring.pmu.magnitude.mean[5] != 0.3
        @test monitoring.pmu.magnitude.variance[5] == 1e-10
        @test monitoring.pmu.magnitude.status[5] == 0
        @test monitoring.pmu.angle.mean[5] ≈ 0.4 atol = 1e-2
        @test monitoring.pmu.magnitude.mean[5] != 0.4
        @test monitoring.pmu.angle.variance[5] == 1e-11
        @test monitoring.pmu.angle.status[5] == 0
    end
end

@testset "Build and Update Measurements in SI Units" begin
    @default(template)
    @default(unit)

    @power(kW, MVAr, GVA)
    @voltage(kV, deg, MV)
    @current(A, rad)

    system = powerSystem()
    monitoring = measurement(system)
    @base(system, MVA, kV)
    fn = sqrt(3)

    @bus(base = 0.23)
    @branch(reactance = 0.02)

    addBus!(system; label = 1, active = 20.5, reactive = 11.2, magnitude = 126.5 / fn, type = 3)
    addBus!(system; label = 2, magnitude = 95 / fn, angle = 2.4)
    addBranch!(system; label = 1, from = 1, to = 2)
    addGenerator!(system; bus = 1)
    baseCurrent = system.base.power.value * system.base.power.prefix / (fn * 0.23 * 10^6)

    @testset "Voltmeter Data" begin
        addVoltmeter!(monitoring; bus = 1, magnitude = 126.5 / fn, variance = 126.5 / fn)
        addVoltmeter!(monitoring; bus = 1, magnitude = 126.5 / fn, variance = 1e-60 / fn, noise = true)

        @test monitoring.voltmeter.magnitude.mean[1] == system.bus.voltage.magnitude[1]
        @test monitoring.voltmeter.magnitude.variance[1] == system.bus.voltage.magnitude[1]
        @test monitoring.voltmeter.magnitude.mean[2] == system.bus.voltage.magnitude[1]
    end

    @testset "Ammeter Data" begin
        addAmmeter!(monitoring; from = 1, magnitude = 102.5, variance = 102.5)
        addAmmeter!(monitoring; from = 1, magnitude = 102.5, variance = 1e-60, noise = true)

        @test monitoring.ammeter.magnitude.mean[1] ≈ (102.5 / baseCurrent) atol = 1e-15
        @test monitoring.ammeter.magnitude.variance[1] ≈ (102.5 / baseCurrent) atol = 1e-15
        @test monitoring.ammeter.magnitude.mean[2] ≈ (102.5 / baseCurrent) atol = 1e-15

        addAmmeter!(monitoring; to = 1, magnitude = 20, variance = 20)
        addAmmeter!(monitoring; to = 1, magnitude = 20, variance = 1e-60, noise = true)

        @test monitoring.ammeter.magnitude.mean[3] ≈ (20 / baseCurrent) atol = 1e-15
        @test monitoring.ammeter.magnitude.variance[3] ≈ (20 / baseCurrent) atol = 1e-15
        @test monitoring.ammeter.magnitude.mean[4] ≈ (20 / baseCurrent) atol = 1e-15
    end

    @testset "Wattmeter Data" begin
        addWattmeter!(monitoring; bus = 1, active = 20.5, variance = 20.5)
        addWattmeter!(monitoring; bus = 1, active = 20.5, variance = 1e-60, noise = true)

        @test monitoring.wattmeter.active.mean[1] == system.bus.demand.active[1]
        @test monitoring.wattmeter.active.variance[1] == system.bus.demand.active[1]
        @test monitoring.wattmeter.active.mean[2] == system.bus.demand.active[1]

        addWattmeter!(monitoring; from = 1, active = 20.5, variance = 20.5, noise = false)
        addWattmeter!(monitoring; from = 1, active = 20.5, variance = 1e-60, noise = true)

        @test monitoring.wattmeter.active.mean[3] == system.bus.demand.active[1]
        @test monitoring.wattmeter.active.variance[3] == system.bus.demand.active[1]
        @test monitoring.wattmeter.active.mean[4] == system.bus.demand.active[1]

        addWattmeter!(monitoring; to = 1, active = 20.5, variance = 20.5, noise = false)
        addWattmeter!(monitoring; to = 1, active = 20.5, variance = 1e-60, noise = true)

        @test monitoring.wattmeter.active.mean[5] == system.bus.demand.active[1]
        @test monitoring.wattmeter.active.variance[5] == system.bus.demand.active[1]
        @test monitoring.wattmeter.active.mean[6] == system.bus.demand.active[1]
    end

    @testset "Varmeter Data" begin
        addVarmeter!(monitoring; bus = 1, reactive = 11.2, variance = 11.2, noise = false)
        addVarmeter!(monitoring; bus = 1, reactive = 11.2, variance = 1e-60, noise = true)

        @test monitoring.varmeter.reactive.mean[1] == system.bus.demand.reactive[1]
        @test monitoring.varmeter.reactive.variance[1] == system.bus.demand.reactive[1]
        @test monitoring.varmeter.reactive.mean[2] == system.bus.demand.reactive[1]

        addVarmeter!(monitoring; from = 1, reactive = 11.2, variance = 11.2, noise = false)
        addVarmeter!(monitoring; from = 1,reactive = 11.2, variance = 1e-60,  noise = true)

        @test monitoring.varmeter.reactive.mean[3] == system.bus.demand.reactive[1]
        @test monitoring.varmeter.reactive.variance[3] == system.bus.demand.reactive[1]
        @test monitoring.varmeter.reactive.mean[4] == system.bus.demand.reactive[1]

        addVarmeter!(monitoring; to = 1, reactive = 11.2, variance = 11.2)
        addVarmeter!(monitoring; to = 1, reactive = 11.2, variance = 1e-60, noise = true)

        @test monitoring.varmeter.reactive.mean[5] == system.bus.demand.reactive[1]
        @test monitoring.varmeter.reactive.variance[5] == system.bus.demand.reactive[1]
        @test monitoring.varmeter.reactive.mean[6] == system.bus.demand.reactive[1]
    end

    @testset "PMU Data" begin
        addPmu!(monitoring; bus = 2, magnitude = 95 / fn, angle = 2.4)
        updatePmu!(monitoring; label = 1, varianceMagnitude = 95 / fn, varianceAngle = 2.4)

        @test monitoring.pmu.magnitude.mean[1] == system.bus.voltage.magnitude[2]
        @test monitoring.pmu.magnitude.variance[1] == system.bus.voltage.magnitude[2]
        @test monitoring.pmu.angle.mean[1] == system.bus.voltage.angle[2]
        @test monitoring.pmu.angle.variance[1] == system.bus.voltage.angle[2]

        addPmu!(monitoring; from = 1, magnitude = 40, angle = 0.1)
        updatePmu!(monitoring; label = 2, varianceMagnitude = 40, varianceAngle = 0.1)

        @test monitoring.pmu.magnitude.mean[2] ≈ (40 / baseCurrent) atol = 1e-15
        @test monitoring.pmu.magnitude.variance[2] ≈ (40 / baseCurrent) atol = 1e-15
        @test monitoring.pmu.angle.mean[2] == 0.1
        @test monitoring.pmu.angle.variance[2] == 0.1

        addPmu!(monitoring; to = 1, magnitude = 60, angle = 3)
        updatePmu!(monitoring; label = 3, varianceMagnitude = 60, varianceAngle = 3)

        @test monitoring.pmu.magnitude.mean[3] ≈ (60 / baseCurrent) atol = 1e-15
        @test monitoring.pmu.magnitude.variance[3] ≈ (60 / baseCurrent) atol = 1e-15
        @test monitoring.pmu.angle.mean[3] == 3
        @test monitoring.pmu.angle.variance[3] == 3
    end

    @testset "Multiple Labels" begin
        monitoring = measurement(system)

        @voltmeter(label = "!")
        addVoltmeter!(monitoring; bus = 1, magnitude = 1)
        addVoltmeter!(monitoring; bus = 1, magnitude = 1)
        addVoltmeter!(monitoring; bus = 1, magnitude = 1)

        labels = collect(keys(monitoring.voltmeter.label))
        @test labels[1] == "1"
        @test labels[2] == "1 (1)"
        @test labels[3] == "1 (2)"
    end
end

@testset "Build Random Measurement Set" begin
    @default(template)
    @config(label = Integer)

    ########## Generate Measurements from AC Power Flow ##########
    system, monitoring = ems(path * "case14test.m")

    analysis = newtonRaphson(system)
    powerFlow!(analysis; power = true, current = true)

    stateVariable = 2 * system.bus.number - 1

    @testset "Set of Voltmeters" begin
        addVoltmeter!(monitoring, analysis)

        statusVoltmeter!(monitoring; inservice = 10)
        @test sum(monitoring.voltmeter.magnitude.status) == 10

        statusVoltmeter!(monitoring; outservice = 5)
        @test sum(monitoring.voltmeter.magnitude.status) == 9

        statusVoltmeter!(monitoring; redundancy = 0.5)
        @test sum(monitoring.voltmeter.magnitude.status) == round(0.5 * stateVariable)
    end

    @testset "Set of Ammeters" begin
        addAmmeter!(monitoring, analysis; noise = true)

        statusAmmeter!(monitoring; inservice = 18)
        @test sum(monitoring.ammeter.magnitude.status) == 18

        statusAmmeter!(monitoring; outservice = 4)
        @test sum(monitoring.ammeter.magnitude.status) == 32

        statusAmmeter!(monitoring; redundancy = 1.1)
        @test sum(monitoring.ammeter.magnitude.status) == round(1.1 * stateVariable)

        layout = monitoring.ammeter.layout
        statusAmmeter!(monitoring; inserviceFrom = 10, inserviceTo = 4)
        @test sum(monitoring.ammeter.magnitude.status[layout.from]) == 10
        @test sum(monitoring.ammeter.magnitude.status[layout.to]) == 4

        statusAmmeter!(monitoring; outserviceFrom = 5, outserviceTo = 3)
        @test sum(monitoring.ammeter.magnitude.status[layout.from]) == 13
        @test sum(monitoring.ammeter.magnitude.status[layout.to]) == 15

        statusAmmeter!(monitoring; redundancyFrom = 0.5, redundancyTo = 0.2)
        @test sum(monitoring.ammeter.magnitude.status[layout.from]) == round(0.5 * stateVariable)
        @test sum(monitoring.ammeter.magnitude.status[layout.to]) == round(0.2 * stateVariable)
    end

    @testset "Set of Wattmeters" begin
        addWattmeter!(monitoring, analysis; noise = true)

        statusWattmeter!(monitoring; inservice = 14)
        @test sum(monitoring.wattmeter.active.status) == 14

        statusWattmeter!(monitoring; outservice = 40)
        @test sum(monitoring.wattmeter.active.status) == 10

        statusWattmeter!(monitoring; redundancy = 1.8)
        @test sum(monitoring.wattmeter.active.status) == round(1.8 * stateVariable)

        layout = monitoring.wattmeter.layout
        statusWattmeter!(monitoring; inserviceBus = 10, inserviceFrom = 12, inserviceTo = 8)
        @test sum(monitoring.wattmeter.active.status[layout.bus]) == 10
        @test sum(monitoring.wattmeter.active.status[layout.from]) == 12
        @test sum(monitoring.wattmeter.active.status[layout.to]) == 8

        statusWattmeter!(monitoring; outserviceBus = 14, outserviceFrom = 15, outserviceTo = 17)
        @test sum(monitoring.wattmeter.active.status[layout.bus]) == 0
        @test sum(monitoring.wattmeter.active.status[layout.from]) == 3
        @test sum(monitoring.wattmeter.active.status[layout.to]) == 1

        statusWattmeter!(monitoring; redundancyBus = 0.1, redundancyFrom = 0.3, redundancyTo = 0.4)
        @test sum(monitoring.wattmeter.active.status[layout.bus]) == round(0.1 * stateVariable)
        @test sum(monitoring.wattmeter.active.status[layout.from]) == round(0.3 * stateVariable)
        @test sum(monitoring.wattmeter.active.status[layout.to]) == round(0.4 * stateVariable)
    end

    @testset "Set of Varmeters" begin
        addVarmeter!(monitoring, analysis; noise = true)

        statusVarmeter!(monitoring; inservice = 1)
        @test sum(monitoring.varmeter.reactive.status) == 1

        statusVarmeter!(monitoring; outservice = 30)
        @test sum(monitoring.varmeter.reactive.status) == 20

        statusVarmeter!(monitoring; redundancy = 1.2)
        @test sum(monitoring.varmeter.reactive.status) == round(1.2 * stateVariable)

        layout = monitoring.varmeter.layout
        statusVarmeter!(monitoring; inserviceBus = 0, inserviceFrom = 18, inserviceTo = 4)
        @test sum(monitoring.varmeter.reactive.status[layout.bus]) == 0
        @test sum(monitoring.varmeter.reactive.status[layout.from]) == 18
        @test sum(monitoring.varmeter.reactive.status[layout.to]) == 4

        statusVarmeter!(monitoring; outserviceBus = 0, outserviceFrom = 10, outserviceTo = 2)
        @test sum(monitoring.varmeter.reactive.status[layout.bus]) == 14
        @test sum(monitoring.varmeter.reactive.status[layout.from]) == 8
        @test sum(monitoring.varmeter.reactive.status[layout.to]) == 16

        statusVarmeter!(monitoring; redundancyBus = 0.2, redundancyFrom = 0.1, redundancyTo = 0.3)
        @test sum(monitoring.varmeter.reactive.status[layout.bus]) == round(0.2 * stateVariable)
        @test sum(monitoring.varmeter.reactive.status[layout.from]) == round(0.1 * stateVariable)
        @test sum(monitoring.varmeter.reactive.status[layout.to]) == round(0.3 * stateVariable)
    end

    @testset "Set of PMUs" begin
        addPmu!(monitoring, analysis; noise = true)

        statusPmu!(monitoring; inservice = 10)
        @test monitoring.pmu.magnitude.status == monitoring.pmu.angle.status
        @test sum(monitoring.pmu.magnitude.status) == 10

        statusPmu!(monitoring; outservice = 40)
        @test monitoring.pmu.magnitude.status == monitoring.pmu.angle.status
        @test sum(monitoring.pmu.magnitude.status) == 10

        statusPmu!(monitoring; redundancy = 0.2)
        @test monitoring.pmu.magnitude.status == monitoring.pmu.angle.status
        @test sum(monitoring.pmu.magnitude.status) == round(0.2 * stateVariable)

        layout = monitoring.pmu.layout
        statusPmu!(monitoring; inserviceBus = 10, inserviceFrom = 15, inserviceTo = 16)
        @test monitoring.pmu.magnitude.status == monitoring.pmu.angle.status
        @test sum(monitoring.pmu.magnitude.status[layout.bus]) == 10
        @test sum(monitoring.pmu.magnitude.status[layout.from]) == 15
        @test sum(monitoring.pmu.magnitude.status[layout.to]) == 16

        statusPmu!(monitoring; outserviceBus = 6, outserviceFrom = 10, outserviceTo = 15)
        @test monitoring.pmu.magnitude.status == monitoring.pmu.angle.status
        @test sum(monitoring.pmu.magnitude.status[layout.bus]) == 8
        @test sum(monitoring.pmu.magnitude.status[layout.from]) == 8
        @test sum(monitoring.pmu.magnitude.status[layout.to]) == 3

        statusPmu!(monitoring; redundancyBus = 0.3, redundancyFrom = 0.2, redundancyTo = 0.4)
        @test monitoring.pmu.magnitude.status == monitoring.pmu.angle.status
        @test sum(monitoring.pmu.magnitude.status[layout.bus]) == round(0.3 * stateVariable)
        @test sum(monitoring.pmu.magnitude.status[layout.from]) == round(0.2 * stateVariable)
        @test sum(monitoring.pmu.magnitude.status[layout.to]) == round(0.4 * stateVariable)
    end

    @testset "Set of All Measurements" begin
        status!(monitoring; inservice = 40)
        @test monitoring.pmu.magnitude.status == monitoring.pmu.angle.status
        @test sum(monitoring.voltmeter.magnitude.status) + sum(monitoring.ammeter.magnitude.status) +
            sum(monitoring.wattmeter.active.status) + sum(monitoring.varmeter.reactive.status) +
            sum(monitoring.pmu.magnitude.status) == 40

        status!(monitoring; outservice = 100)
        @test monitoring.pmu.magnitude.status == monitoring.pmu.angle.status
        @test sum(monitoring.voltmeter.magnitude.status) + sum(monitoring.ammeter.magnitude.status) +
            sum(monitoring.wattmeter.active.status) + sum(monitoring.varmeter.reactive.status) +
            sum(monitoring.pmu.magnitude.status) == 100

        status!(monitoring; redundancy = 3.1)
        @test monitoring.pmu.magnitude.status == monitoring.pmu.angle.status
        @test sum(monitoring.voltmeter.magnitude.status) + sum(monitoring.ammeter.magnitude.status) +
            sum(monitoring.wattmeter.active.status) + sum(monitoring.varmeter.reactive.status) +
            sum(monitoring.pmu.magnitude.status) == round(3.1 * stateVariable)
    end
end

@testset "Build Measurements in Per-Units Using Macros" begin
    @default(template)
    @default(unit)

    system = powerSystem()
    monitoring = measurement(system)

    addBus!(system; label = "Bus 1")
    addBus!(system; label = "Bus 2")
    addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

    @testset "Voltmeter Macro" begin
        @voltmeter(label = "Voltmeter ?", variance = 1e-2, status = 0, noise = true)

        addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 1.0)
        @test monitoring.voltmeter.label["Voltmeter 1"] == 1
        @test monitoring.voltmeter.magnitude.mean[1] != 1.0
        @test monitoring.voltmeter.magnitude.variance[1] == 1e-2
        @test monitoring.voltmeter.magnitude.status[1] == 0

        addVoltmeter!(monitoring; bus = "Bus 2", magnitude = 2.0, variance = 1e-3, noise = false)
        @test monitoring.voltmeter.label["Voltmeter 2"] == 2
        @test monitoring.voltmeter.magnitude.mean[2] == 2.0
        @test monitoring.voltmeter.magnitude.variance[2] == 1e-3
        @test monitoring.voltmeter.magnitude.status[2] == 0

        addVoltmeter!( monitoring; bus = "Bus 2", magnitude = 2.0, status = 1)
        @test monitoring.voltmeter.label["Voltmeter 3"] == 3
        @test monitoring.voltmeter.magnitude.status[3] == 1

        @suppress print(monitoring; voltmeter = "Voltmeter 1")
    end

    @testset "Ammeter Macro" begin
        @ammeter(label = "Ammeter ?", varianceFrom = 1e-2, varianceTo = 1e-3)
        @ammeter(statusFrom = 1, statusTo = 0, noise = true)

        addAmmeter!(monitoring; from = "Branch 1", magnitude = 1.0, status = 0)
        @test monitoring.ammeter.label["Ammeter 1"] == 1
        @test monitoring.ammeter.magnitude.mean[1] != 1.0
        @test monitoring.ammeter.magnitude.variance[1] == 1e-2
        @test monitoring.ammeter.magnitude.status[1] == 0

        addAmmeter!(monitoring; from = "Branch 1", magnitude = 3.0, variance = 1e-4, noise = false)
        @test monitoring.ammeter.label["Ammeter 2"] == 2
        @test monitoring.ammeter.magnitude.mean[2] == 3.0
        @test monitoring.ammeter.magnitude.variance[2] == 1e-4
        @test monitoring.ammeter.magnitude.status[2] == 1

        addAmmeter!(monitoring; to = "Branch 1", magnitude = 2.0, status = 1)
        @test monitoring.ammeter.label["Ammeter 3"] == 3
        @test monitoring.ammeter.magnitude.mean[3] != 2.0
        @test monitoring.ammeter.magnitude.variance[3] == 1e-3
        @test monitoring.ammeter.magnitude.status[3] == 1

        addAmmeter!(monitoring; to = "Branch 1", magnitude = 4.0, variance = 1e-5, noise = false)
        @test monitoring.ammeter.label["Ammeter 4"] == 4
        @test monitoring.ammeter.magnitude.mean[4] == 4.0
        @test monitoring.ammeter.magnitude.variance[4] == 1e-5
        @test monitoring.ammeter.magnitude.status[4] == 0

        @suppress print(monitoring; ammeter = "Ammeter 1")
        @suppress print(monitoring; ammeter = "Ammeter 3")
    end

    @testset "Wattmeter Macro" begin
        @wattmeter(label = "Wattmeter ?", varianceBus = 1e-1, varianceFrom = 1e-2, varianceTo = 1e-3)
        @wattmeter(statusBus = 0, statusFrom = 1, statusTo = 0, noise = true)

        addWattmeter!(monitoring; bus = "Bus 1", active = 1.0, status = 1)
        @test monitoring.wattmeter.label["Wattmeter 1"] == 1
        @test monitoring.wattmeter.active.mean[1] != 1.0
        @test monitoring.wattmeter.active.variance[1] == 1e-1
        @test monitoring.wattmeter.active.status[1] == 1

        addWattmeter!(monitoring; bus = "Bus 1", active = 2.0, variance = 1, noise = false)
        @test monitoring.wattmeter.label["Wattmeter 2"] == 2
        @test monitoring.wattmeter.active.mean[2] == 2.0
        @test monitoring.wattmeter.active.variance[2] == 1
        @test monitoring.wattmeter.active.status[2] == 0

        addWattmeter!(monitoring; from = "Branch 1", active = 5.0, status = 0)
        @test monitoring.wattmeter.label["Wattmeter 3"] == 3
        @test monitoring.wattmeter.active.mean[3] != 5.0
        @test monitoring.wattmeter.active.variance[3] == 1e-2
        @test monitoring.wattmeter.active.status[3] == 0

        addWattmeter!(monitoring; from = "Branch 1", active = 6.0, variance = 2, noise = false)
        @test monitoring.wattmeter.label["Wattmeter 4"] == 4
        @test monitoring.wattmeter.active.mean[4] == 6.0
        @test monitoring.wattmeter.active.variance[4] == 2
        @test monitoring.wattmeter.active.status[4] == 1

        addWattmeter!(monitoring; to = "Branch 1", active = 6.0, status = 1)
        @test monitoring.wattmeter.label["Wattmeter 5"] == 5
        @test monitoring.wattmeter.active.mean[5] != 6.0
        @test monitoring.wattmeter.active.variance[5] == 1e-3
        @test monitoring.wattmeter.active.status[5] == 1

        addWattmeter!(monitoring; to = "Branch 1", active = 7.0, variance = 3, noise = false)
        @test monitoring.wattmeter.label["Wattmeter 6"] == 6
        @test monitoring.wattmeter.active.mean[6] == 7.0
        @test monitoring.wattmeter.active.variance[6] == 3
        @test monitoring.wattmeter.active.status[6] == 0

        @suppress print(monitoring; wattmeter = "Wattmeter 1")
        @suppress print(monitoring; wattmeter = "Wattmeter 3")
        @suppress print(monitoring; wattmeter = "Wattmeter 5")
    end

    @testset "Varmeter Macro" begin
        @varmeter(label = "Varmeter ?", varianceBus = 1, varianceFrom = 2)
        @varmeter(varianceTo = 3, statusBus = 1, statusFrom = 0, statusTo = 1, noise = true)

        addVarmeter!(monitoring; bus = "Bus 1", reactive = 1.1, status = 0)
        @test monitoring.varmeter.label["Varmeter 1"] == 1
        @test monitoring.varmeter.reactive.mean[1] != 1.1
        @test monitoring.varmeter.reactive.variance[1] == 1
        @test monitoring.varmeter.reactive.status[1] == 0

        addVarmeter!(monitoring; bus = "Bus 1", reactive = 2.1, variance = 10, noise = false)
        @test monitoring.varmeter.label["Varmeter 2"] == 2
        @test monitoring.varmeter.reactive.mean[2] == 2.1
        @test monitoring.varmeter.reactive.variance[2] == 10
        @test monitoring.varmeter.reactive.status[2] == 1

        addVarmeter!(monitoring; from = "Branch 1", reactive = 5.1, status = 1)
        @test monitoring.varmeter.label["Varmeter 3"] == 3
        @test monitoring.varmeter.reactive.mean[3] != 5.1
        @test monitoring.varmeter.reactive.variance[3] == 2
        @test monitoring.varmeter.reactive.status[3] == 1

        addVarmeter!(monitoring; from = "Branch 1", reactive = 6.1, variance = 20, noise = false)
        @test monitoring.varmeter.label["Varmeter 4"] == 4
        @test monitoring.varmeter.reactive.mean[4] == 6.1
        @test monitoring.varmeter.reactive.variance[4] == 20
        @test monitoring.varmeter.reactive.status[4] == 0

        addVarmeter!(monitoring; to = "Branch 1", reactive = 6.1, status = 0)
        @test monitoring.varmeter.label["Varmeter 5"] == 5
        @test monitoring.varmeter.reactive.mean[5] != 6.1
        @test monitoring.varmeter.reactive.variance[5] == 3
        @test monitoring.varmeter.reactive.status[5] == 0

        addVarmeter!(monitoring; to = "Branch 1", reactive = 7.1, variance = 30, noise = false)
        @test monitoring.varmeter.label["Varmeter 6"] == 6
        @test monitoring.varmeter.reactive.mean[6] == 7.1
        @test monitoring.varmeter.reactive.variance[6] == 30
        @test monitoring.varmeter.reactive.status[6] == 1

        @suppress print(monitoring; varmeter = "Varmeter 1")
        @suppress print(monitoring; varmeter = "Varmeter 3")
        @suppress print(monitoring; varmeter = "Varmeter 5")
    end

    @testset "PMU Macro" begin
        @pmu(label = "PMU ?", noise = true, polar = true, correlated = true)
        @pmu(varianceMagnitudeBus = 10, varianceAngleBus = 20, statusBus = 0)
        @pmu(varianceMagnitudeFrom = 30, varianceAngleFrom = 40, statusFrom = 1)
        @pmu(varianceMagnitudeTo = 50, varianceAngleTo = 60, statusTo = 0)

        addPmu!(monitoring; bus = "Bus 1", magnitude = 2, angle = 1, status = 1)
        @test monitoring.pmu.label["PMU 1"] == 1
        @test monitoring.pmu.magnitude.mean[1] != 2
        @test monitoring.pmu.magnitude.variance[1] == 10
        @test monitoring.pmu.magnitude.status[1] == 1
        @test monitoring.pmu.angle.mean[1] != 1
        @test monitoring.pmu.angle.variance[1] == 20
        @test monitoring.pmu.angle.status[1] == 1
        @test monitoring.pmu.layout.polar[1] == true
        @test monitoring.pmu.layout.correlated[1] == true

        addPmu!(
            monitoring;
            bus = "Bus 1", noise = false, polar = false, correlated = false,
            magnitude = 3, varianceMagnitude = 1e-1, angle = 4, varianceAngle = 1e-2
        )
        @test monitoring.pmu.label["PMU 2"] == 2
        @test monitoring.pmu.magnitude.mean[2] == 3
        @test monitoring.pmu.magnitude.variance[2] == 1e-1
        @test monitoring.pmu.magnitude.status[2] == 0
        @test monitoring.pmu.angle.mean[2] == 4
        @test monitoring.pmu.angle.variance[2] == 1e-2
        @test monitoring.pmu.angle.status[2] == 0
        @test monitoring.pmu.layout.polar[2] == false
        @test monitoring.pmu.layout.correlated[2] == false

        addPmu!(monitoring; from = "Branch 1", magnitude = 5, angle = 6, status = 0)
        @test monitoring.pmu.label["PMU 3"] == 3
        @test monitoring.pmu.magnitude.mean[3] != 5
        @test monitoring.pmu.magnitude.variance[3] == 30
        @test monitoring.pmu.magnitude.status[3] == 0
        @test monitoring.pmu.angle.mean[3] != 6
        @test monitoring.pmu.angle.variance[3] == 40
        @test monitoring.pmu.angle.status[3] == 0
        @test monitoring.pmu.layout.polar[3] == true
        @test monitoring.pmu.layout.correlated[3] == true

        addPmu!(
            monitoring; from = "Branch 1", noise = false, polar = false, correlated = false,
            magnitude = 7, varianceMagnitude = 2e-1, angle = 8, varianceAngle = 2e-2
        )
        @test monitoring.pmu.label["PMU 4"] == 4
        @test monitoring.pmu.magnitude.mean[4] == 7
        @test monitoring.pmu.magnitude.variance[4] == 2e-1
        @test monitoring.pmu.magnitude.status[4] == 1
        @test monitoring.pmu.angle.mean[4] == 8
        @test monitoring.pmu.angle.variance[4] == 2e-2
        @test monitoring.pmu.angle.status[4] == 1
        @test monitoring.pmu.layout.polar[4] == false
        @test monitoring.pmu.layout.correlated[4] == false

        addPmu!(monitoring; to = "Branch 1", magnitude = 500, angle = 600)
        @test monitoring.pmu.label["PMU 5"] == 5
        @test monitoring.pmu.magnitude.mean[5] != 500
        @test monitoring.pmu.magnitude.variance[5] == 50
        @test monitoring.pmu.magnitude.status[5] == 0
        @test monitoring.pmu.angle.mean[5] != 600
        @test monitoring.pmu.angle.variance[5] == 60
        @test monitoring.pmu.angle.status[5] == 0
        @test monitoring.pmu.layout.polar[5] == true
        @test monitoring.pmu.layout.correlated[5] == true

        addPmu!(
            monitoring; to = "Branch 1", noise = false, polar = false, correlated = false,
            magnitude = 9, varianceMagnitude = 3e-1, angle = 10, varianceAngle = 3e-2, status = 1
        )
        @test monitoring.pmu.label["PMU 6"] == 6
        @test monitoring.pmu.magnitude.mean[6] == 9
        @test monitoring.pmu.magnitude.variance[6] == 3e-1
        @test monitoring.pmu.magnitude.status[6] == 1
        @test monitoring.pmu.angle.mean[6] == 10
        @test monitoring.pmu.angle.variance[6] == 3e-2
        @test monitoring.pmu.angle.status[6] == 1
        @test monitoring.pmu.layout.polar[6] == false
        @test monitoring.pmu.layout.correlated[6] == false

        @suppress print(monitoring; pmu = "PMU 1")
        @suppress print(monitoring; pmu = "PMU 3")
        @suppress print(monitoring; pmu = "PMU 5")
    end
end

@testset "Build Measurements in SI Units Using Macros" begin
    @default(unit)
    @default(template)

    ########## Build Power System ##########
    @power(MW, MVAr, GVA)
    @voltage(kV, deg, kV)
    @current(A, deg)

    system = powerSystem()
    monitoring = measurement(system)
    @base(system, MVA, kV)

    addBus!(system; label = "Bus 1", base = 100)
    addBus!(system; label = "Bus 2", base = 100)
    addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

    @testset "Voltmeter Macro" begin
        @voltmeter(label = "Voltmeter ?", variance = 1 / sqrt(3))

        addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 100 / sqrt(3))
        @test monitoring.voltmeter.magnitude.mean[1] ≈ 1.0
        @test monitoring.voltmeter.magnitude.variance[1] ≈ 1e-2
    end

    @testset "Ammeter Macro" begin
        @ammeter(label = "Ammeter ?")
        @ammeter(varianceFrom = 1e-2 * ((100 * 10^6) / (sqrt(3) * 100 * 10^3)))

        addAmmeter!(monitoring; from = "Branch 1", magnitude = (100 * 10^6) / (sqrt(3) * 100 * 10^3))
        @test monitoring.ammeter.magnitude.mean[1] ≈ 1.0
        @test monitoring.ammeter.magnitude.variance[1] ≈ 1e-2
    end

    @testset "Wattmeter Macro" begin
        @wattmeter(label = "Wattmeter ?", varianceBus = 10)

        addWattmeter!(monitoring; bus = "Bus 1", active = 100)
        @test monitoring.wattmeter.active.mean[1] == 1.0
        @test monitoring.wattmeter.active.variance[1] == 1e-1
    end

    @testset "Varmeter Macro" begin
        @varmeter(label = "Varmeter ?", varianceBus = 100)

        addVarmeter!(monitoring; bus = "Bus 1", reactive = 110)
        @test monitoring.varmeter.reactive.mean[1] == 1.1
        @test monitoring.varmeter.reactive.variance[1] == 1
    end

    @testset "PMU Macro" begin
        @pmu(label = "PMU ?")
        @pmu(varianceMagnitudeBus = 1e3 / sqrt(3), varianceAngleBus = 20 * 180 / pi)
        @pmu(varianceMagnitudeFrom = 30 * ((100 * 10^6) / (sqrt(3) * 100 * 10^3)))
        @pmu(varianceAngleFrom = 40 * 180 / pi)

        addPmu!(monitoring; bus = "Bus 1", magnitude = 2e2 / sqrt(3), angle = 1 * 180 / pi)
        @test monitoring.pmu.magnitude.mean[1] ≈ 2
        @test monitoring.pmu.magnitude.variance[1] ≈ 10
        @test monitoring.pmu.angle.mean[1] == 1
        @test monitoring.pmu.angle.variance[1] == 20

        addPmu!(
            monitoring; from = "Branch 1",
            magnitude = 5 * ((100 * 10^6) / (sqrt(3) * 100 * 10^3)), angle = 6 * 180 / pi
        )
        @test monitoring.pmu.magnitude.mean[2] ≈ 5
        @test monitoring.pmu.magnitude.variance[2] ≈ 30
        @test monitoring.pmu.angle.mean[2] ≈ 6
        @test monitoring.pmu.angle.variance[2] ≈ 40
    end
end

@testset "Measurement Errors" begin
    @default(unit)
    @default(template)
    system = powerSystem()
    monitoring = measurement(system)

    addBus!(system; label = "Bus 1", type = 3)
    addBus!(system; label = "Bus 2")
    addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)
    addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.2)

    analysis = newtonRaphson(system)
    powerFlow!(analysis)

    addVoltmeter!(monitoring; label = "Volt 1", bus = "Bus 1", magnitude = 1)
    addAmmeter!(monitoring; label = "Amm 1", from = "Branch 1", magnitude = 1)
    addWattmeter!(monitoring; label = "Watt 1", from = "Branch 1", active = 1)
    addVarmeter!(monitoring; label = "Var 1", from = "Branch 1", reactive = 1)
    addPmu!(monitoring; label = "PMU 1", bus = "Bus 1", magnitude = 1, angle = 1)

    @testset "Voltmeter Errors" begin
        err = ErrorException(
            "The status 2 is not allowed; it should be in-service (1) or out-of-service (0)."
        )
        @test_throws err addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 1, status = 2)

        err = ErrorException("The label Volt 1 is not unique.")
        @test_throws err addVoltmeter!(monitoring; label = "Volt 1", bus = "Bus 1", magnitude = 1)

        @test_throws ErrorException @eval @voltmeter(label = "Voltmeter ?", means = 1)
    end

    @testset "Ammeter Errors" begin
        err = ErrorException("The label Amm 1 is not unique.")
        @test_throws err addAmmeter!(monitoring; label = "Amm 1", from = "Branch 1", magnitude = 1)

        err = ErrorException("At least one of the location keywords must be provided.")
        @test_throws err addAmmeter!(monitoring; label = "Ammeter 1", magnitude = 1)

        err = ErrorException("Concurrent location keyword definition is not allowed.")
        @test_throws err addAmmeter!(monitoring; from = "Branch 1", to = "Branch 1", magnitude = 1)

        err = ErrorException("The current values are missing.")
        @test_throws err addAmmeter!(monitoring, analysis)

        @test_throws ErrorException @eval @ammeter(label = "Ammeter ?", means = 1)
    end

    @testset "Wattmeter Errors" begin
        err = ErrorException("The label Watt 1 is not unique.")
        @test_throws err addWattmeter!(monitoring; label = "Watt 1", from = "Branch 1", active = 1)

        err = ErrorException("Concurrent location keyword definition is not allowed.")
        @test_throws err addWattmeter!(monitoring; from = "Branch 1", to = "Branch 1", active = 1)

        err = ErrorException("At least one of the location keywords must be provided.")
        @test_throws err addWattmeter!(monitoring; label = "Wattmeter 1", active = 1)

        err = ErrorException("The power values are missing.")
        @test_throws err addWattmeter!(monitoring, analysis)

        @test_throws ErrorException @eval @wattmeter(label = "Wattmeter ?", means = 1)
    end

    @testset "Varmeter Errors" begin
        err = ErrorException("The label Var 1 is not unique.")
        @test_throws err addVarmeter!(monitoring; label = "Var 1", from = "Branch 1", reactive = 1)

        err = ErrorException("Concurrent location keyword definition is not allowed.")
        @test_throws err addVarmeter!(monitoring; from = "Branch 1", to = "Branch 1", bus = "Bus 1", reactive = 1)

        err = ErrorException("The power values are missing.")
        @test_throws err addVarmeter!(monitoring, analysis)

        @test_throws ErrorException @eval @varmeter(label = "Varmeter ?", means = 1)
    end

    @testset "PMU Errors" begin
        err = ErrorException("The label PMU 1 is not unique.")
        @test_throws err addPmu!(monitoring; label = "PMU 1", bus = "Bus 1", magnitude = 1, angle = 1)

        err = ErrorException("The current values are missing.")
        @test_throws err addPmu!( monitoring, analysis)

        @test_throws ErrorException @eval @pmu(label = "PMU ?", means = 1)
    end

    @testset "Configuration Errors" begin
        err = ErrorException(
            "The total number of available devices is less than the " *
            "requested number for a status change."
        )
        @test_throws err status!(monitoring; inservice = 12)
        @test_throws err statusVoltmeter!(monitoring; inservice = 12)
        @test_throws err statusPmu!(monitoring; inservice = 12)
        @test_throws err statusAmmeter!(monitoring; inserviceFrom = 12)
        @test_throws err statusPmu!(monitoring; inserviceBus = 12)
    end

    @testset "Load Errors" begin
        err = DomainError(".m", "The extension .m is not supported.")
        @test_throws err measurement(system, "case14.m")
    end
end