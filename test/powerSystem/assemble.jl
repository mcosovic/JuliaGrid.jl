@testset "addBus!, addGenerator!, addBranch!" begin
    rad = pi / 180
    system = powerSystem(string(pathData, "part300.m"))
    
    systemPU = powerSystem()
    addBus!(systemPU; label = 152, active = 0.17, reactive = 0.09, magnitude = 1.0535, angle = 9.24 * rad, minMagnitude = 0.94, maxMagnitude = 1.06, base = 230e3)
    addBus!(systemPU; label = 153, magnitude = 1.0435, angle = 10.46 * rad, minMagnitude = 0.94, maxMagnitude = 1.06, base = 230e3)
    addBus!(systemPU; label = 154, active = 0.7, reactive = 0.05, susceptance = 0.345, magnitude = 0.9663, angle = -1.8 * rad, minMagnitude = 0.94, maxMagnitude = 1.06, base = 115e3)
    addBus!(systemPU; label = 155, active = 2, reactive = 0.5, magnitude = 1.0177, angle = 6.75 * rad, minMagnitude = 0.94, maxMagnitude = 1.06, base = 230e3)
    addBus!(systemPU; label = 156, active = 0.75, reactive = 0.5, magnitude = 0.963, angle = 5.15 * rad, minMagnitude = 0.94, maxMagnitude = 1.06, base = 115e3)
    addBus!(systemPU; label = 161, active = 0.35, reactive = 0.15, magnitude = 1.036, angle = 8.85 * rad, minMagnitude = 0.94, maxMagnitude = 1.06, base = 230e3)
    addBus!(systemPU; label = 164, susceptance = -2.12, magnitude = 0.9839, angle = 9.66 * rad, minMagnitude = 0.94, maxMagnitude = 1.06, base = 230e3)
    addBus!(systemPU; label = 183, active = 0.4, reactive = 0.04, magnitude = 0.9717, angle = 7.12 * rad, minMagnitude = 0.94, maxMagnitude = 1.06, base = 115e3)
    slackBus!(systemPU; label = 152)
    addBranch!(systemPU; label = 1, from = 164, to = 155, resistance = 0.0009, reactance = 0.0231, susceptance = -0.033, turnsRatio = 0.956, shiftAngle = 1.2 * rad, longTerm = 0.1, minDiffAngle = -360 * rad, maxDiffAngle = 360 * rad)
    addBranch!(systemPU; label = 2, from = 155, to = 156, resistance = 0.0008, reactance = 0.0256, turnsRatio = 1.05, minDiffAngle = -360 * rad, maxDiffAngle = 360 * rad)
    addBranch!(systemPU; label = 3, from = 154, to = 156, resistance = 0.1746, reactance = 0.3161, susceptance = 0.04, minDiffAngle = -360 * rad, maxDiffAngle = 360 * rad)
    addBranch!(systemPU; label = 4, from = 155, to = 161, resistance = 0.011, reactance = 0.0568, susceptance = 0.388, shortTerm = 0.05, minDiffAngle = -360 * rad, maxDiffAngle = 360 * rad)
    addBranch!(systemPU; label = 5, from = 153, to = 183, resistance = 0.0027, reactance = 0.0639, turnsRatio = 1.073, minDiffAngle = -360 * rad, maxDiffAngle = 360 * rad)
    addBranch!(systemPU; label = 6, from = 153, to = 161, resistance = 0.0055, reactance = 0.0288, susceptance = 0.19, minDiffAngle = -360 * rad, maxDiffAngle = 360 * rad)
    addBranch!(systemPU; label = 7, from = 152, to = 153, resistance = 0.0137, reactance = 0.0957, susceptance = 0.141, minDiffAngle = -360 * rad, maxDiffAngle = 360 * rad)
    addBranch!(systemPU; label = 8, from = 154, to = 183, resistance = 0.0804, reactance = 0.3054, susceptance = 0.045, emergency = 0.03, minDiffAngle = -360 * rad, maxDiffAngle = 360 * rad)
    addGenerator!(systemPU; label = 1, bus = 152, active = 3.72, minReactive = -0.5, maxReactive = 1.75, magnitude = 1.0535, maxActive = 4.72)
    addGenerator!(systemPU; label = 2, bus = 153, active = 2.16, reactive = 0.1, minReactive = -0.5, maxReactive = 0.9, magnitude = 1.0435, maxActive = 3.16)
    addGenerator!(systemPU; label = 3, bus = 153, active = 2.06, reactive = 0.3, minReactive = -0.5, maxReactive = 0.9, magnitude = 1.0435, maxActive = 3.16)

    ######### Bus ##########
    @test system.bus.label == systemPU.bus.label
    @test system.bus.number == systemPU.bus.number

    @test system.bus.demand.active ≈ systemPU.bus.demand.active
    @test system.bus.demand.reactive ≈ systemPU.bus.demand.reactive

    @test system.bus.supply.active ≈ systemPU.bus.supply.active
    @test system.bus.supply.reactive ≈ systemPU.bus.supply.reactive
    @test system.bus.supply.inService == systemPU.bus.supply.inService

    @test system.bus.shunt.conductance ≈ systemPU.bus.shunt.conductance
    @test system.bus.shunt.susceptance ≈ systemPU.bus.shunt.susceptance

    @test system.bus.voltage.magnitude ≈ systemPU.bus.voltage.magnitude
    @test system.bus.voltage.angle ≈ systemPU.bus.voltage.angle
    @test system.bus.voltage.minMagnitude ≈ systemPU.bus.voltage.minMagnitude
    @test system.bus.voltage.maxMagnitude ≈ systemPU.bus.voltage.maxMagnitude

    @test system.bus.layout.type == systemPU.bus.layout.type
    @test system.bus.layout.area == systemPU.bus.layout.area
    @test system.bus.layout.lossZone == systemPU.bus.layout.lossZone
    @test system.bus.layout.slack == systemPU.bus.layout.slack
    @test system.bus.layout.renumbering == systemPU.bus.layout.renumbering

    ######### Branch ##########
    @test system.branch.label == systemPU.branch.label == systemSI.branch.label
    @test system.branch.number == systemPU.branch.number == systemSI.branch.number

    @test system.branch.parameter.resistance ≈ systemPU.branch.parameter.resistance
    @test system.branch.parameter.reactance ≈ systemPU.branch.parameter.reactance
    @test system.branch.parameter.susceptance ≈ systemPU.branch.parameter.susceptance
    @test system.branch.parameter.turnsRatio == systemPU.branch.parameter.turnsRatio
    @test system.branch.parameter.shiftAngle == systemPU.branch.parameter.shiftAngle

    @test system.branch.rating.longTerm == systemPU.branch.rating.longTerm
    @test system.branch.rating.shortTerm == systemPU.branch.rating.shortTerm
    @test system.branch.rating.emergency == systemPU.branch.rating.emergency

    @test system.branch.voltage.minDiffAngle == systemPU.branch.voltage.minDiffAngle
    @test system.branch.voltage.maxDiffAngle == systemPU.branch.voltage.maxDiffAngle

    @test system.branch.layout.from == systemPU.branch.layout.from
    @test system.branch.layout.to == systemPU.branch.layout.to
    @test system.branch.layout.status == systemPU.branch.layout.status
    @test system.branch.layout.renumbering == systemPU.branch.layout.renumbering

    ######### Generator ##########
    @test system.generator.label == systemPU.generator.label
    @test system.generator.number == systemPU.generator.number

    @test system.generator.output.active == systemPU.generator.output.active
    @test system.generator.output.reactive == systemPU.generator.output.reactive

    @test system.generator.capability.minReactive == systemPU.generator.capability.minReactive
    @test system.generator.capability.maxReactive == systemPU.generator.capability.maxReactive
    @test system.generator.capability.minActive == systemPU.generator.capability.minActive
    @test system.generator.capability.maxActive == systemPU.generator.capability.maxActive

    @test system.generator.voltage.magnitude == systemPU.generator.voltage.magnitude

    @test system.generator.layout.bus == systemPU.generator.layout.bus
    @test system.generator.layout.status == systemPU.generator.layout.status
    @test system.generator.layout.area == systemPU.generator.layout.area
end
