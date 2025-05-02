
@testset "Reusing AC State Estimation" begin
    @default(template)
    @default(unit)
    @config(label = Integer)

    ############ IEEE 14-bus Test Case ############
    system = powerSystem(path * "case14test.m")

    acModel!(system)
    pf = newtonRaphson(system)
    powerFlow!(pf)

    @pmu(varianceMagnitudeBus = 1, varianceAngleBus = 1)
    monitoring = measurement(system)

    addVoltmeter!(monitoring; label = 1, bus = 1, magnitude = 1.06)

    addAmmeter!(monitoring; label = 1, from = 2, magnitude = 0.97)
    addAmmeter!(monitoring; label = 2, to = 4, magnitude = 1.18)

    addWattmeter!(monitoring; label = 1, bus = 3, active = -0.94)
    addWattmeter!(monitoring; label = 2, from = 10, active = 0.29)
    addWattmeter!(monitoring; label = 3, to = 13, active = -0.16)

    addVarmeter!(monitoring; label = 1, bus = 10, reactive = -0.06)
    addVarmeter!(monitoring; label = 2, from = 4, reactive = 0.22)
    addVarmeter!(monitoring; label = 3, to = 6, reactive = -0.62)

    addPmu!(monitoring, pf; statusFrom = -1, statusTo = -1, polar = true)
    addPmu!(monitoring; label = 15, bus = 2, magnitude = 1.045, angle = -0.075, polar = false)
    addPmu!(monitoring; label = 16, from = 10, magnitude = 0.30, angle = -0.07, polar = true)
    addPmu!(monitoring; label = 17, from = 10, magnitude = 0.30, angle = -0.07, polar = false)
    addPmu!(monitoring; label = 18, to = 2, magnitude = 0.98, angle = 2.92, polar = true)
    addPmu!(monitoring; label = 19, to = 2, magnitude = 0.98, angle = 2.92, polar = false)

    wls = gaussNewton(monitoring)
    lav = acLavStateEstimation(monitoring, Ipopt.Optimizer)

    @testset "Voltmeter" begin
        updateVoltmeter!(wls; label = 1, magnitude = 2.6, variance = 1e30)
        updateVoltmeter!(lav; label = 1, magnitude = 2.6, variance = 1e30)
        testReusing(monitoring, wls, lav, 1)

        updateVoltmeter!(wls; label = 1, variance = 1e-4, status = 0)
        updateVoltmeter!(lav; label = 1, status = 0)
        testReusing(monitoring, wls, lav, 1)

        updateVoltmeter!(wls; label = 1, magnitude = 1.06, status = 1)
        updateVoltmeter!(lav; label = 1, magnitude = 1.06, status = 1)
        testReusing(monitoring, wls, lav, 1)

        updateVoltmeter!(monitoring; label = 1, magnitude = 1.07, status = 0)
        updateVoltmeter!(wls; label = 1)
        updateVoltmeter!(lav; label = 1)
        testReusing(monitoring, wls, lav, 1)

        updateVoltmeter!(monitoring; label = 1, status = 1)
        updateVoltmeter!(wls; label = 1, variance = 1e-3)
        updateVoltmeter!(lav; label = 1)
        testReusing(monitoring, wls, lav, 1)
    end

    @testset "From-Bus Ammeter" begin
        updateAmmeter!(wls; label = 1, magnitude = 3.0, variance = 1e30)
        updateAmmeter!(lav; label = 1, magnitude = 3.0, variance = 1e30)
        testReusing(monitoring, wls, lav, 2)

        updateAmmeter!(wls; label = 1, variance = 1e-3, status = 0)
        updateAmmeter!(lav; label = 1, magnitude = 4.2, status = 0)
        testReusing(monitoring, wls, lav, 2)

        updateAmmeter!(wls; label = 1, magnitude = 0.97, status = 1)
        updateAmmeter!(lav; label = 1, magnitude = 0.97, status = 1)
        testReusing(monitoring, wls, lav, 2)

        updateAmmeter!(wls; label = 1, square = true)
        updateAmmeter!(lav; label = 1, square = true)
        testReusing(monitoring, wls, lav, 2)

        updateAmmeter!(wls; label = 1, square = false)
        updateAmmeter!(lav; label = 1, square = false)
        testReusing(monitoring, wls, lav, 2)

        updateAmmeter!(monitoring; label = 1, variance = 1e-4)
        updateAmmeter!(wls; label = 1, square = true)
        updateAmmeter!(lav; label = 1, square = true)
        testReusing(monitoring, wls, lav, 2)

        updateAmmeter!(monitoring; label = 1, square = false, status = 0)
        updateAmmeter!(wls; label = 1, magnitude = 3.5)
        updateAmmeter!(lav; label = 1, magnitude = 3.5)
        testReusing(monitoring, wls, lav, 2)

        updateAmmeter!(monitoring; label = 1, magnitude = 0.98)
        updateAmmeter!(wls; label = 1, status = 1)
        updateAmmeter!(lav; label = 1)
        testReusing(monitoring, wls, lav, 2)
    end

    @testset "To-Bus Ammeter" begin
        updateAmmeter!(wls; label = 2, magnitude = 4.0, variance = 1e40)
        updateAmmeter!(lav; label = 2, magnitude = 4.0, variance = 1e40)
        testReusing(monitoring, wls, lav, 3)

        updateAmmeter!(wls; label = 2, variance = 1e-4, status = 0)
        updateAmmeter!(lav; label = 2, variance = 1e-4, status = 0)
        testReusing(monitoring, wls, lav, 3)

        updateAmmeter!(wls; label = 2, magnitude = 1.18, status = 1)
        updateAmmeter!(lav; label = 2, magnitude = 1.18, status = 1)
        testReusing(monitoring, wls, lav, 3)

        updateAmmeter!(wls; label = 2, square = true)
        updateAmmeter!(lav; label = 2, square = true)
        testReusing(monitoring, wls, lav, 3)

        updateAmmeter!(wls; label = 2, square = false)
        updateAmmeter!(lav; label = 2, square = false)
        testReusing(monitoring, wls, lav, 3)

        updateAmmeter!(monitoring; label = 2, square = true)
        updateAmmeter!(wls; label = 2, variance = 1e-3)
        updateAmmeter!(lav; label = 2, status = 1)
        testReusing(monitoring, wls, lav, 3)

        updateAmmeter!(monitoring; label = 2, square = false, status = 0)
        updateAmmeter!(wls; label = 2, magnitude = 3.5)
        updateAmmeter!(lav; label = 2, magnitude = 3.5)
        testReusing(monitoring, wls, lav, 3)

        updateAmmeter!(monitoring; label = 2, magnitude = 1.19)
        updateAmmeter!(wls; label = 2, status = 1)
        updateAmmeter!(lav; label = 2, status = 1)
        testReusing(monitoring, wls, lav, 3)
    end

    @testset "Bus Wattmeter" begin
        updateWattmeter!(wls; label = 1, active = 5.3, variance = 1e45)
        updateWattmeter!(lav; label = 1, active = 5.3, variance = 1e45)
        testReusing(monitoring, wls, lav, 4)

        updateWattmeter!(wls; label = 1, variance = 1e-4, status = 0)
        updateWattmeter!(lav; label = 1, variance = 1e-4, status = 0)
        testReusing(monitoring, wls, lav, 4)

        updateWattmeter!(wls; label = 1, active = -0.94, status = 1)
        updateWattmeter!(lav; label = 1, active = -0.94, status = 1)
        testReusing(monitoring, wls, lav, 4)

        updateWattmeter!(monitoring; label = 1, active = 6.9)
        updateWattmeter!(wls; label = 1, status = 0)
        updateWattmeter!(lav; label = 1, status = 0)
        testReusing(monitoring, wls, lav, 4)

        updateWattmeter!(monitoring; label = 1, active = -0.95)
        updateWattmeter!(wls; label = 1, status = 1)
        updateWattmeter!(lav; label = 1, status = 1)
        testReusing(monitoring, wls, lav, 4)
    end

    @testset "From-Bus Wattmeter" begin
        updateWattmeter!(wls; label = 2, active = 2.3, variance = 1e35)
        updateWattmeter!(lav; label = 2, active = 2.3, variance = 1e35)
        testReusing(monitoring, wls, lav, 5)

        updateWattmeter!(wls; label = 2, variance = 1e-6, status = 0)
        updateWattmeter!(lav; label = 2, variance = 1e-6, status = 0)
        testReusing(monitoring, wls, lav, 5)

        updateWattmeter!(wls; label = 2, active = 0.29, status = 1)
        updateWattmeter!(lav; label = 2, active = 0.29, status = 1)
        testReusing(monitoring, wls, lav, 5)

        updateWattmeter!(monitoring; label = 2, status = 0)
        updateWattmeter!(wls; label = 2, active = 6.9)
        updateWattmeter!(lav; label = 2, active = 6.9)
        testReusing(monitoring, wls, lav, 5)

        updateWattmeter!(monitoring; label = 2, active = 0.3, variance = 1e-3)
        updateWattmeter!(wls; label = 2, status = 1)
        updateWattmeter!(lav; label = 2, status = 1)
        testReusing(monitoring, wls, lav, 5)
    end

    @testset "To-Bus Wattmeter" begin
        updateWattmeter!(wls; label = 3, active = 1.2, variance = 1e30)
        updateWattmeter!(lav; label = 3, active = 1.2, variance = 1e30)
        testReusing(monitoring, wls, lav, 6)

        updateWattmeter!(wls; label = 3, variance = 1e-5, status = 0)
        updateWattmeter!(lav; label = 3, variance = 1e-5, status = 0)
        testReusing(monitoring, wls, lav, 6)

        updateWattmeter!(wls; label = 3, active = -0.16, status = 1)
        updateWattmeter!(lav; label = 3, active = -0.16, status = 1)
        testReusing(monitoring, wls, lav, 6)

        updateWattmeter!(monitoring; label = 3, active = 6.9)
        updateWattmeter!(wls; label = 3, status = 0)
        updateWattmeter!(lav; label = 3, status = 0)
        testReusing(monitoring, wls, lav, 6)

        updateWattmeter!(monitoring; label = 3, active = -0.15, status = 1)
        updateWattmeter!(wls; label = 3, variance = 1e-3)
        updateWattmeter!(lav; label = 3, variance = 1e-3)
        testReusing(monitoring, wls, lav, 6)
    end

    @testset "Bus Varmeter" begin
        updateVarmeter!(wls; label = 1, reactive = 1.0, variance = 1e40)
        updateVarmeter!(lav; label = 1, reactive = 1.0, variance = 1e40)
        testReusing(monitoring, wls, lav, 7)

        updateVarmeter!(wls; label = 1, variance = 1e-3, status = 0)
        updateVarmeter!(lav; label = 1, variance = 1e-3, status = 0)
        testReusing(monitoring, wls, lav, 7)

        updateVarmeter!(wls; label = 1, reactive = -0.06, status = 1)
        updateVarmeter!(lav; label = 1, reactive = -0.06, status = 1)
        testReusing(monitoring, wls, lav, 7)

        updateVarmeter!(monitoring; label = 1, status = 0)
        updateVarmeter!(wls; label = 1, reactive = 3.9)
        updateVarmeter!(lav; label = 1, reactive = 3.9)
        testReusing(monitoring, wls, lav, 7)

        updateVarmeter!(monitoring; label = 1, status = 1)
        updateVarmeter!(wls; label = 1, reactive = -0.07)
        updateVarmeter!(lav; label = 1, reactive = -0.07)
        testReusing(monitoring, wls, lav, 7)
    end

    @testset "From-Bus Varmeter" begin
        updateVarmeter!(wls; label = 2, reactive = 4.0, variance = 1e30)
        updateVarmeter!(lav; label = 2, reactive = 4.0, variance = 1e30)
        testReusing(monitoring, wls, lav, 8)

        updateVarmeter!(wls; label = 2, variance = 1e-5, status = 0)
        updateVarmeter!(lav; label = 2, variance = 1e-5, status = 0)
        testReusing(monitoring, wls, lav, 8)

        updateVarmeter!(wls; label = 2, reactive = 0.22, status = 1)
        updateVarmeter!(lav; label = 2, reactive = 0.22, status = 1)
        testReusing(monitoring, wls, lav, 8)

        updateVarmeter!(monitoring; label = 2, reactive = 8.9, status = 0)
        updateVarmeter!(wls; label = 2)
        updateVarmeter!(lav; label = 2)
        testReusing(monitoring, wls, lav, 8)

        updateVarmeter!(monitoring; label = 2, reactive = 0.23)
        updateVarmeter!(wls; label = 2, status = 1)
        updateVarmeter!(lav; label = 2, status = 1)
        testReusing(monitoring, wls, lav, 8)
    end

    @testset "To-Bus Varmeter" begin
        updateVarmeter!(wls; label = 3, reactive = 2.0, variance = 1e30)
        updateVarmeter!(lav; label = 3, reactive = 2.0, variance = 1e30)
        testReusing(monitoring, wls, lav, 9)

        updateVarmeter!(wls; label = 3, variance = 1e-6, status = 0)
        updateVarmeter!(lav; label = 3, variance = 1e-6, status = 0)
        testReusing(monitoring, wls, lav, 9)

        updateVarmeter!(wls; label = 3, reactive = -0.62, status = 1)
        updateVarmeter!(lav; label = 3, reactive = -0.62, status = 1)
        testReusing(monitoring, wls, lav, 9)

        updateVarmeter!(monitoring; label = 3, status = 0)
        updateVarmeter!(wls; label = 3, reactive = 8.9)
        updateVarmeter!(lav; label = 3, reactive = 8.9)
        testReusing(monitoring, wls, lav, 9)

        updateVarmeter!(monitoring; label = 3, reactive = -0.63, variance = 1e-4)
        updateVarmeter!(wls; label = 3, reactive = -0.64, status = 1)
        updateVarmeter!(lav; label = 3, reactive = -0.64)
        testReusing(monitoring, wls, lav, 9)
    end

    @testset "Bus Polar PMU" begin
        updatePmu!(wls; label = 2, magnitude = 2.3, angle = 2.1, varianceMagnitude = 1e35)
        updatePmu!(lav; label = 2, magnitude = 2.3, angle = 2.1, varianceMagnitude = 1e35)
        testReusing(monitoring, wls, lav, 12; pmu = true)

        updatePmu!(wls; label = 2, varianceMagnitude = 1e-2, varianceAngle = 1e-1, status = 0)
        updatePmu!(lav; label = 2, status = 0)
        testReusing(monitoring, wls, lav, 12; pmu = true)

        updatePmu!(wls; label = 2, magnitude = 1.045, angle = -0.075, status = 1)
        updatePmu!(lav; label = 2, magnitude = 1.045, angle = -0.075, status = 1)
        testReusing(monitoring, wls, lav, 12; pmu = true)

        updatePmu!(wls; label = 2, polar = false)
        updatePmu!(lav; label = 2, polar = false)
        testReusing(monitoring, wls, lav, 12; pmu = true)

        updatePmu!(wls; label = 2, correlated = true)
        testReusing(monitoring, wls, lav, 12; pmu = true)

        updatePmu!(wls; label = 2, polar = true)
        updatePmu!(lav; label = 2, polar = true)
        testReusing(monitoring, wls, lav, 12; pmu = true)

        updatePmu!(wls; label = 2, polar = false, correlated = true)
        updatePmu!(lav; label = 2, polar = false)
        testReusing(monitoring, wls, lav, 12; pmu = true)

        updatePmu!(monitoring; label = 2, polar = true)
        updatePmu!(wls; label = 2, status = 0)
        updatePmu!(lav; label = 2, status = 0)
        testReusing(monitoring, wls, lav, 12; pmu = true)

        updatePmu!(monitoring; label = 2, status = 1)
        updatePmu!(wls; label = 2)
        updatePmu!(lav; label = 2)
        testReusing(monitoring, wls, lav, 12; pmu = true)

        updatePmu!(monitoring; label = 2, polar = false)
        updatePmu!(wls; label = 2, correlated = true)
        updatePmu!(lav; label = 2, status = 1)
        testReusing(monitoring, wls, lav, 12; pmu = true)
    end

    @testset "Bus Rectangular PMU" begin
        updatePmu!(wls; label = 15, magnitude = 2.3, angle = 2.1, varianceAngle = 1e35)
        updatePmu!(lav; label = 15, magnitude = 2.3, angle = 2.1, varianceAngle = 1e35)
        testReusing(monitoring, wls, lav, 38; pmu = true)

        updatePmu!(wls; label = 15, varianceMagnitude = 1e-2, varianceAngle = 1e-1, status = 0)
        updatePmu!(lav; label = 15, status = 0)
        testReusing(monitoring, wls, lav, 38; pmu = true)

        updatePmu!(wls; label = 15, magnitude = 1.045, angle = -0.075, status = 1, correlated = true)
        updatePmu!(lav; label = 15, magnitude = 1.045, angle = -0.075, status = 1)
        testReusing(monitoring, wls, lav, 38; pmu = true)

        updatePmu!(wls; label = 15, polar = true)
        updatePmu!(lav; label = 15, polar = true)
        testReusing(monitoring, wls, lav, 38; pmu = true)

        updatePmu!(wls; label = 15, polar = false, correlated = false)
        updatePmu!(lav; label = 15, polar = false)
        testReusing(monitoring, wls, lav, 38; pmu = true)

        updatePmu!(monitoring; label = 15, status = 0)
        updatePmu!(wls; label = 15)
        updatePmu!(lav; label = 15)
        testReusing(monitoring, wls, lav, 38; pmu = true)
    end

    @testset "From-Bus Polar PMU" begin
        updatePmu!(wls; label = 16, magnitude = 8.3, angle = 6.1, varianceMagnitude = 1e36)
        updatePmu!(lav; label = 16, magnitude = 8.3, angle = 6.1, varianceMagnitude = 1e36)
        testReusing(monitoring, wls, lav, 40; pmu = true)

        updatePmu!(wls; label = 16, varianceMagnitude = 1e-3, varianceAngle = 1e-2, status = 0)
        updatePmu!(lav; label = 16, status = 0)
        testReusing(monitoring, wls, lav, 40; pmu = true)

        updatePmu!(wls; label = 16, magnitude = 0.3, angle = -0.07, status = 1)
        updatePmu!(lav; label = 16, magnitude = 0.3, angle = -0.07, status = 1)
        testReusing(monitoring, wls, lav, 40; pmu = true)

        updatePmu!(wls; label = 16, square = true)
        updatePmu!(lav; label = 16, square = true)
        testReusing(monitoring, wls, lav, 40; pmu = true)

        updatePmu!(wls; label = 16, polar = false)
        updatePmu!(lav; label = 16, polar = false)
        testReusing(monitoring, wls, lav, 40; pmu = true)

        updatePmu!(wls; label = 16, correlated = true)
        testReusing(monitoring, wls, lav, 40; pmu = true)

        updatePmu!(wls; label = 16, polar = true, square = false)
        updatePmu!(lav; label = 16, polar = true, square = false)
        testReusing(monitoring, wls, lav, 40; pmu = true)

        updatePmu!(wls; label = 16, polar = false, correlated = true)
        updatePmu!(lav; label = 16, polar = false, correlated = true)
        testReusing(monitoring, wls, lav, 40; pmu = true)

        updatePmu!(monitoring; label = 16, status = 0)
        updatePmu!(wls; label = 16)
        updatePmu!(lav; label = 16)
        testReusing(monitoring, wls, lav, 40; pmu = true)

        updatePmu!(monitoring; label = 16, polar = true, status = 1)
        updatePmu!(wls; label = 16, correlated = true)
        updatePmu!(lav; label = 16)
        testReusing(monitoring, wls, lav, 40; pmu = true)
    end

    @testset "From-Bus Rectangular PMU" begin
        updatePmu!(wls; label = 17, magnitude = 4.3, angle = 1.1, varianceMagnitude = 1e30)
        updatePmu!(lav; label = 17, magnitude = 4.3, angle = 1.1, varianceMagnitude = 1e30)
        testReusing(monitoring, wls, lav, 42; pmu = true)

        updatePmu!(wls; label = 17, varianceMagnitude = 1e-2, varianceAngle = 1e-1, status = 0)
        updatePmu!(lav; label = 17, status = 0)
        testReusing(monitoring, wls, lav, 42; pmu = true)

        updatePmu!(wls; label = 17, magnitude = 0.3, angle = -0.07, status = 1, correlated = true)
        updatePmu!(lav; label = 17, magnitude = 0.3, angle = -0.07, status = 1)
        testReusing(monitoring, wls, lav, 42; pmu = true)

        updatePmu!(wls; label = 17, polar = true)
        updatePmu!(lav; label = 17, polar = true)
        testReusing(monitoring, wls, lav, 42; pmu = true)

        updatePmu!(wls; label = 17, polar = false)
        updatePmu!(lav; label = 17, polar = false)
        testReusing(monitoring, wls, lav, 42; pmu = true)
    end

    @testset "To-Bus Polar PMU" begin
        updatePmu!(wls; label = 18, magnitude = 8.3, angle = 6.1, varianceMagnitude = 1e36)
        updatePmu!(lav; label = 18, magnitude = 8.3, angle = 6.1, varianceMagnitude = 1e36)
        testReusing(monitoring, wls, lav, 44; pmu = true)

        updatePmu!(wls; label = 18, varianceMagnitude = 1e-3, varianceAngle = 1e-2, status = 0)
        updatePmu!(lav; label = 18, status = 0)
        testReusing(monitoring, wls, lav, 44; pmu = true)

        updatePmu!(wls; label = 18, magnitude = 0.98, angle = 2.92, status = 1)
        updatePmu!(lav; label = 18, magnitude = 0.98, angle = 2.92, status = 1)
        testReusing(monitoring, wls, lav, 44; pmu = true)

        updatePmu!(wls; label = 18, square = true)
        updatePmu!(lav; label = 18, square = true)
        testReusing(monitoring, wls, lav, 44; pmu = true)

        updatePmu!(wls; label = 18, polar = false)
        updatePmu!(lav; label = 18, polar = false)
        testReusing(monitoring, wls, lav, 44; pmu = true)

        updatePmu!(wls; label = 18, correlated = true)
        testReusing(monitoring, wls, lav, 44; pmu = true)

        updatePmu!(wls; label = 18, polar = true, square = false)
        updatePmu!(lav; label = 18, polar = true, square = false)
        testReusing(monitoring, wls, lav, 44; pmu = true)

        updatePmu!(wls; label = 18, polar = false, correlated = true)
        updatePmu!(lav; label = 18, polar = false, correlated = true)
        testReusing(monitoring, wls, lav, 44; pmu = true)

        updatePmu!(monitoring; label = 18, status = 0)
        updatePmu!(wls; label = 18)
        updatePmu!(lav; label = 18)
        testReusing(monitoring, wls, lav, 44; pmu = true)

        updatePmu!(monitoring; label = 18, polar = true, status = 1)
        updatePmu!(wls; label = 18, correlated = true)
        updatePmu!(lav; label = 18)
        testReusing(monitoring, wls, lav, 44; pmu = true)
    end

    @testset "To-Bus Rectangular PMU" begin
        updatePmu!(wls; label = 19, magnitude = 4.3, angle = 1.1, varianceMagnitude = 1e30)
        updatePmu!(lav; label = 19, magnitude = 4.3, angle = 1.1, varianceMagnitude = 1e30)
        testReusing(monitoring, wls, lav, 46; pmu = true)

        updatePmu!(wls; label = 19, varianceMagnitude = 1e-2, varianceAngle = 1e-1, status = 0)
        updatePmu!(lav; label = 19, status = 0)
        testReusing(monitoring, wls, lav, 46; pmu = true)

        updatePmu!(wls; label = 19, magnitude = 0.98, angle = 2.92, status = 1, correlated = true)
        updatePmu!(lav; label = 19, magnitude = 0.98, angle = 2.92, status = 1)
        testReusing(monitoring, wls, lav, 46; pmu = true)

        updatePmu!(wls; label = 19, polar = true)
        updatePmu!(lav; label = 19, polar = true)
        testReusing(monitoring, wls, lav, 46; pmu = true)

        updatePmu!(wls; label = 19, polar = false)
        updatePmu!(lav; label = 19, polar = false)
        testReusing(monitoring, wls, lav, 46; pmu = true)
    end
end

@testset "Reusing Meters PMU State Estimation" begin
    @default(template)
    @default(unit)
    @config(label = Integer)

    ############ IEEE 14-bus Test Case ############
    system = powerSystem(path * "case14test.m")

    acModel!(system)
    pf = newtonRaphson(system)
    powerFlow!(pf)

    @pmu(varianceMagnitudeBus = 1, varianceAngleBus = 1)
    monitoring = measurement(system)

    addPmu!(monitoring, pf; statusFrom = -1, statusTo = -1)
    addPmu!(monitoring; label = 15, bus = 2, magnitude = 1.045, angle = -0.07)
    addPmu!(monitoring; label = 16, bus = 2, magnitude = 1.045, angle = -0.07)
    addPmu!(monitoring; label = 17, from = 10, magnitude = 0.30, angle = -0.07)
    addPmu!(monitoring; label = 18, to = 2, magnitude = 0.98, angle = 2.92)

    wls = pmuStateEstimation(monitoring)
    lav = pmuLavStateEstimation(monitoring, Ipopt.Optimizer)

    @testset "Bus PMU" begin
        updatePmu!(wls; label = 16, magnitude = 2.3, angle = 2.1, varianceMagnitude = 1e35)
        updatePmu!(lav; label = 16, magnitude = 2.3, angle = 2.1)
        testReusing(monitoring, wls, lav, 31)

        updatePmu!(wls; label = 16, varianceMagnitude = 1e-2, varianceAngle = 1e-3, status = 0)
        updatePmu!(lav; label = 16, status = 0)
        testReusing(monitoring, wls, lav, 31)

        updatePmu!(wls; label = 16, magnitude = 1.045, angle = -0.07, status = 1)
        updatePmu!(lav; label = 16, magnitude = 1.045, angle = -0.07, status = 1)
        testReusing(monitoring, wls, lav, 31)

        updatePmu!(wls; label = 16, correlated = true)
        testReusing(monitoring, wls, lav, 31)

        updatePmu!(wls; label = 16, status = 0)
        updatePmu!(lav; label = 16, status = 0)
        testReusing(monitoring, wls, lav, 31)

        updatePmu!(wls; label = 16, status = 1, correlated = false)
        updatePmu!(lav; label = 16, status = 1)
        testReusing(monitoring, wls, lav, 31)

        updatePmu!(monitoring; label = 16, status = 0)
        updatePmu!(wls; label = 16)
        updatePmu!(lav; label = 16)
        testReusing(monitoring, wls, lav, 31)

        updatePmu!(monitoring; label = 16, status = 1)
        updatePmu!(wls; label = 16)
        updatePmu!(lav; label = 16)
        testReusing(monitoring, wls, lav, 31)
    end

    @testset "From-Bus PMU" begin
        updatePmu!(wls; label = 17, magnitude = 3.3, angle = 4.1, varianceAngle = 1e30)
        updatePmu!(lav; label = 17, magnitude = 3.3, angle = 4.1)
        testReusing(monitoring, wls, lav, 33)

        updatePmu!(wls; label = 17, varianceMagnitude = 1e-3, varianceAngle = 1e-4, status = 0)
        updatePmu!(lav; label = 17, status = 0)
        testReusing(monitoring, wls, lav, 33)

        updatePmu!(wls; label = 17, magnitude = 0.30, angle = -0.07, status = 1)
        updatePmu!(lav; label = 17, magnitude = 0.30, angle = -0.07, status = 1)
        testReusing(monitoring, wls, lav, 33)

        updatePmu!(wls; label = 17, correlated = true)
        testReusing(monitoring, wls, lav, 33)

        updatePmu!(wls; label = 17, status = 0)
        updatePmu!(lav; label = 17, status = 0)
        testReusing(monitoring, wls, lav, 33)

        updatePmu!(wls; label = 17, status = 1, correlated = false)
        updatePmu!(lav; label = 17, status = 1)
        testReusing(monitoring, wls, lav, 33)

        updatePmu!(monitoring; label = 17, status = 0)
        updatePmu!(wls; label = 17)
        updatePmu!(lav; label = 17)
        testReusing(monitoring, wls, lav, 33)

        updatePmu!(monitoring; label = 17, status = 1)
        updatePmu!(wls; label = 17)
        updatePmu!(lav; label = 17)
        testReusing(monitoring, wls, lav, 33)
    end

    @testset "To-Bus PMU" begin
        updatePmu!(wls; label = 18, magnitude = 3.3, angle = 4.1, varianceAngle = 1e30)
        updatePmu!(lav; label = 18, magnitude = 3.3, angle = 4.1)
        testReusing(monitoring, wls, lav, 35)

        updatePmu!(wls; label = 18, varianceMagnitude = 1e-3, varianceAngle = 1e-4, status = 0)
        updatePmu!(lav; label = 18, status = 0)
        testReusing(monitoring, wls, lav, 35)

        updatePmu!(wls; label = 18, magnitude = 0.30, angle = -0.07, status = 1)
        updatePmu!(lav; label = 18, magnitude = 0.30, angle = -0.07, status = 1)
        testReusing(monitoring, wls, lav, 35)

        updatePmu!(wls; label = 18, correlated = true)
        testReusing(monitoring, wls, lav, 35)

        updatePmu!(wls; label = 18, status = 0)
        updatePmu!(lav; label = 18, status = 0)
        testReusing(monitoring, wls, lav, 35)

        updatePmu!(wls; label = 18, status = 1, correlated = false)
        updatePmu!(lav; label = 18, status = 1)
        testReusing(monitoring, wls, lav, 35)

        updatePmu!(monitoring; label = 18, status = 0)
        updatePmu!(wls; label = 18)
        updatePmu!(lav; label = 18)
        testReusing(monitoring, wls, lav, 35)

        updatePmu!(monitoring; label = 18, status = 1)
        updatePmu!(wls; label = 18)
        updatePmu!(lav; label = 18)
        testReusing(monitoring, wls, lav, 35)
    end
end

@testset "Reusing Meters DC State Estimation" begin
    @default(template)
    @default(unit)
    @config(label = Integer)

    ############ IEEE 14-bus Test Case ############
    system = powerSystem(path * "case14test.m")

    dcModel!(system)
    pf = dcPowerFlow(system)
    powerFlow!(pf)

    @pmu(varianceMagnitudeBus = 1, varianceAngleBus = 1)
    monitoring = measurement(system)

    addWattmeter!(monitoring; label = 1, bus = 3, active = -0.94)
    addWattmeter!(monitoring; label = 2, from = 10, active = 0.32)
    addWattmeter!(monitoring; label = 3, to = 13, active = -0.16)

    for (key, idx) in system.bus.label
        addPmu!(monitoring; bus = key, magnitude = 1, angle = pf.voltage.angle[idx])
    end
    addPmu!(monitoring; bus = 2, magnitude = 1, angle = -0.06)

    wls = dcStateEstimation(monitoring)
    lav = dcLavStateEstimation(monitoring, Ipopt.Optimizer)

    @testset "Bus PMU" begin
        updatePmu!(wls; label = 15, angle = 2.1, varianceAngle = 1e36)
        updatePmu!(lav; label = 15, angle = 2.1, varianceAngle = 1e36)
        testReusing(monitoring, wls, lav, 18)

        updatePmu!(wls; label = 15, varianceAngle = 1e-3, status = 0)
        updatePmu!(lav; label = 15, status = 0)
        testReusing(monitoring, wls, lav, 18)

        updatePmu!(wls; label = 15, angle = -0.06, status = 1)
        updatePmu!(lav; label = 15, angle = -0.06, status = 1)
        testReusing(monitoring, wls, lav, 18)

        updatePmu!(monitoring; label = 15, status = 0)
        updatePmu!(wls; label = 15)
        updatePmu!(lav; label = 15)
        testReusing(monitoring, wls, lav, 18)

        updatePmu!(monitoring; label = 15, status = 1)
        updatePmu!(wls; label = 15, angle = -0.07)
        updatePmu!(lav; label = 15, angle = -0.07 )
        testReusing(monitoring, wls, lav, 18)
    end

    @testset "Bus Wattmeter" begin
        updateWattmeter!(wls; label = 1, active = 5.3, variance = 1e45)
        updateWattmeter!(lav; label = 1, active = 5.3, variance = 1e45)
        testReusing(monitoring, wls, lav, 1)

        updateWattmeter!(wls; label = 1, variance = 1e-4, status = 0)
        updateWattmeter!(lav; label = 1, variance = 1e-4, status = 0)
        testReusing(monitoring, wls, lav, 1)

        updateWattmeter!(wls; label = 1, active = -0.94, status = 1)
        updateWattmeter!(lav; label = 1, active = -0.94, status = 1)
        testReusing(monitoring, wls, lav, 1)

        updateWattmeter!(monitoring; label = 1, active = 6.9)
        updateWattmeter!(wls; label = 1, status = 0)
        updateWattmeter!(lav; label = 1, status = 0)
        testReusing(monitoring, wls, lav, 1)

        updateWattmeter!(monitoring; label = 1, active = -0.95)
        updateWattmeter!(wls; label = 1, status = 1)
        updateWattmeter!(lav; label = 1, status = 1)
        testReusing(monitoring, wls, lav, 1)
    end

    @testset "From-Bus Wattmeter" begin
        updateWattmeter!(wls; label = 2, active = 2.3, variance = 1e35)
        updateWattmeter!(lav; label = 2, active = 2.3, variance = 1e35)
        testReusing(monitoring, wls, lav, 2)

        updateWattmeter!(wls; label = 2, variance = 1e-6, status = 0)
        updateWattmeter!(lav; label = 2, variance = 1e-6, status = 0)
        testReusing(monitoring, wls, lav, 2)

        updateWattmeter!(wls; label = 2, active = 0.32, status = 1)
        updateWattmeter!(lav; label = 2, active = 0.32, status = 1)
        testReusing(monitoring, wls, lav, 2)

        updateWattmeter!(monitoring; label = 2, status = 0)
        updateWattmeter!(wls; label = 2, active = 6.9)
        updateWattmeter!(lav; label = 2, active = 6.9)
        testReusing(monitoring, wls, lav, 2)

        updateWattmeter!(monitoring; label = 2, active = 0.31, variance = 1e-3)
        updateWattmeter!(wls; label = 2, status = 1)
        updateWattmeter!(lav; label = 2, status = 1)
        testReusing(monitoring, wls, lav, 2)
    end

    @testset "To-Bus Wattmeter" begin
        updateWattmeter!(wls; label = 3, active = 1.2, variance = 1e30)
        updateWattmeter!(lav; label = 3, active = 1.2, variance = 1e30)
        testReusing(monitoring, wls, lav, 3)

        updateWattmeter!(wls; label = 3, variance = 1e-5, status = 0)
        updateWattmeter!(lav; label = 3, variance = 1e-5, status = 0)
        testReusing(monitoring, wls, lav, 3)

        updateWattmeter!(wls; label = 3, active = -0.16, status = 1)
        updateWattmeter!(lav; label = 3, active = -0.16, status = 1)
        testReusing(monitoring, wls, lav, 3)

        updateWattmeter!(monitoring; label = 3, active = 3.9)
        updateWattmeter!(wls; label = 3, status = 0)
        updateWattmeter!(lav; label = 3, status = 0)
        testReusing(monitoring, wls, lav, 3)

        updateWattmeter!(monitoring; label = 3, active = -0.15, status = 1)
        updateWattmeter!(wls; label = 3, variance = 1e-3)
        updateWattmeter!(lav; label = 3, variance = 1e-3)
        testReusing(monitoring, wls, lav, 3)
    end
end