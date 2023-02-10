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
    
    addBranch!(systemPU; label = 1, from = 164, to = 155, resistance = 0.0009, reactance = 0.0231, susceptance = -0.033, turnsRatio = 0.956, shiftAngle = 10.2 * rad, longTerm = 0.1, minDiffAngle = -360 * rad, maxDiffAngle = 360 * rad)
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

    addActiveCost!(systemPU; label = 1, model = 2, polynomial = [0.01 * 100^2; 40 * 100; 4])
    addActiveCost!(systemPU; label = 2, model = 2, polynomial = [0.0266666667 * 100^2; 20 * 100; 3])
    addActiveCost!(systemPU; label = 3, model = 2, polynomial = [0.0266666667 * 100^2; 20 * 100; 2])

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
    @test system.branch.label == systemPU.branch.label
    @test system.branch.number == systemPU.branch.number

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

    @test system.generator.cost.active.model == systemPU.generator.cost.active.model
    @test system.generator.cost.active.polynomial == systemPU.generator.cost.active.polynomial
end

@testset "SI Units: addBus!, addGenerator!, addBranch!" begin
    rad = pi / 180
    system = powerSystem(string(pathData, "part300.m"))
    
    @power(MW, MVAr, MVA)
    @voltage(V, deg)
    @parameter(Ω, S)
    
    systemSI = powerSystem()
    @base(systemSI, MVA, kV)
    addBus!(systemSI; label = 152, active = 17, reactive = 9, magnitude = 1.0535 * 230e3, angle = 9.24, minMagnitude = 0.94 * 230e3, maxMagnitude = 1.06 * 230e3, base = 230)
    addBus!(systemSI; label = 153, magnitude = 1.0435 * 230e3, angle = 10.46, minMagnitude = 0.94 * 230e3, maxMagnitude = 1.06 * 230e3, base = 230)
    addBus!(systemSI; label = 154, active = 70, reactive = 5, susceptance = 34.5, magnitude = 0.9663 * 115e3, angle = -1.8, minMagnitude = 0.94 * 115e3, maxMagnitude = 1.06 * 115e3, base = 115)
    addBus!(systemSI; label = 155, active = 200, reactive = 50, magnitude = 1.0177 * 230e3, angle = 6.75, minMagnitude = 0.94 * 230e3, maxMagnitude = 1.06 * 230e3, base = 230)
    addBus!(systemSI; label = 156, active = 75, reactive = 50, magnitude = 0.963 * 115e3, angle = 5.15, minMagnitude = 0.94 * 115e3, maxMagnitude = 1.06 * 115e3, base = 115)
    addBus!(systemSI; label = 161, active = 35, reactive = 15, magnitude = 1.036 * 230e3, angle = 8.85, minMagnitude = 0.94 * 230e3, maxMagnitude = 1.06 * 230e3, base = 230)
    addBus!(systemSI; label = 164, susceptance = -212, magnitude = 0.9839 * 230e3, angle = 9.66, minMagnitude = 0.94 * 230e3, maxMagnitude = 1.06 * 230e3, base = 230)
    addBus!(systemSI; label = 183, active = 40, reactive = 4, magnitude = 0.9717 * 115e3, angle = 7.12, minMagnitude = 0.94 * 115e3, maxMagnitude = 1.06 * 115e3, base = 115)
    slackBus!(systemSI; label = 152)
   
    addBranch!(systemSI; label = 1, from = 164, to = 155, resistance = 0.4351, reactance = 11.1682, susceptance = -0.0683e-03, turnsRatio = 0.956, shiftAngle = 10.2, longTerm = 10, minDiffAngle = -360, maxDiffAngle = 360)
    addBranch!(systemSI; label = 2, from = 155, to = 156, resistance = 0.4666, reactance = 14.9305, turnsRatio = 1.05, minDiffAngle = -360, maxDiffAngle = 360)
    addBranch!(systemSI; label = 3, from = 154, to = 156, resistance = 23.0909, reactance = 41.8042, susceptance = 0.3025e-3, minDiffAngle = -360, maxDiffAngle = 360)        
    addBranch!(systemSI; label = 4, from = 155, to = 161, resistance = 5.8190, reactance = 30.0472, susceptance = 0.7335e-3, shortTerm = 5, minDiffAngle = -360, maxDiffAngle = 360)
    addBranch!(systemSI; label = 5, from = 153, to = 183, resistance = 1.6444, reactance = 38.9185, turnsRatio = 1.073, minDiffAngle = -360, maxDiffAngle = 360)
    addBranch!(systemSI; label = 6, from = 153, to = 161, resistance = 2.9095, reactance = 15.2352, susceptance = 0.3592e-3, minDiffAngle = -360, maxDiffAngle = 360)
    addBranch!(systemSI; label = 7, from = 152, to = 153, resistance = 7.2473, reactance = 50.6253, susceptance = 0.2665e-3, minDiffAngle = -360, maxDiffAngle = 360)
    addBranch!(systemSI; label = 8, from = 154, to = 183, resistance = 10.6329, reactance = 40.3892, susceptance = 0.3403e-3, emergency = 3, minDiffAngle = -360, maxDiffAngle = 360)
   
    addGenerator!(systemSI; label = 1, bus = 152, active = 372, minReactive = -50, maxReactive = 175, magnitude = 1.0535 * 230e3, maxActive = 472)
    addGenerator!(systemSI; label = 2, bus = 153, active = 216, reactive = 10, minReactive = -50, maxReactive = 90, magnitude = 1.0435 * 230e3, maxActive = 316)
    addGenerator!(systemSI; label = 3, bus = 153, active = 206, reactive = 30, minReactive = -50, maxReactive = 90, magnitude = 1.0435 * 230e3, maxActive = 316)

    addActiveCost!(systemPU; label = 1, model = 2, polynomial = [0.01; 40; 4])
    addActiveCost!(systemPU; label = 2, model = 2, polynomial = [0.0266666667; 20; 3])
    addActiveCost!(systemPU; label = 3, model = 2, polynomial = [0.0266666667; 20; 2])

    ######### Bus ##########
    @test system.bus.label == systemSI.bus.label
    @test system.bus.number == systemSI.bus.number
 
    @test system.bus.demand.active ≈ systemSI.bus.demand.active
    @test system.bus.demand.reactive ≈ systemSI.bus.demand.reactive
 
    @test system.bus.supply.active ≈ systemSI.bus.supply.active
    @test system.bus.supply.reactive ≈ systemSI.bus.supply.reactive
    @test system.bus.supply.inService == systemSI.bus.supply.inService
 
    @test system.bus.shunt.conductance ≈ systemSI.bus.shunt.conductance
    @test system.bus.shunt.susceptance ≈ systemSI.bus.shunt.susceptance
 
    @test system.bus.voltage.magnitude ≈ systemSI.bus.voltage.magnitude
    @test system.bus.voltage.angle ≈ systemSI.bus.voltage.angle
    @test system.bus.voltage.minMagnitude ≈ systemSI.bus.voltage.minMagnitude
    @test system.bus.voltage.maxMagnitude ≈ systemSI.bus.voltage.maxMagnitude
 
    @test system.bus.layout.type == systemSI.bus.layout.type
    @test system.bus.layout.area == systemSI.bus.layout.area
    @test system.bus.layout.lossZone == systemSI.bus.layout.lossZone
    @test system.bus.layout.slack == systemSI.bus.layout.slack
    @test system.bus.layout.renumbering == systemSI.bus.layout.renumbering
 
    ######### Branch ##########
    @test system.branch.label == systemSI.branch.label
    @test system.branch.number == systemSI.branch.number
 
    @test system.branch.parameter.resistance ≈ round.(systemSI.branch.parameter.resistance, digits=4)
    @test system.branch.parameter.reactance ≈ round.(systemSI.branch.parameter.reactance, digits=4)
    @test system.branch.parameter.susceptance ≈ round.(systemSI.branch.parameter.susceptance, digits=4)
    @test system.branch.parameter.turnsRatio ≈ systemSI.branch.parameter.turnsRatio
    @test system.branch.parameter.shiftAngle ≈ systemSI.branch.parameter.shiftAngle
 
    @test system.branch.rating.longTerm ≈ systemSI.branch.rating.longTerm
    @test system.branch.rating.shortTerm ≈ systemSI.branch.rating.shortTerm
    @test system.branch.rating.emergency ≈ systemSI.branch.rating.emergency
 
    @test system.branch.voltage.minDiffAngle ≈ systemSI.branch.voltage.minDiffAngle
    @test system.branch.voltage.maxDiffAngle ≈ systemSI.branch.voltage.maxDiffAngle
 
    @test system.branch.layout.from == systemSI.branch.layout.from
    @test system.branch.layout.to == systemSI.branch.layout.to
    @test system.branch.layout.status == systemSI.branch.layout.status
    @test system.branch.layout.renumbering == systemSI.branch.layout.renumbering
 
    ######### Generator ##########
    @test system.generator.label == systemSI.generator.label
    @test system.generator.number == systemSI.generator.number
 
    @test system.generator.output.active ≈ systemSI.generator.output.active
    @test system.generator.output.reactive ≈ systemSI.generator.output.reactive
 
    @test system.generator.capability.minReactive ≈ systemSI.generator.capability.minReactive
    @test system.generator.capability.maxReactive ≈ systemSI.generator.capability.maxReactive
    @test system.generator.capability.minActive ≈ systemSI.generator.capability.minActive
    @test system.generator.capability.maxActive ≈ systemSI.generator.capability.maxActive
 
    @test system.generator.voltage.magnitude ≈ systemSI.generator.voltage.magnitude
 
    @test system.generator.layout.bus == systemSI.generator.layout.bus
    @test system.generator.layout.status == systemSI.generator.layout.status
    @test system.generator.layout.area == systemSI.generator.layout.area

    @test system.generator.cost.active.model == systemPU.generator.cost.active.model
    @test system.generator.cost.active.polynomial == systemPU.generator.cost.active.polynomial
end