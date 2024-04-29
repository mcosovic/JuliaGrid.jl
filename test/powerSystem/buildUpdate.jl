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
