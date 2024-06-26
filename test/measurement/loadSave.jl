@testset "Load and Save Measurement Data" begin
    system = powerSystem(string(pathData, "case14test.m"))
    device = measurement()

    @voltmeter(label = "Voltmeter ?")
    addVoltmeter!(system, device; bus = 1, magnitude = 1.1, noise = true, status = 0)
    addVoltmeter!(system, device; bus = 14, magnitude = 1.0, variance = 1e-4)

    addAmmeter!(system, device; from = 10, magnitude = 0.2, variance = 1e-5)
    addAmmeter!(system, device; to = 10, magnitude = 0.1, status = 0, noise = true)

    @wattmeter(label = "Wattmeter ?: !", statusBus = 0, varianceFrom = 1e-5, noise = true)
    addWattmeter!(system, device; bus = 3, active = 1.1, status = 1)
    addWattmeter!(system, device; from = 14, active = 1.0, variance = 1e-4, noise = true)
    addWattmeter!(system, device; to = 2, active = 0.8, status = 0, noise = true)

    @varmeter(statusFrom = 0, varianceBus = 1e-5)
    addVarmeter!(system, device; bus = 4, reactive = 0.6,status = 1)
    addVarmeter!(system, device; from = 14, reactive = 1.2, variance = 1e-4, noise = true)
    addVarmeter!(system, device; to = 2, reactive = 0.1, status = 0, noise = true)

    @pmu(label = "!", statusAngleTo = 0, varianceMagnitudeTo = 1e-3)
    addPmu!(system, device; bus = 9, magnitude = 1.6, angle = -0.1, statusAngle = 1, polar = true)
    addPmu!(system, device; from = 14, magnitude = 1.2, angle = -0.2, varianceMagnitude = 1e-4, polar = false, noise = true)
    addPmu!(system, device; to = 19, magnitude = 0.3, angle = 0.1, statusMagnitude = 0, correlated = true, noise = true, polar = true)

    saveMeasurement(device; path = string(pathData, "measurement14.h5"))
    deviceLoad = measurement(string(pathData, "measurement14.h5"))

    ####### Test Voltmeter Data #######
    @test device.voltmeter.label == deviceLoad.voltmeter.label
    @test device.voltmeter.number == deviceLoad.voltmeter.number
    equalStruct(device.voltmeter.magnitude, deviceLoad.voltmeter.magnitude)
    equalStruct(device.voltmeter.layout, deviceLoad.voltmeter.layout)

    ####### Test Ammeter Data #######
    @test device.ammeter.label == deviceLoad.ammeter.label
    @test device.ammeter.number == deviceLoad.ammeter.number
    equalStruct(device.ammeter.magnitude, deviceLoad.ammeter.magnitude)
    equalStruct(device.ammeter.layout, deviceLoad.ammeter.layout)

    ####### Test Wattmeter Data #######
    @test device.wattmeter.label == deviceLoad.wattmeter.label
    @test device.wattmeter.number == deviceLoad.wattmeter.number
    equalStruct(device.wattmeter.active, deviceLoad.wattmeter.active)
    equalStruct(device.wattmeter.layout, deviceLoad.wattmeter.layout)

    ####### Test Varmeter Data #######
    @test device.varmeter.label == deviceLoad.varmeter.label
    @test device.varmeter.number == deviceLoad.varmeter.number
    equalStruct(device.varmeter.reactive, deviceLoad.varmeter.reactive)
    equalStruct(device.varmeter.layout, deviceLoad.varmeter.layout)

    ####### Test PMU Data #######
    @test device.pmu.label == deviceLoad.pmu.label
    @test device.pmu.number == deviceLoad.pmu.number
    equalStruct(device.pmu.magnitude, deviceLoad.pmu.magnitude)
    equalStruct(device.pmu.angle, deviceLoad.pmu.angle)
    equalStruct(device.pmu.layout, deviceLoad.pmu.layout)
end