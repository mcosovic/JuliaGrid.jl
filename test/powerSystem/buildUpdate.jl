@testset "Build and Update Power System Data in Per-Units" begin
    system = powerSystem(string(pathData, "build.m"))
    rad = pi / 180

    ################ Build Power System ################
    systemPU = powerSystem()

    @bus(area = 1, lossZone = 1, base = 230e3)
    @branch(minDiffAngle = 0, maxDiffAngle = 360 * pi / 180, susceptance = 0.14, resistance = 0.09, reactance = 0.02)
    @generator(minReactive = -0.5, maxReactive = 0.9)

    addBus!(systemPU; label = "1", type = 3, active = 0.17, conductance = 0.09)
    addBus!(systemPU; label = 2, type = 2, magnitude = 1.1, minMagnitude = 0.9, base = 115e3)
    addBus!(systemPU; label = 4, active = 0.7, reactive = 0.05, susceptance = 0.3)
    addBus!(systemPU; label = 5, active = 2, reactive = 0.5, angle = -1.8 * rad)
    addBus!(systemPU; label = 6, active = 0.75, reactive = 0.5, base = 115e3)
    addBus!(systemPU; active = 0.35, reactive = 0.15, magnitude = 0.9, maxMagnitude = 1.06)
    addBus!(systemPU; susceptance = -0.1, magnitude = 0.98, angle = 7.1 * rad)
    addBus!(systemPU; label = 9, active = 0.4, reactive = 0.04, base = 115e3)

    addBranch!(systemPU; from = 8, to = 5, susceptance = 0, turnsRatio = 0.956, shiftAngle = 2.2 * rad)
    addBranch!(systemPU; from = "5", to = "6", susceptance = 0, turnsRatio = 1.05)
    addBranch!(systemPU; from = 4, to = 6, resistance = 0.17, reactance = 0.31, status = 0)
    addBranch!(systemPU; from = 5, to = 7, resistance = 0.01, reactance = 0.05, shortTerm = 0.05)
    addBranch!(systemPU; from = 2, to = 9, reactance = 0.06, susceptance = 0, turnsRatio = 1.073)
    addBranch!(systemPU; from = 2, to = 7, resistance = 0.05, reactance = 0.02, status = 0)
    addBranch!(systemPU; from = 1, to = 2, resistance = 0.07, reactance = 0.09, longTerm = 0.1)
    addBranch!(systemPU; from = 4, to = 9, resistance = 0.08, reactance = 0.30, emergency = 0.03)

    @generator(label = "?")
    addGenerator!(systemPU; bus = "1", active = 3.7, maxReactive = 1.75, maxActive = 4.72)
    addGenerator!(systemPU; bus = 2, active = 2.1, magnitude = 1.1, maxActive = 3.16, status = 0)
    addGenerator!(systemPU; bus = 2, active = 2.6, reactive = 0.3, maxActive = 3.16)
    addGenerator!(systemPU; bus = 1, active = 0.8, reactive = 0.3, status = 0)

    cost!(systemPU; label = 1, active = 2, polynomial = [0.01 * 100^2; 40 * 100; 4])
    cost!(systemPU; label = 2, active = 2, polynomial = [0.0266666667 * 100^2; 20 * 100; 3])
    cost!(systemPU; label = 3, active = 2, polynomial = [0.0266666667 * 100^2; 20 * 100; 2])
    cost!(systemPU; label = 4, active = 2, polynomial = [30.0 * 100; 5])

    ####### Test Bus Data #######
    @test system.bus.label == systemPU.bus.label
    @test system.bus.number == systemPU.bus.number

    approxStruct(system.bus.demand, systemPU.bus.demand)
    approxStruct(system.bus.supply, systemPU.bus.supply)
    approxStruct(system.bus.shunt, systemPU.bus.shunt)
    approxStruct(system.bus.voltage, systemPU.bus.voltage)
    equalStruct(system.bus.layout, systemPU.bus.layout)

    ####### Test Branch Data #######
    @test system.branch.label == systemPU.branch.label
    @test system.branch.number == systemPU.branch.number

    approxStruct(system.branch.parameter, systemPU.branch.parameter)
    equalStruct(system.branch.flow, systemPU.branch.flow)
    equalStruct(system.branch.voltage, systemPU.branch.voltage)
    equalStruct(system.branch.layout, systemPU.branch.layout)

    ####### Test Generator Data #######
    @test system.generator.label == systemPU.generator.label
    @test system.generator.number == systemPU.generator.number

    equalStruct(system.generator.output, systemPU.generator.output)
    equalStruct(system.generator.capability, systemPU.generator.capability)
    equalStruct(system.generator.voltage, systemPU.generator.voltage)
    equalStruct(system.generator.cost.active, systemPU.generator.cost.active)
    equalStruct(system.generator.layout, systemPU.generator.layout)

    ####### Test Base Data #######
    equalStruct(system.base.power, systemPU.base.power)
    equalStruct(system.base.voltage, systemPU.base.voltage)

    ################ Update Power System ################
    system = powerSystem(string(pathData, "update.m"))

    updateBus!(systemPU; label = 1, conductance = 0.1, susceptance = -0.2, active = 0.3)
    updateBus!(systemPU; label = 2, type = 1, reactive = 0.2, magnitude = 1.2, base = 120e3)
    updateBus!(systemPU; label = 5, angle = -0.8 * rad, area = 2, lossZone = 3)
    updateBus!(systemPU; label = 8,  minMagnitude = 0.8, maxMagnitude = 1.2)

    updateBranch!(systemPU; label = 3, status = 1, susceptance = 0.1)
    updateBranch!(systemPU; label = 6, status = 1, resistance = 0.08, reactance = 0.04)
    updateBranch!(systemPU; label = 2, status = 0)
    updateBranch!(systemPU; label = 1, status = 0, resistance = 0.05, turnsRatio = 0.89, shiftAngle = 1.2 * rad)
    updateBranch!(systemPU; label = 8, minDiffAngle = -2 * rad, maxDiffAngle = rad)
    updateBranch!(systemPU; label = 7, longTerm = 5, shortTerm = 2, emergency = 4, type = 1)

    updateGenerator!(systemPU; label = 2, status = 1, magnitude = 1.2)
    updateGenerator!(systemPU; label = 4, status = 1, active = 0.1, reactive = 0.2)
    updateGenerator!(systemPU; label = 1, status = 0, minActive = 0.1, maxActive = 1)
    updateGenerator!(systemPU; label = 3, status = 0, active = 0.3, reactive = 0.1)
    updateGenerator!(systemPU; label = 1, minReactive = -0.1, maxReactive = 0.9)
    updateGenerator!(systemPU; label = 1, lowActive = 1, minLowReactive = 2, maxLowReactive = 3)
    updateGenerator!(systemPU; label = 1, upActive = 5, minUpReactive = 3, maxUpReactive = 4)
    updateGenerator!(systemPU; label = 1, loadFollowing = 5, reserve10min = 3, reactiveTimescale = 4)

    cost!(systemPU; label = 4, active = 2, polynomial = [0.3 * 100^2; 15 * 100; 5])

    ####### Test Bus Data #######
    @test system.bus.label == systemPU.bus.label
    @test system.bus.number == systemPU.bus.number

    approxStruct(system.bus.demand, systemPU.bus.demand)
    approxStruct(system.bus.supply, systemPU.bus.supply)
    approxStruct(system.bus.shunt, systemPU.bus.shunt)
    approxStruct(system.bus.voltage, systemPU.bus.voltage)
    equalStruct(system.bus.layout, systemPU.bus.layout)

    ####### Test Branch Data #######
    @test system.branch.label == systemPU.branch.label
    @test system.branch.number == systemPU.branch.number

    approxStruct(system.branch.parameter, systemPU.branch.parameter)
    equalStruct(system.branch.flow, systemPU.branch.flow)
    equalStruct(system.branch.voltage, systemPU.branch.voltage)
    equalStruct(system.branch.layout, systemPU.branch.layout)

    ####### Test Generator Data #######
    @test system.generator.label == systemPU.generator.label
    @test system.generator.number == systemPU.generator.number

    equalStruct(system.generator.output, systemPU.generator.output)
    equalStruct(system.generator.capability, systemPU.generator.capability)
    equalStruct(system.generator.voltage, systemPU.generator.voltage)
    equalStruct(system.generator.cost.active, systemPU.generator.cost.active)
    equalStruct(system.generator.layout, systemPU.generator.layout)

    ####### Test Base Data #######
    equalStruct(system.base.power, systemPU.base.power)
    equalStruct(system.base.voltage, systemPU.base.voltage)
end

@testset "Build and Update Power System Data in SI Units" begin
    system = powerSystem(string(pathData, "build.m"))
    @base(system, MVA, kV)

    ################ Build Power System ################
    @power(kW, MVAr, GVA)
    @voltage(kV, deg, MV)
    @parameter(Ω, S)
    @default(template)

    systemSI = powerSystem()
    @base(systemSI, MVA, kV)

    @bus(area = 1, lossZone = 1, base = 0.23)
    @branch(minDiffAngle = 0, maxDiffAngle = 360, susceptance = 0.14, resistance = 0.09, reactance = 0.02)
    @generator(minReactive = -50, maxReactive = 90)

    addBus!(systemSI; label = 1, type = 3, active = 17e3, conductance = 9e3)
    addBus!(systemSI; type = 2, magnitude = 1.1 * 115, minMagnitude = 0.9 * 115, base = 0.115)
    addBus!(systemSI; label = 4, active = 70e3, reactive = 5, susceptance = 30)
    addBus!(systemSI; label = 5, active = 200e3, reactive = 50, angle = -1.8)
    addBus!(systemSI; label = 6, active = 75e3, reactive = 50, base = 0.115)
    addBus!(systemSI; active = 35e3, reactive = 15, magnitude = 0.9 * 230, maxMagnitude = 1.06 * 230)
    addBus!(systemSI; susceptance = -10, magnitude = 0.98 * 230, angle = 7.1)
    addBus!(systemSI; label = 9, active = 40e3, reactive = 4, base = 0.115)

    Zb1 = (230e3 * 0.956)^2 / (100e6)
    Zb2 = (230e3 * 1.05)^2 / (100e6)
    Zb3 = 230^2 / 100
    Zb4 = (115e3 * 1.073)^2 / (100e6)
    Zb5 = 115^2 / 100

    addBranch!(systemSI; from = 8, to = 5, resistance = 0.09 * Zb1, reactance = 0.02 * Zb1, susceptance = 0, turnsRatio = 0.956, shiftAngle = 2.2)
    addBranch!(systemSI; from = 5, to = 6, resistance = 0.09 * Zb2, reactance = 0.02 * Zb2, susceptance = 0, turnsRatio = 1.05)
    addBranch!(systemSI; from = 4, to = 6, resistance = 0.17 * Zb3, reactance = 0.31 * Zb3, susceptance = 0.14 / Zb3, status = 0)
    addBranch!(systemSI; from = 5, to = 7, resistance = 0.01 * Zb3, reactance = 0.05 * Zb3, susceptance = 0.14 / Zb3, shortTerm = 5e-3)
    addBranch!(systemSI; from = 2, to = 9, resistance = 0.09 * Zb4, reactance = 0.06 * Zb4, susceptance = 0, turnsRatio = 1.073)
    addBranch!(systemSI; from = 2, to = 7, resistance = 0.05 * Zb5, reactance = 0.02 * Zb5, susceptance = 0.14 / Zb5, status = 0)
    addBranch!(systemSI; from = 1, to = 2, resistance = 0.07 * Zb3, reactance = 0.09 * Zb3, susceptance = 0.14 / Zb3, longTerm = 10e-3)
    addBranch!(systemSI; from = 4, to = 9, resistance = 0.08 * Zb3, reactance = 0.30 * Zb3, susceptance = 0.14 / Zb3,  emergency = 3e-3)

    addGenerator!(systemSI; bus = 1, active = 370e3, maxReactive = 175, maxActive = 472e3)
    addGenerator!(systemSI; bus = 2, active = 210e3, magnitude = 1.1 * 115, maxActive = 316e3, status = 0)
    addGenerator!(systemSI; bus = 2, active = 260e3, reactive = 30, maxActive = 316e3)
    addGenerator!(systemSI; bus = 1, active = 80e3, reactive = 30, status = 0)

    cost!(systemSI; label = 1, active = 2, polynomial = [0.01e-6; 40e-3; 4])
    cost!(systemSI; label = 2, active = 2, polynomial = [0.0266666667e-6; 20e-3; 3])
    cost!(systemSI; label = 3, active = 2, polynomial = [0.0266666667e-6; 20e-3; 2])
    cost!(systemSI; label = 4, active = 2, polynomial = [30.0e-3; 5])

    ####### Test Bus Data #######
    @test system.bus.label == systemSI.bus.label
    @test system.bus.number == systemSI.bus.number

    approxStruct(system.bus.demand, systemSI.bus.demand)
    approxStruct(system.bus.supply, systemSI.bus.supply)
    approxStruct(system.bus.shunt, systemSI.bus.shunt)
    approxStruct(system.bus.voltage, systemSI.bus.voltage)
    equalStruct(system.bus.layout, systemSI.bus.layout)

    ####### Test Branch Data #######
    @test system.branch.label == systemSI.branch.label
    @test system.branch.number == systemSI.branch.number

    approxStruct(system.branch.parameter, systemSI.branch.parameter)
    approxStruct(system.branch.flow, systemSI.branch.flow)
    equalStruct(system.branch.voltage, systemSI.branch.voltage)
    equalStruct(system.branch.layout, systemSI.branch.layout)

    ####### Test Generator Data #######
    @test system.generator.label == systemSI.generator.label
    @test system.generator.number == systemSI.generator.number

    equalStruct(system.generator.output, systemSI.generator.output)
    equalStruct(system.generator.capability, systemSI.generator.capability)
    equalStruct(system.generator.voltage, systemSI.generator.voltage)
    approxStruct(system.generator.cost.active, systemSI.generator.cost.active)
    equalStruct(system.generator.layout, systemSI.generator.layout)

    ####### Test Base Data #######
    equalStruct(system.base.power, systemSI.base.power)
    equalStruct(system.base.voltage, systemSI.base.voltage)

    ################ Update Power System ################
    system = powerSystem(string(pathData, "update.m"))
    @base(system, MVA, kV)

    updateBus!(systemSI; label = 1, conductance = 10e3, susceptance = -20, active = 30e3)
    updateBus!(systemSI; label = 2, type = 1, reactive = 20, magnitude = 1.2 * 120, base = 0.12)
    updateBus!(systemSI; label = 5, angle = -0.8, area = 2, lossZone = 3)
    updateBus!(systemSI; label = 8, minMagnitude = 0.8 * 230, maxMagnitude = 1.2 * 230)

    Zb1 = 230^2 / 100
    Zb2 = 120^2 / 100
    Zb3 = (230e3 * 0.89)^2 / (100e6)

    updateBranch!(systemSI; label = 3, status = 1, susceptance = 0.1 / Zb1)
    updateBranch!(systemSI; label = 6, status = 1, resistance = 0.08 * Zb2, reactance = 0.04 * Zb2)
    updateBranch!(systemSI; label = 2, status = 0)
    updateBranch!(systemSI; label = 1, status = 0, resistance = 0.05 * Zb3, turnsRatio = 0.89, shiftAngle = 1.2)
    updateBranch!(systemSI; label = 8, minDiffAngle = -2, maxDiffAngle = 1)
    updateBranch!(systemSI; label = 7, longTerm = 0.5, shortTerm = 0.2, emergency = 0.4, type = 1)

    updateGenerator!(systemSI; label = 2, status = 1, magnitude = 1.2 * 120)
    updateGenerator!(systemSI; label = 4, status = 1, active = 10e3, reactive = 20)
    updateGenerator!(systemSI; label = 1, status = 0, minActive = 10e3, maxActive = 100e3)
    updateGenerator!(systemSI; label = 3, status = 0, active = 30e3, reactive = 10)
    updateGenerator!(systemSI; label = 1, minReactive = -10, maxReactive = 90)
    updateGenerator!(systemSI; label = 1, lowActive = 100e3, minLowReactive = 200, maxLowReactive = 300)
    updateGenerator!(systemSI; label = 1, upActive = 500e3, minUpReactive = 300, maxUpReactive = 400)
    updateGenerator!(systemSI; label = 1, loadFollowing = 500e3, reserve10min = 300e3, reactiveTimescale = 400)

    cost!(systemSI; label = 4, active = 2, polynomial = [0.3e-6; 15e-3; 5])

    ####### Test Bus Data #######
    @test system.bus.label == systemSI.bus.label
    @test system.bus.number == systemSI.bus.number

    approxStruct(system.bus.demand, systemSI.bus.demand)
    approxStruct(system.bus.supply, systemSI.bus.supply)
    approxStruct(system.bus.shunt, systemSI.bus.shunt)
    approxStruct(system.bus.voltage, systemSI.bus.voltage)
    equalStruct(system.bus.layout, systemSI.bus.layout)

    ####### Test Branch Data #######
    @test system.branch.label == systemSI.branch.label
    @test system.branch.number == systemSI.branch.number

    approxStruct(system.branch.parameter, systemSI.branch.parameter)
    approxStruct(system.branch.flow, systemSI.branch.flow)
    equalStruct(system.branch.voltage, systemSI.branch.voltage)
    equalStruct(system.branch.layout, systemSI.branch.layout)

    ####### Test Generator Data #######
    @test system.generator.label == systemSI.generator.label
    @test system.generator.number == systemSI.generator.number

    equalStruct(system.generator.output, systemSI.generator.output)
    equalStruct(system.generator.capability, systemSI.generator.capability)
    equalStruct(system.generator.voltage, systemSI.generator.voltage)
    approxStruct(system.generator.cost.active, systemSI.generator.cost.active)
    equalStruct(system.generator.layout, systemSI.generator.layout)

    ####### Test Base Data #######
    equalStruct(system.base.power, systemSI.base.power)
    equalStruct(system.base.voltage, systemSI.base.voltage)
end

@testset "Build Power System Data in Per-Units Using Macros" begin
    @default(unit)
    @default(template)
    system = powerSystem()

    ################ Bus Macro ################
    @bus(label = "Bus ?", type = 2, active = 0.1, reactive = -0.2, conductance = 1e-2, susceptance = 1,
    magnitude = 1.1, angle = 0.2, minMagnitude = 0.8, maxMagnitude = 0.9, base = 100e3, area = 2, lossZone = 3)

    ####### Test Bus Data #######
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

    addBus!(system; type = 1, active = 0.3, reactive = -0.3, conductance = 1e-3, susceptance = 2,
    magnitude = 1.2, angle = 0.3, minMagnitude = 0.9, maxMagnitude = 1.1, base = 110e3, area = 3, lossZone = 4)
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

    ################ Branch Macro ################
    @branch(label = "Branch ?", status = 0, resistance = 0.1, reactance = 0.2, susceptance = 0.3,
    conductance = 0.4, turnsRatio = 0.5, shiftAngle = 0.6, minDiffAngle = -1.0, maxDiffAngle = 1.0,
    longTerm = 0.2, shortTerm = 0.3, emergency = 0.4, type = 2)

    ####### Test Branch Data #######
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
    @test system.branch.flow.longTerm[1] == 0.2
    @test system.branch.flow.shortTerm[1] == 0.3
    @test system.branch.flow.emergency[1] == 0.4
    @test system.branch.flow.type[1] == 2

    addBranch!(system;  from = "Bus 1", to = "Bus 2", status = 1, resistance = 1.1, reactance = 1.2,
    susceptance = 1.3, conductance = 1.4, turnsRatio = 1.5, shiftAngle = 1.6, minDiffAngle = -2.0,
    maxDiffAngle = 2.0, longTerm = 1.2, shortTerm = 1.3, emergency = 1.4, type = 3)
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
    @test system.branch.flow.longTerm[2] == 1.2
    @test system.branch.flow.shortTerm[2] == 1.3
    @test system.branch.flow.emergency[2] == 1.4
    @test system.branch.flow.type[2] == 3

    ################ Generator Macro ################
    @generator(label = "Generator ?", area = 2, status = 0, active = 1.1, reactive = 1.2, magnitude = 0.5,
    minActive = 0.1, maxActive = 0.2, minReactive = 0.3, maxReactive = 0.4, lowActive = 0.5, minLowReactive = 0.6,
    maxLowReactive = 0.7, upActive = 0.8, minUpReactive = 0.9, maxUpReactive = 1.0, loadFollowing = 1.1,
    reserve10min = 1.2, reserve30min = 1.3, reactiveTimescale = 1.4)

    ####### Test Generator Data #######
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
    @test system.generator.ramping.reactiveTimescale[1] == 1.4

    addGenerator!(system; label = "Generator 2", bus = "Bus 1", area = 1, status = 1, active = 2.1,
    reactive = 2.2, magnitude = 1.5, minActive = 1.1, maxActive = 1.2, minReactive = 1.3, maxReactive = 1.4,
    lowActive = 1.5, minLowReactive = 1.6, maxLowReactive = 1.7, upActive = 1.8, minUpReactive = 1.9,
    maxUpReactive = 2.0, loadFollowing = 2.1, reserve10min = 2.2, reserve30min = 2.3, reactiveTimescale = 2.4)
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
    @test system.generator.ramping.reactiveTimescale[2] == 2.4
end

@testset "Build Power System Data in SI Units Using Macros" begin
    @default(unit)
    @default(template)

    ################ Build Power System ################
    @power(kW, MVAr, GVA)
    @voltage(kV, deg, kV)
    @parameter(Ω, S)

    system = powerSystem()
    @base(system, MVA, kV)

    ################ Bus Macro ################
    @bus(label = "Bus ?", type = 2, active = 1e4, reactive = -20, conductance = 1e3, susceptance = 100,
    magnitude = 110, angle = 0.2 * 180 / pi, minMagnitude = 80, maxMagnitude = 90, base = 100, area = 2, lossZone = 3)

    ####### Test Bus Data #######
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
    @test system.base.voltage.value[1] == 100
    @test system.bus.layout.area[1] == 2
    @test system.bus.layout.lossZone[1] == 3

    ################ Branch Macro ################
    addBus!(system)
    @branch(label = "Branch ?", status = 0, resistance = 0.1 * (100e3 * 0.5)^2 / (100e6), reactance = 0.2 * (100e3 * 0.5)^2 / (100e6),
    susceptance = 0.3 / ((100e3 * 0.5)^2 / (100e6)), conductance = 0.4 / ((100e3 * 0.5)^2 / (100e6)), turnsRatio = 0.5,
    shiftAngle = 0.6 * 180 / pi, minDiffAngle = -1 * 180 / pi, maxDiffAngle = 1 * 180 / pi,
    longTerm = 0.2e5, shortTerm = 0.3e5, emergency = 0.4e5, type = 2)

    ####### Test Branch Data #######
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
    @test system.branch.flow.longTerm[1] == 0.2
    @test system.branch.flow.shortTerm[1] == 0.3
    @test system.branch.flow.emergency[1] == 0.4
    @test system.branch.flow.type[1] == 2

    ################ Generator Macro ################
    @generator(label = "Generator ?", area = 2, status = 0, active = 1.1e5, reactive = 1.2e2, magnitude = 50,
    minActive = 0.1e5, maxActive = 0.2e5, minReactive = 0.3e2, maxReactive = 0.4e2, lowActive = 0.5e5, minLowReactive = 0.6e2,
    maxLowReactive = 0.7e2, upActive = 0.8e5, minUpReactive = 0.9e2, maxUpReactive = 1.0e2, loadFollowing = 1.1e5,
    reserve10min = 1.2e5, reserve30min = 1.3e5, reactiveTimescale = 1.4e2)

    ####### Test Generator Data #######
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
    @test system.generator.capability.maxLowReactive[1] ≈ 0.7
    @test system.generator.capability.upActive[1] == 0.8
    @test system.generator.capability.minUpReactive[1] == 0.9
    @test system.generator.capability.maxUpReactive[1] == 1.0
    @test system.generator.ramping.loadFollowing[1] == 1.1
    @test system.generator.ramping.reserve10min[1] == 1.2
    @test system.generator.ramping.reserve30min[1] == 1.3
    @test system.generator.ramping.reactiveTimescale[1] ≈ 1.4
end

@testset "Test Errors and Messages" begin
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

    addBus!(system, label = "Bus 3")

    ####### Test Deleting Models #######
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

    ####### Test Bus Errors #######
    @test_throws ErrorException("The label Bus 1 is not unique.") addBus!(system; label = "Bus 1")
    @test_throws ErrorException("The value 4 of the bus type keyword is illegal.") addBus!(system; label = "Bus 4", type = 4)
    @test_throws ErrorException("The slack bus has already been designated.") addBus!(system; label = "Bus 5", type = 3)
    @test_throws ErrorException("The DC power flow model cannot be reused when adding a new bus.") addBus!(system, dc; label = "Bus 4", active = 0.1)
    @test_throws ErrorException("The AC power flow model cannot be reused when adding a new bus.") addBus!(system, nr; label = "Bus 4", active = 0.1)
    @test_throws ErrorException("The AC power flow model cannot be reused when adding a new bus.") addBus!(system, fnrxb; label = "Bus 4", active = 0.1)
    @test_throws ErrorException("The AC power flow model cannot be reused when adding a new bus.") addBus!(system, fnrbx; label = "Bus 4", active = 0.1)
    @test_throws ErrorException("The AC power flow model cannot be reused when adding a new bus.") addBus!(system, gs; label = "Bus 4", active = 0.1)

    @test_throws ErrorException("To set bus with label Bus 3 as the slack bus, reassign the current slack bus to either a generator or demand bus.") updateBus!(system; label = "Bus 3", type = 3)
    @test_throws ErrorException("The DC power flow model cannot be reused due to required bus type conversion.") updateBus!(system, dc; label = "Bus 1", type = 1)
    @test_throws ErrorException("The AC power flow model cannot be reused due to required bus type conversion.")  updateBus!(system, nr; label = "Bus 1", type = 1)
    @test_throws ErrorException("The AC power flow model cannot be reused due to required bus type conversion.")  updateBus!(system, fnrxb; label = "Bus 1", type = 1)
    @test_throws ErrorException("The AC power flow model cannot be reused due to required bus type conversion.")  updateBus!(system, fnrbx; label = "Bus 1", type = 1)
    @test_throws ErrorException("The AC power flow model cannot be reused due to required bus type conversion.")  updateBus!(system, gs; label = "Bus 1", type = 1)

    @test_throws LoadError @eval @bus(label = "Bus ?", typee = 1)

    ####### Test Branch Errors #######
    @test_throws ErrorException("The label Branch 1 is not unique.") addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2")
    @test_throws ErrorException("The provided value for the from or to keywords is not valid.") addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 1")
    @test_throws ErrorException("At least one of the keywords resistance or reactance must be provided.") addBranch!(system; label = "Branch 3", from = "Bus 1", to = "Bus 2")
    @test_throws ErrorException("The status 2 is not allowed; it should be either in-service (1) or out-of-service (0).") addBranch!(system; label = "Branch 4", from = "Bus 1", to = "Bus 2", resistance = 0.1, status = 2)

    @test_throws LoadError @eval @branch(label = "Branch ?", resistances = 1)

    ####### Test Generator Errors #######
    @test_throws ErrorException("The label Generator 1 is not unique.") addGenerator!(system; label = "Generator 1", bus = "Bus 1")
    @test_throws ErrorException("The status 2 is not allowed; it should be either in-service (1) or out-of-service (0).") addGenerator!(system; label = "Generator 2", bus = "Bus 1", status = 2)

    @test_throws ErrorException("The DC power flow model cannot be reused due to required bus type conversion.") updateGenerator!(system, dc; label = "Generator 1", status = 0)
    @test_throws ErrorException("The AC power flow model cannot be reused due to required bus type conversion.") updateGenerator!(system, nr; label = "Generator 1", status = 0)
    @test_throws ErrorException("The AC power flow model cannot be reused due to required bus type conversion.") updateGenerator!(system, gs; label = "Generator 1", status = 0)

    @test_throws ErrorException("The concurrent definition of the keywords active and reactive is not allowed.") cost!(system; label = "Generator 1", active = 2, reactive = 1, polynomial = [1100.0; 500.0; 150.0])
    @test_throws ErrorException("The cost model is missing.") cost!(system; label = "Generator 1", polynomial = [1100.0; 500.0; 150.0])
    @test_throws ErrorException("The model is not allowed; it should be either piecewise (1) or polynomial (2).") cost!(system; label = "Generator 1", active = 3, polynomial = [1100.0; 500.0; 150.0])
    @test_throws ErrorException("An attempt to assign a polynomial function has been made, but the polynomial function does not exist.") cost!(system; label = "Generator 1", active = 2)
    @test_throws ErrorException("An attempt to assign a piecewise function has been made, but the piecewise function does not exist.") cost!(system; label = "Generator 1", active = 1)

    @test_throws LoadError @eval @generator(label = "Generator ?", actives = 1)
end