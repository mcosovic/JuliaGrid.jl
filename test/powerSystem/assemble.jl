@testset "Build Power System: Per-Unit" begin
    system = powerSystem(string(pathData, "part300.m"))
    rad = pi / 180

    systemPU = powerSystem()
    @bus(minMagnitude = 0.94, maxMagnitude = 1.06, area = 1, lossZone = 1)
    addBus!(systemPU; label = 152, type = 3, active = 0.17, reactive = 0.09, magnitude = 1.0535, angle = 9.24 * rad, base = 230e3)
    addBus!(systemPU; label = 153, type = 2, magnitude = 1.0435, angle = 10.46 * rad, base = 230e3)
    addBus!(systemPU; label = 154, active = 0.7, reactive = 0.05, susceptance = 0.345, magnitude = 0.9663, angle = -1.8 * rad, base = 115e3)
    addBus!(systemPU; label = 155, active = 2, reactive = 0.5, magnitude = 1.0177, angle = 6.75 * rad, base = 230e3)
    addBus!(systemPU; label = 156, active = 0.75, reactive = 0.5, magnitude = 0.963, angle = 5.15 * rad, base = 115e3)
    addBus!(systemPU; label = 161, active = 0.35, reactive = 0.15, magnitude = 1.036, angle = 8.85 * rad, base = 230e3)
    addBus!(systemPU; label = 164, susceptance = -2.12, magnitude = 0.9839, angle = 9.66 * rad, base = 230e3)
    addBus!(systemPU; label = 183, active = 0.4, reactive = 0.04, magnitude = 0.9717, angle = 7.12 * rad, base = 115e3)

    @branch(minDiffAngle = -360 * pi / 180, maxDiffAngle = 360 * pi / 180)
    addBranch!(systemPU; from = 164, to = 155, resistance = 0.0009, reactance = 0.0231, susceptance = -0.033, turnsRatio = 0.956, shiftAngle = 10.2 * rad, longTerm = 0.1)
    addBranch!(systemPU; from = 155, to = 156, resistance = 0.0008, reactance = 0.0256, turnsRatio = 1.05)
    addBranch!(systemPU; from = 154, to = 156, resistance = 0.1746, reactance = 0.3161, susceptance = 0.04)
    addBranch!(systemPU; from = 155, to = 161, resistance = 0.011, reactance = 0.0568, susceptance = 0.388, shortTerm = 0.05)
    addBranch!(systemPU; from = 153, to = 183, resistance = 0.0027, reactance = 0.0639, turnsRatio = 1.073)
    addBranch!(systemPU; from = 153, to = 161, resistance = 0.0055, reactance = 0.0288, susceptance = 0.19)
    addBranch!(systemPU; from = 152, to = 153, resistance = 0.0137, reactance = 0.0957, susceptance = 0.141)
    addBranch!(systemPU; from = 154, to = 183, resistance = 0.0804, reactance = 0.3054, susceptance = 0.045, emergency = 0.03)

    addGenerator!(systemPU; bus = 152, active = 3.72, minReactive = -0.5, maxReactive = 1.75, magnitude = 1.0535, maxActive = 4.72)
    addGenerator!(systemPU; bus = 153, active = 2.16, reactive = 0.1, minReactive = -0.5, maxReactive = 0.9, magnitude = 1.0435, maxActive = 3.16)
    addGenerator!(systemPU; bus = 153, active = 2.06, reactive = 0.3, minReactive = -0.5, maxReactive = 0.9, magnitude = 1.0435, maxActive = 3.16)

    addActiveCost!(systemPU; label = 1, model = 2, polynomial = [0.01 * 100^2; 40 * 100; 4])
    addActiveCost!(systemPU; label = 2, model = 2, polynomial = [0.0266666667 * 100^2; 20 * 100; 3])
    addActiveCost!(systemPU; label = 3, model = 2, polynomial = [0.0266666667 * 100^2; 20 * 100; 2])

    ####### Bus Data ##########
    @test system.bus.label == systemPU.bus.label
    @test system.bus.number == systemPU.bus.number

    approxStruct(system.bus.demand, systemPU.bus.demand)
    approxStruct(system.bus.supply, systemPU.bus.supply)
    approxStruct(system.bus.shunt, systemPU.bus.shunt)
    approxStruct(system.bus.voltage, systemPU.bus.voltage)
    equalStruct(system.bus.layout, systemPU.bus.layout)

    ######## Branch Data ##########
    @test system.branch.label == systemPU.branch.label
    @test system.branch.number == systemPU.branch.number

    approxStruct(system.branch.parameter, systemPU.branch.parameter)
    equalStruct(system.branch.rating, systemPU.branch.rating)
    equalStruct(system.branch.voltage, systemPU.branch.voltage)
    equalStruct(system.branch.layout, systemPU.branch.layout)

    ######## Generator Data ##########
    @test system.generator.label == systemPU.generator.label
    @test system.generator.number == systemPU.generator.number

    equalStruct(system.generator.output, systemPU.generator.output)
    equalStruct(system.generator.capability, systemPU.generator.capability)
    equalStruct(system.generator.voltage, systemPU.generator.voltage)
    equalStruct(system.generator.cost.active, systemPU.generator.cost.active)
    equalStruct(system.generator.layout, systemPU.generator.layout)

    ######## Base Power ##########
    equalStruct(system.base.power, systemPU.base.power)
    equalStruct(system.base.voltage, systemPU.base.voltage)
end

@testset "Build Power System: SI Unit" begin
    system = powerSystem(string(pathData, "part300.m"))

    @power(MW, MVAr, MVA)
    @voltage(V, deg, kV)
    @parameter(Ω, S)
    @default(template)

    systemSI = powerSystem()
    @base(systemSI, MVA, kV)

    @bus(area = 1, lossZone = 1)
    addBus!(systemSI; label = 152, type = 3, active = 17, reactive = 9, magnitude = 1.0535 * 230e3, angle = 9.24, minMagnitude = 0.94 * 230e3, maxMagnitude = 1.06 * 230e3, base = 230)
    addBus!(systemSI; label = 153, type = 2, magnitude = 1.0435 * 230e3, angle = 10.46, minMagnitude = 0.94 * 230e3, maxMagnitude = 1.06 * 230e3, base = 230)
    addBus!(systemSI; label = 154, active = 70, reactive = 5, susceptance = 34.5, magnitude = 0.9663 * 115e3, angle = -1.8, minMagnitude = 0.94 * 115e3, maxMagnitude = 1.06 * 115e3, base = 115)
    addBus!(systemSI; label = 155, active = 200, reactive = 50, magnitude = 1.0177 * 230e3, angle = 6.75, minMagnitude = 0.94 * 230e3, maxMagnitude = 1.06 * 230e3, base = 230)
    addBus!(systemSI; label = 156, active = 75, reactive = 50, magnitude = 0.963 * 115e3, angle = 5.15, minMagnitude = 0.94 * 115e3, maxMagnitude = 1.06 * 115e3, base = 115)
    addBus!(systemSI; label = 161, active = 35, reactive = 15, magnitude = 1.036 * 230e3, angle = 8.85, minMagnitude = 0.94 * 230e3, maxMagnitude = 1.06 * 230e3, base = 230)
    addBus!(systemSI; label = 164, susceptance = -212, magnitude = 0.9839 * 230e3, angle = 9.66, minMagnitude = 0.94 * 230e3, maxMagnitude = 1.06 * 230e3, base = 230)
    addBus!(systemSI; label = 183, active = 40, reactive = 4, magnitude = 0.9717 * 115e3, angle = 7.12, minMagnitude = 0.94 * 115e3, maxMagnitude = 1.06 * 115e3, base = 115)

    @branch(minDiffAngle = -360, maxDiffAngle = 360)
    addBranch!(systemSI; from = 164, to = 155, resistance = 0.4351, reactance = 11.1682, susceptance = -0.0683e-03, turnsRatio = 0.956, shiftAngle = 10.2, longTerm = 10)
    addBranch!(systemSI; from = 155, to = 156, resistance = 0.4666, reactance = 14.9305, turnsRatio = 1.05)
    addBranch!(systemSI; from = 154, to = 156, resistance = 23.0909, reactance = 41.8042, susceptance = 0.3025e-3)
    addBranch!(systemSI; from = 155, to = 161, resistance = 5.8190, reactance = 30.0472, susceptance = 0.7335e-3, shortTerm = 5)
    addBranch!(systemSI; from = 153, to = 183, resistance = 1.6444, reactance = 38.9185, turnsRatio = 1.073)
    addBranch!(systemSI; from = 153, to = 161, resistance = 2.9095, reactance = 15.2352, susceptance = 0.3592e-3)
    addBranch!(systemSI; from = 152, to = 153, resistance = 7.2473, reactance = 50.6253, susceptance = 0.2665e-3)
    addBranch!(systemSI; from = 154, to = 183, resistance = 10.6329, reactance = 40.3892, susceptance = 0.3403e-3, emergency = 3)

    addGenerator!(systemSI; bus = 152, active = 372, minReactive = -50, maxReactive = 175, magnitude = 1.0535 * 230e3, maxActive = 472)
    addGenerator!(systemSI; bus = 153, active = 216, reactive = 10, minReactive = -50, maxReactive = 90, magnitude = 1.0435 * 230e3, maxActive = 316)
    addGenerator!(systemSI; bus = 153, active = 206, reactive = 30, minReactive = -50, maxReactive = 90, magnitude = 1.0435 * 230e3, maxActive = 316)

    addActiveCost!(systemSI; label = 1, model = 2, polynomial = [0.01; 40; 4])
    addActiveCost!(systemSI; label = 2, model = 2, polynomial = [0.0266666667; 20; 3])
    addActiveCost!(systemSI; label = 3, model = 2, polynomial = [0.0266666667; 20; 2])

    ####### Bus Data ##########
    @test system.bus.label == systemSI.bus.label
    @test system.bus.number == systemSI.bus.number

    approxStruct(system.bus.demand, systemSI.bus.demand)
    approxStruct(system.bus.supply, systemSI.bus.supply)
    approxStruct(system.bus.shunt, systemSI.bus.shunt)
    approxStruct(system.bus.voltage, systemSI.bus.voltage)
    equalStruct(system.bus.layout, systemSI.bus.layout)

    ######## Branch Data ##########
    @test system.branch.label == systemSI.branch.label
    @test system.branch.number == systemSI.branch.number

    approxStruct(system.branch.parameter, systemSI.branch.parameter, 1e-4)
    approxStruct(system.branch.rating, systemSI.branch.rating)
    equalStruct(system.branch.voltage, systemSI.branch.voltage)
    equalStruct(system.branch.layout, systemSI.branch.layout)

    ######## Generator Data ##########
    @test system.generator.label == systemSI.generator.label
    @test system.generator.number == systemSI.generator.number

    equalStruct(system.generator.output, systemSI.generator.output)
    approxStruct(system.generator.capability, systemSI.generator.capability)
    approxStruct(system.generator.voltage, systemSI.generator.voltage)
    equalStruct(system.generator.cost.active, systemSI.generator.cost.active)
    equalStruct(system.generator.layout, systemSI.generator.layout)
end