@testset "Build and Update Power System in Per-Units" begin
    @default(template)

    load = powerSystem(path * "build.m")
    rad = pi / 180

    ########## Build Power System ##########
    build = powerSystem()

    # Add Buses
    @bus(area = 1, lossZone = 1, base = 230e3)
    addBus!(build; label = "1", type = 3, active = 0.17, conductance = 0.09)
    addBus!(build; label = 2, type = 2, magnitude = 1.1, minMagnitude = 0.9, base = 115e3)
    addBus!(build; label = 4, active = 0.7, reactive = 0.05, susceptance = 0.3)
    addBus!(build; label = 5, active = 2, reactive = 0.5, angle = -1.8 * rad)
    addBus!(build; label = 6, active = 0.75, reactive = 0.5, base = 115e3)
    addBus!(build; active = 0.35, reactive = 0.15, magnitude = 0.9, maxMagnitude = 1.06)
    addBus!(build; susceptance = -0.1, magnitude = 0.98, angle = 7.1 * rad)
    addBus!(build; label = 9, active = 0.4, reactive = 0.04, base = 115e3)

    # Add Branches
    @branch(
        minDiffAngle = 0, maxDiffAngle = 360 * pi / 180,
        susceptance = 0.14, resistance = 0.09, reactance = 0.02
    )
    addBranch!(
        build;
        from = 8, to = 5, susceptance = 0, turnsRatio = 0.956, shiftAngle = 2.2 * rad
    )
    addBranch!(build; from = "5", to = "6", susceptance = 0, turnsRatio = 1.05)
    addBranch!(build; from = 4, to = 6, resistance = 0.17, reactance = 0.31, status = 0)
    addBranch!(build; from = 5, to = 7, resistance = 0.01, reactance = 0.05)
    addBranch!(
        build; from = 2, to = 9, reactance = 0.06, susceptance = 0, turnsRatio = 1.073
    )
    addBranch!(build; from = 2, to = 7, resistance = 0.05, reactance = 0.02, status = 0)
    addBranch!(
        build; from = 1, to = 2, resistance = 0.07, reactance = 0.09, minFromBus = -0.1,
        maxFromBus = 0.1, minToBus = -0.1, maxToBus = 0.1
    )
    addBranch!(build; from = 4, to = 9, resistance = 0.08, reactance = 0.30)

    # Add Generators
    @generator(label = "?", minReactive = -0.5, maxReactive = 0.9)
    addGenerator!(build; bus = "1", active = 3.7, maxReactive = 1.75, maxActive = 4.72)
    addGenerator!(build; bus = 2, active = 2.1, magnitude = 1.1, maxActive = 3.16, status = 0)
    addGenerator!(build; bus = 2, active = 2.6, reactive = 0.3, maxActive = 3.16)
    addGenerator!(build; bus = 1, active = 0.8, reactive = 0.3, status = 0)

    # Add Costs
    cost!(build; generator = 1, active = 2, polynomial = [0.01 * 100^2; 40 * 100; 4])
    cost!(build; generator = 2, active = 2, polynomial = [0.0266666667 * 100^2; 20 * 100; 3])
    cost!(build; generator = 3, active = 2, polynomial = [0.0266666667 * 100^2; 20 * 100; 2])
    cost!(build; generator = 4, active = 2, polynomial = [30.0 * 100; 5])

    @testset "Power System Data" begin
        compstruct(load.bus, build.bus; atol = 1e-14)
        compstruct(load.branch, build.branch)
        compstruct(load.generator, build.generator)
        compstruct(load.base, build.base)
    end

    ########## Update Power System ##########
    load = powerSystem(path * "update.m")

    # Update Buses
    updateBus!(build; label = 1, conductance = 0.1, susceptance = -0.2, active = 0.3)
    updateBus!(build; label = 2, type = 1, reactive = 0.2, magnitude = 1.2, base = 120e3)
    updateBus!(build; label = 5, angle = -0.8 * rad, area = 2, lossZone = 3)
    updateBus!(build; label = 8,  minMagnitude = 0.8, maxMagnitude = 1.2)

    # Update Branches
    updateBranch!(
        build;
        label = 1, status = 0, resistance = 0.05, turnsRatio = 0.89, shiftAngle = 1.2 * rad
    )
    updateBranch!(
        build;
        label = 7, minFromBus = -5, maxFromBus = 5, minToBus = -5, maxToBus = 5, type = 3
    )
    updateBranch!(build; label = 3, status = 1, susceptance = 0.1)
    updateBranch!(build; label = 6, status = 1, resistance = 0.08, reactance = 0.04)
    updateBranch!(build; label = 2, status = 0)
    updateBranch!(build; label = 8, minDiffAngle = -2 * rad, maxDiffAngle = rad)

    # Update Generators
    updateGenerator!(build; label = 2, status = 1, magnitude = 1.2)
    updateGenerator!(build; label = 4, status = 1, active = 0.1, reactive = 0.2)
    updateGenerator!(build; label = 1, status = 0, minActive = 0.1, maxActive = 1)
    updateGenerator!(build; label = 3, status = 0, active = 0.3, reactive = 0.1)
    updateGenerator!(build; label = 1, minReactive = -0.1, maxReactive = 0.9)
    updateGenerator!(build; label = 1, lowActive = 1, minLowReactive = 2, maxLowReactive = 3)
    updateGenerator!(build; label = 1, upActive = 5, minUpReactive = 3, maxUpReactive = 4)
    updateGenerator!(build; label = 1, loadFollowing = 5, reserve10min = 3, reactiveRamp = 4)

    # Update Costs
    cost!(build; generator = 4, active = 2, polynomial = [0.3 * 100^2; 15 * 100; 5])

    @testset "Power System Data" begin
        compstruct(load.bus, build.bus; atol = 1e-14)
        compstruct(load.branch, build.branch; atol = 1e-14)
        compstruct(load.generator, build.generator)
        compstruct(load.base, build.base)
    end

    @label(aaaa)
end

@testset "Build and Update Power System in SI Units" begin
    @labels(Integer)
    load = powerSystem(path * "build.m")
    @base(load, MVA, kV)

    ########## Build Power System ##########
    @power(kW, MVAr, GVA)
    @voltage(kV, deg, MV)
    @parameter(Ω, S)
    @default(template)

    build = powerSystem()
    @base(build, MVA, kV)
    fn = sqrt(3)

    # Add Buses
    @bus(area = 1, lossZone = 1, base = 0.23)
    addBus!(build; label = 1, type = 3, active = 17e3, conductance = 9e3)
    addBus!(build; type = 2, magnitude = 1.1 * 115 / fn, minMagnitude = 0.9 * 115 / fn, base = 0.115)
    addBus!(build; label = 4, active = 70e3, reactive = 5, susceptance = 30)
    addBus!(build; label = 5, active = 200e3, reactive = 50, angle = -1.8)
    addBus!(build; label = 6, active = 75e3, reactive = 50, base = 0.115)
    addBus!(
        build;
        active = 35e3, reactive = 15, magnitude = 0.9 * 230 / fn, maxMagnitude = 1.06 * 230 / fn
    )
    addBus!(build; susceptance = -10, magnitude = 0.98 * 230 / fn, angle = 7.1)
    addBus!(build; label = 9, active = 40e3, reactive = 4, base = 0.115)

    # Add Branches
    Zb1 = (230e3 * 0.956)^2 / (100e6)
    Zb2 = (230e3 * 1.05)^2 / (100e6)
    Zb3 = 230^2 / 100
    Zb4 = (115e3 * 1.073)^2 / (100e6)
    Zb5 = 115^2 / 100

    @branch(
        minDiffAngle = 0, maxDiffAngle = 360, susceptance = 0.14,
        resistance = 0.09, reactance = 0.02
    )
    addBranch!(
        build; from = 8, to = 5, resistance = 0.09 * Zb1, reactance = 0.02 * Zb1,
        susceptance = 0, turnsRatio = 0.956, shiftAngle = 2.2
    )
    addBranch!(
        build; from = 5, to = 6, resistance = 0.09 * Zb2, reactance = 0.02 * Zb2,
        susceptance = 0, turnsRatio = 1.05
    )
    addBranch!(
        build; from = 4, to = 6, resistance = 0.17 * Zb3, reactance = 0.31 * Zb3,
        susceptance = 0.14 / Zb3, status = 0
    )
    addBranch!(
        build; from = 5, to = 7, resistance = 0.01 * Zb3, reactance = 0.05 * Zb3,
        susceptance = 0.14 / Zb3
    )
    addBranch!(
        build; from = 2, to = 9, resistance = 0.09 * Zb4, reactance = 0.06 * Zb4,
        susceptance = 0, turnsRatio = 1.073
    )
    addBranch!(
        build; from = 2, to = 7, resistance = 0.05 * Zb5, reactance = 0.02 * Zb5,
        susceptance = 0.14 / Zb5, status = 0
    )
    addBranch!(
        build; from = 1, to = 2, resistance = 0.07 * Zb3, reactance = 0.09 * Zb3,
        susceptance = 0.14 / Zb3, minFromBus = -10e-3, maxFromBus = 10e-3,
        minToBus = -10e-3, maxToBus = 10e-3
    )
    addBranch!(
        build; from = 4, to = 9, resistance = 0.08 * Zb3, reactance = 0.30 * Zb3,
        susceptance = 0.14 / Zb3
    )

    # Add Generators
    @generator(minReactive = -50, maxReactive = 90)
    addGenerator!(build; bus = 1, active = 370e3, maxReactive = 175, maxActive = 472e3)
    addGenerator!(
        build;
        bus = 2, active = 210e3, magnitude = 1.1 * 115 / fn, maxActive = 316e3, status = 0
    )
    addGenerator!(build; bus = 2, active = 260e3, reactive = 30, maxActive = 316e3)
    addGenerator!(build; bus = 1, active = 80e3, reactive = 30, status = 0)

    # Add Costs
    cost!(build; generator = 1, active = 2, polynomial = [0.01e-6; 40e-3; 4])
    cost!(build; generator = 2, active = 2, polynomial = [0.0266666667e-6; 20e-3; 3])
    cost!(build; generator = 3, active = 2, polynomial = [0.0266666667e-6; 20e-3; 2])
    cost!(build; generator = 4, active = 2, polynomial = [30.0e-3; 5])

    @testset "Power System Data" begin
        compstruct(load.bus, build.bus; atol = 1e-12)
        compstruct(load.branch, build.branch; atol = 1e-12)
        compstruct(load.generator, build.generator; atol = 1e-12)
        compstruct(load.base, build.base)
    end

    ########## Update Power System ##########
    load = powerSystem(path * "update.m")
    @base(load, MVA, kV)

    # Update Buses
    updateBus!(build; label = 1, conductance = 10e3, susceptance = -20, active = 30e3)
    updateBus!(build; label = 2, type = 1, reactive = 20, magnitude = 1.2 * 120 / fn, base = 0.12)
    updateBus!(build; label = 5, angle = -0.8, area = 2, lossZone = 3)
    updateBus!(build; label = 8, minMagnitude = 0.8 * 230 / fn, maxMagnitude = 1.2 * 230 / fn)

    # Update Branches
    Zb1 = 230^2 / 100
    Zb2 = 120^2 / 100
    Zb3 = (230e3 * 0.89)^2 / (100e6)

    updateBranch!(
        build; label = 6, status = 1, resistance = 0.08 * Zb2, reactance = 0.04 * Zb2
    )
    updateBranch!(
        build;
        label = 1, status = 0, resistance = 0.05 * Zb3, turnsRatio = 0.89, shiftAngle = 1.2
    )
    updateBranch!(
        build; label = 7, minFromBus = -0.5, maxFromBus = 0.5, minToBus = -0.5,
        maxToBus = 0.5, type = 3
    )
    updateBranch!(build; label = 3, status = 1, susceptance = 0.1 / Zb1)
    updateBranch!(build; label = 2, status = 0)
    updateBranch!(build; label = 8, minDiffAngle = -2, maxDiffAngle = 1)

    # Update Generators
    updateGenerator!(
        build; label = 1, lowActive = 100e3, minLowReactive = 200, maxLowReactive = 300
    )
    updateGenerator!(
        build; label = 1, upActive = 500e3, minUpReactive = 300, maxUpReactive = 400
    )
    updateGenerator!(
        build; label = 1, loadFollowing = 500e3, reserve10min = 300e3, reactiveRamp = 400
    )
    updateGenerator!(build; label = 2, status = 1, magnitude = 1.2 * 120 / fn)
    updateGenerator!(build; label = 4, status = 1, active = 10e3, reactive = 20)
    updateGenerator!(build; label = 1, status = 0, minActive = 10e3, maxActive = 100e3)
    updateGenerator!(build; label = 3, status = 0, active = 30e3, reactive = 10)
    updateGenerator!(build; label = 1, minReactive = -10, maxReactive = 90)

    # Update Costs
    cost!(build; generator = 4, active = 2, polynomial = [0.3e-6; 15e-3; 5])

    @testset "Power System Data" begin
        compstruct(load.bus, build.bus; atol = 1e-12)
        compstruct(load.branch, build.branch; atol = 1e-12)
        compstruct(load.generator, build.generator; atol = 1e-12)
        compstruct(load.base, build.base)
    end
end

@testset "Build Power System in Per-Units with Macros" begin
    @default(unit)
    @default(template)
    system = powerSystem()

    ########## Bus Macro ##########
    @bus(
        label = "Bus ?", type = 2, active = 0.1, reactive = -0.2, conductance = 1e-2,
        susceptance = 1, magnitude = 1.1, angle = 0.2, minMagnitude = 0.8,
        maxMagnitude = 0.9, base = 100e3, area = 2, lossZone = 3
    )

    @testset "Bus Data Using Macro" begin
        addBus!(system)
        @test system.bus.label["Bus 1"] == 1
        @test system.bus.layout.type[1] == 2
        @test system.bus.demand.active[1] == 0.1
        @test system.bus.demand.reactive[1] == -0.2
        @test system.bus.shunt.conductance[1] == 1e-2
        @test system.bus.shunt.susceptance[1] == 1
        @test system.bus.voltage.magnitude[1] == 1.1
        @test system.bus.voltage.angle[1] == 0.2
        @test system.bus.voltage.minMagnitude[1] == 0.8
        @test system.bus.voltage.maxMagnitude[1] == 0.9
        @test system.base.voltage.value[1] == 100e3
        @test system.bus.layout.area[1] == 2
        @test system.bus.layout.lossZone[1] == 3
    end

    @testset "Bus Data Using Function" begin
        addBus!(
            system; type = 1, active = 0.3, reactive = -0.3, conductance = 1e-3,
            susceptance = 2, magnitude = 1.2, angle = 0.3, minMagnitude = 0.9,
            maxMagnitude = 1.1, base = 110e3, area = 3, lossZone = 4
        )
        @test system.bus.label["Bus 2"] == 2
        @test system.bus.layout.type[2] == 1
        @test system.bus.demand.active[2] == 0.3
        @test system.bus.demand.reactive[2] == -0.3
        @test system.bus.shunt.conductance[2] == 1e-3
        @test system.bus.shunt.susceptance[2] == 2
        @test system.bus.voltage.magnitude[2] == 1.2
        @test system.bus.voltage.angle[2] == 0.3
        @test system.bus.voltage.minMagnitude[2] == 0.9
        @test system.bus.voltage.maxMagnitude[2] == 1.1
        @test system.base.voltage.value[2] == 110e3
        @test system.bus.layout.area[2] == 3
        @test system.bus.layout.lossZone[2] == 4
    end

    ########## Branch Macro ##########
    @branch(
        label = "Branch ?", status = 0, resistance = 0.1, reactance = 0.2,
        susceptance = 0.3, conductance = 0.4, turnsRatio = 0.5, shiftAngle = 0.6,
        minDiffAngle = -1.0, maxDiffAngle = 1.0, minFromBus = -0.2, maxFromBus = 0.2,
        minToBus = -0.3, maxToBus = 0.3, type = 2
    )

    @testset "Branch Data Using Macro" begin
        addBranch!(system; from = "Bus 1", to = "Bus 2")
        @test system.branch.label["Branch 1"] == 1
        @test system.branch.layout.status[1] == 0
        @test system.branch.parameter.resistance[1] == 0.1
        @test system.branch.parameter.reactance[1] == 0.2
        @test system.branch.parameter.susceptance[1] == 0.3
        @test system.branch.parameter.conductance[1] == 0.4
        @test system.branch.parameter.turnsRatio[1] == 0.5
        @test system.branch.parameter.shiftAngle[1] == 0.6
        @test system.branch.voltage.minDiffAngle[1] == -1
        @test system.branch.voltage.maxDiffAngle[1] == 1
        @test system.branch.flow.minFromBus[1] == -0.2
        @test system.branch.flow.maxFromBus[1] == 0.2
        @test system.branch.flow.minToBus[1] == -0.3
        @test system.branch.flow.maxToBus[1] == 0.3
        @test system.branch.flow.type[1] == 2
    end

    @testset "Branch Data Using Function" begin
        addBranch!(
            system; from = "Bus 1", to = "Bus 2", status = 1, resistance = 1.1,
            reactance = 1.2, susceptance = 1.3, conductance = 1.4, turnsRatio = 1.5,
            shiftAngle = 1.6, minDiffAngle = -2.0, maxDiffAngle = 2.0, minFromBus = -1.2,
            maxFromBus = 1.2, minToBus = -1.3, maxToBus = 1.3, type = 3
        )
        @test system.branch.label["Branch 2"] == 2
        @test system.branch.layout.status[2] == 1
        @test system.branch.parameter.resistance[2] == 1.1
        @test system.branch.parameter.reactance[2] == 1.2
        @test system.branch.parameter.susceptance[2] == 1.3
        @test system.branch.parameter.conductance[2] == 1.4
        @test system.branch.parameter.turnsRatio[2] == 1.5
        @test system.branch.parameter.shiftAngle[2] == 1.6
        @test system.branch.voltage.minDiffAngle[2] == -2
        @test system.branch.voltage.maxDiffAngle[2] == 2
        @test system.branch.flow.minFromBus[2] == -1.2
        @test system.branch.flow.maxFromBus[2] == 1.2
        @test system.branch.flow.minToBus[2] == -1.3
        @test system.branch.flow.maxToBus[2] == 1.3
        @test system.branch.flow.type[2] == 3
    end

    ########## Generator Macro ##########
    @generator(
        label = "Generator ?", area = 2, status = 0, active = 1.1, reactive = 1.2,
        magnitude = 0.5, minActive = 0.1, maxActive = 0.2, minReactive = 0.3,
        maxReactive = 0.4, lowActive = 0.5, minLowReactive = 0.6,
        maxLowReactive = 0.7, upActive = 0.8, minUpReactive = 0.9, maxUpReactive = 1.0,
        loadFollowing = 1.1, reserve10min = 1.2, reserve30min = 1.3, reactiveRamp = 1.4
    )

    @testset "Generator Data Using Macro" begin
        addGenerator!(system; bus = "Bus 1")
        @test system.generator.label["Generator 1"] == 1
        @test system.generator.layout.status[1] == 0
        @test system.generator.output.active[1] == 1.1
        @test system.generator.output.reactive[1] == 1.2
        @test system.generator.voltage.magnitude[1] == 0.5
        @test system.generator.capability.minActive[1] == 0.1
        @test system.generator.capability.maxActive[1] == 0.2
        @test system.generator.capability.minReactive[1] == 0.3
        @test system.generator.capability.maxReactive[1] == 0.4
        @test system.generator.capability.lowActive[1] == 0.5
        @test system.generator.capability.minLowReactive[1] == 0.6
        @test system.generator.capability.maxLowReactive[1] == 0.7
        @test system.generator.capability.upActive[1] == 0.8
        @test system.generator.capability.minUpReactive[1] == 0.9
        @test system.generator.capability.maxUpReactive[1] == 1.0
        @test system.generator.ramping.loadFollowing[1] == 1.1
        @test system.generator.ramping.reserve10min[1] == 1.2
        @test system.generator.ramping.reserve30min[1] == 1.3
        @test system.generator.ramping.reactiveRamp[1] == 1.4
    end

    @testset "Generator Data Using Function" begin
        addGenerator!(
            system; label = "Generator 2", bus = "Bus 1", area = 1, status = 1,
            active = 2.1, reactive = 2.2, magnitude = 1.5, minActive = 1.1, maxActive = 1.2,
            minReactive = 1.3, maxReactive = 1.4, lowActive = 1.5, minLowReactive = 1.6,
            maxLowReactive = 1.7, upActive = 1.8, minUpReactive = 1.9, maxUpReactive = 2.0,
            loadFollowing = 2.1, reserve10min = 2.2, reserve30min = 2.3, reactiveRamp = 2.4
        )
        @test system.generator.label["Generator 2"] == 2
        @test system.generator.layout.status[2] == 1
        @test system.generator.output.active[2] == 2.1
        @test system.generator.output.reactive[2] == 2.2
        @test system.generator.voltage.magnitude[2] == 1.5
        @test system.generator.capability.minActive[2] == 1.1
        @test system.generator.capability.maxActive[2] == 1.2
        @test system.generator.capability.minReactive[2] == 1.3
        @test system.generator.capability.maxReactive[2] == 1.4
        @test system.generator.capability.lowActive[2] == 1.5
        @test system.generator.capability.minLowReactive[2] == 1.6
        @test system.generator.capability.maxLowReactive[2] == 1.7
        @test system.generator.capability.upActive[2] == 1.8
        @test system.generator.capability.minUpReactive[2] == 1.9
        @test system.generator.capability.maxUpReactive[2] == 2.0
        @test system.generator.ramping.loadFollowing[2] == 2.1
        @test system.generator.ramping.reserve10min[2] == 2.2
        @test system.generator.ramping.reserve30min[2] == 2.3
        @test system.generator.ramping.reactiveRamp[2] == 2.4
    end
end

@testset "Build Power System in SI Units with Macros" begin
    @default(unit)
    @default(template)

    @power(kW, MVAr, GVA)
    @voltage(kV, deg, kV)
    @parameter(Ω, S)

    system = powerSystem()
    @base(system, MVA, kV)

    ########## Bus Macro ##########
    @bus(
        label = "Bus ?", type = 2, active = 1e4, reactive = -20, conductance = 1e3,
        susceptance = 100, magnitude = 110 / sqrt(3), angle = 0.2 * 180 / pi,
        minMagnitude = 80 / sqrt(3), maxMagnitude = 90 / sqrt(3), base = 100, area = 2,
        lossZone = 3
    )

    @testset "Bus Data Using Macro" begin
        addBus!(system)
        @test system.bus.label["Bus 1"] == 1
        @test system.bus.layout.type[1] == 2
        @test system.bus.demand.active[1] == 0.1
        @test system.bus.demand.reactive[1] == -0.2
        @test system.bus.shunt.conductance[1] == 1e-2
        @test system.bus.shunt.susceptance[1] == 1
        @test system.bus.voltage.magnitude[1] ≈ 1.1
        @test system.bus.voltage.angle[1] == 0.2
        @test system.bus.voltage.minMagnitude[1] ≈ 0.8
        @test system.bus.voltage.maxMagnitude[1] ≈ 0.9
        @test system.base.voltage.value[1] == 100
        @test system.bus.layout.area[1] == 2
        @test system.bus.layout.lossZone[1] == 3
    end

    ########## Branch Macro ##########
    addBus!(system)
    @branch(
        label = "Branch ?", status = 0, resistance = 0.1 * (100e3 * 0.5)^2 / (100e6),
        reactance = 0.2 * (100e3 * 0.5)^2 / (100e6),
        susceptance = 0.3 / ((100e3 * 0.5)^2 / (100e6)),
        conductance = 0.4 / ((100e3 * 0.5)^2 / (100e6)), turnsRatio = 0.5,
        shiftAngle = 0.6 * 180 / pi, minDiffAngle = -1 * 180 / pi,
        maxDiffAngle = 1 * 180 / pi, minFromBus = -0.2e5, maxFromBus = 0.2e5,
        minToBus = 0.3e5, maxToBus = 0.4e5, type = 1
    )

    @testset "Branch Data Using Macro" begin
        addBranch!(system; from = "Bus 1", to = "Bus 2")
        @test system.branch.label["Branch 1"] == 1
        @test system.branch.layout.status[1] == 0
        @test system.branch.parameter.resistance[1] == 0.1
        @test system.branch.parameter.reactance[1] == 0.2
        @test system.branch.parameter.susceptance[1] == 0.3
        @test system.branch.parameter.conductance[1] == 0.4
        @test system.branch.parameter.turnsRatio[1] == 0.5
        @test system.branch.parameter.shiftAngle[1] == 0.6
        @test system.branch.voltage.minDiffAngle[1] == -1
        @test system.branch.voltage.maxDiffAngle[1] == 1
        @test system.branch.flow.minFromBus[1] == -0.2
        @test system.branch.flow.maxFromBus[1] == 0.2
        @test system.branch.flow.minToBus[1] == 0.3
        @test system.branch.flow.maxToBus[1] == 0.4
        @test system.branch.flow.type[1] == 1
    end

    ########## Generator Macro ##########
    @generator(
        label = "Generator ?", area = 2, status = 0, active = 1.1e5,
        reactive = 1.2e2, magnitude = 50 / sqrt(3), minActive = 0.1e5, maxActive = 0.2e5,
        minReactive = 0.3e2, maxReactive = 0.4e2, lowActive = 0.5e5,
        minLowReactive = 0.6e2, maxLowReactive = 0.7e2, upActive = 0.8e5,
        minUpReactive = 0.9e2, maxUpReactive = 1.0e2, loadFollowing = 1.1e5,
        reserve10min = 1.2e5, reserve30min = 1.3e5, reactiveRamp = 1.4e2
    )

    @testset "Generator Data Using Macro" begin
        addGenerator!(system; bus = "Bus 1")
        @test system.generator.label["Generator 1"] == 1
        @test system.generator.layout.status[1] == 0
        @test system.generator.output.active[1] == 1.1
        @test system.generator.output.reactive[1] == 1.2
        @test system.generator.voltage.magnitude[1] ≈ 0.5
        @test system.generator.capability.minActive[1] == 0.1
        @test system.generator.capability.maxActive[1] == 0.2
        @test system.generator.capability.minReactive[1] == 0.3
        @test system.generator.capability.maxReactive[1] == 0.4
        @test system.generator.capability.lowActive[1] == 0.5
        @test system.generator.capability.minLowReactive[1] == 0.6
        @test system.generator.capability.maxLowReactive[1] ≈ 0.7
        @test system.generator.capability.upActive[1] == 0.8
        @test system.generator.capability.minUpReactive[1] == 0.9
        @test system.generator.capability.maxUpReactive[1] == 1.0
        @test system.generator.ramping.loadFollowing[1] == 1.1
        @test system.generator.ramping.reserve10min[1] == 1.2
        @test system.generator.ramping.reserve30min[1] == 1.3
        @test system.generator.ramping.reactiveRamp[1] ≈ 1.4
    end
end

@testset "Errors and Messages" begin
    @default(unit)
    @default(template)
    system = powerSystem()

    addBus!(system; label = "Bus 1", type = 3)
    addBus!(system; label = "Bus 2")
    addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)
    addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.2)

    acModel!(system)
    dcModel!(system)

    dc = dcPowerFlow(system)
    nr = newtonRaphson(system)
    fnrxb = fastNewtonRaphsonXB(system)
    fnrbx = fastNewtonRaphsonBX(system)
    gs = gaussSeidel(system)

    @suppress addBus!(system, label = "Bus 3")
    @suppress addBus!(system, label = 4)

    @testset "Deleting AC and DC Models" begin
        @test isempty(system.model.ac.nodalMatrix) == true
        @test isempty(system.model.ac.nodalMatrixTranspose) == true
        @test isempty(system.model.ac.nodalFromFrom) == true
        @test isempty(system.model.ac.nodalFromTo) == true
        @test isempty(system.model.ac.nodalToFrom) == true
        @test isempty(system.model.ac.nodalToTo) == true
        @test isempty(system.model.ac.admittance) == true
        @test system.model.ac.model == 1
        @test system.model.ac.pattern == 1

        @test isempty(system.model.dc.nodalMatrix) == true
        @test isempty(system.model.dc.admittance) == true
        @test isempty(system.model.dc.shiftPower) == true
        @test system.model.dc.model == 1
        @test system.model.dc.pattern == 1
    end

    @testset "Printing Data" begin
        voltg = system.bus.voltage

        print1 = @capture_out print(system.bus.label, voltg.magnitude)
        @test print1 == "Bus 1: 1.0\nBus 2: 1.0\nBus 3: 1.0\n4: 1.0\n"

        print2 = @capture_out print(system.bus.label, voltg.magnitude, voltg.angle)
        @test print2 == "Bus 1: 1.0, 0.0\nBus 2: 1.0, 0.0\nBus 3: 1.0, 0.0\n4: 1.0, 0.0\n"

        print3 = @capture_out print(system.bus.label, system.bus.layout.type)
        @test print3 == "Bus 1: 3\nBus 2: 1\nBus 3: 1\n4: 1\n"
    end

    @testset "Add and Update Bus Errors" begin
        err = ErrorException("The label Bus 1 is not unique.")
        @test_throws err addBus!(system; label = "Bus 1")

        err = ErrorException("The label 4 is not unique.")
        @test_throws err addBus!(system; label = 4)

        err = ErrorException("The value 4 of the bus type is illegal.")
        @test_throws err addBus!(system; label = "Bus 4", type = 4)

        err = ErrorException("The slack bus has already been designated.")
        @test_throws err addBus!(system; label = "Bus 5", type = 3)

        err = ErrorException("The analysis model cannot be reused when adding a bus.")
        @test_throws err addBus!(system, dc; label = "Bus 4", active = 0.1)
        @test_throws err addBus!(system, nr; label = "Bus 4", active = 0.1)
        @test_throws err addBus!(system, fnrxb; label = "Bus 4", active = 0.1)
        @test_throws err addBus!(system, fnrbx; label = "Bus 4", active = 0.1)
        @test_throws err addBus!(system, gs; label = "Bus 4", active = 0.1)

        err = ErrorException(
            "To set bus with label Bus 3 as the slack bus, reassign the current slack " *
            "bus to either a generator or demand bus."
        )
        @test_throws err updateBus!(system; label = "Bus 3", type = 3)

        err = ErrorException(
            "The bus label Bus 6 that has been specified does not exist within the " *
            "available bus labels."
        )
        @test_throws err updateBus!(system; label = "Bus 6", active = 2)

        err = ErrorException(
            "The bus label 2 that has been specified does not exist within the " *
            "available bus labels."
        )
        @test_throws err updateBus!(system; label = 2, active = 2)

        err = ErrorException(
            "The power flow model cannot be reused due to required bus type conversion."
        )
        @test_throws err updateBus!(system, dc; label = "Bus 1", type = 1)
        @test_throws err updateBus!(system, nr; label = "Bus 1", type = 1)
        @test_throws err updateBus!(system, fnrxb; label = "Bus 1", type = 1)
        @test_throws err updateBus!(system, fnrbx; label = "Bus 1", type = 1)
        @test_throws err updateBus!(system, gs; label = "Bus 1", type = 1)

        @test_throws LoadError @eval @bus(label = "Bus ?", typee = 1)
    end

    @testset "Add and Update Branch Errors" begin
        err = ErrorException("The label Branch 1 is not unique.")
        @test_throws err addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2")

        err = ErrorException("Invalid value for from or to keywords.")
        @test_throws err addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 1")

        err = ErrorException("At least one of resistance or reactance is required.")
        @test_throws err addBranch!(system; label = "Branch 3", from = "Bus 1", to = "Bus 2")

        err = ErrorException(
            "The status 2 is not allowed; it should be in-service (1) or out-of-service (0)."
        )
        @test_throws err addBranch!(system; from = "Bus 1", to = "Bus 2", resistance = 0.1, status = 2)

        @test_throws LoadError @eval @branch(label = "Branch ?", resistances = 1)

        err = ErrorException("The label Generator 1 is not unique.")
        @test_throws err addGenerator!(system; label = "Generator 1", bus = "Bus 1")

        err = ErrorException(
            "The status 2 is not allowed; it should be in-service (1) or out-of-service (0)."
        )
        @test_throws err addGenerator!(system; label = "Generator 2", bus = "Bus 1", status = 2)

        err = ErrorException(
            "The power flow model cannot be reused due to required bus type conversion."
        )
        @test_throws err updateGenerator!(system, dc; label = "Generator 1", status = 0)
        @test_throws err updateGenerator!(system, nr; label = "Generator 1", status = 0)
        @test_throws err updateGenerator!(system, gs; label = "Generator 1", status = 0)
    end

    @testset "Add and Update Cost Errors" begin
        err = ErrorException(
            "The concurrent definition of the keywords active and reactive is not allowed."
        )
        @test_throws err begin
            cost!(system; generator = "Generator 1", active = 2, reactive = 1, polynomial = [1.0])
        end

        err = ErrorException("The cost model is missing.")
        @test_throws err cost!(system; generator = "Generator 1", polynomial = [1.0])

        err = ErrorException(
            "The model is not allowed; it should be piecewise (1) or polynomial (2)."
        )
        @test_throws err cost!(system; generator = "Generator 1", active = 3, polynomial = [1.0])

        err = ErrorException(
            "An attempt to assign a polynomial function, but the function does not exist."
        )
        @test_throws err cost!(system; generator = "Generator 1", active = 2)

        err = ErrorException(
            "An attempt to assign a piecewise function, but the function does not exist."
        )
        @test_throws err cost!(system; generator = "Generator 1", active = 1)

        @test_throws LoadError @eval @generator(label = "Generator ?", actives = 1)
    end

    @testset "Unit Errors" begin
        @test_throws LoadError @eval @current(sA, deg)
        @test_throws LoadError @eval @current(kV, deg)
    end

    @testset "Voltage Errors" begin
        err = ErrorException("The voltage values are missing.")
        @test_throws err power!(system, dc)
    end

    @testset "Load Errors" begin
        err = DomainError(".h6", "The extension .h6 is not supported.")
        @test_throws err powerSystem("case14.h6")

        err = DomainError("case15.h5", "The input data case15.h5 is not found.")
        @test_throws err powerSystem("case15.h5")
    end
end