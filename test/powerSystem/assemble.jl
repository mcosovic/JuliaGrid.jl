@testset "addBus, addGenerator, addBranch" begin
    pathData = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/data/")

    systemH5 = powerSystem(string(pathData, "case5test.h5"))

    system = powerSystem()
    system.basePower = 1e8

    addBus!(system; label = 1, base = 230000.0)
    addBus!(system; label = 2, active = 3.0, reactive = 0.9861, base = 230000.0)
    addBus!(system; label = 6, active = 3.0, reactive = 0.9861, conductance = 0.15, susceptance = -0.04, base = 230000.0)
    addBus!(system; label = 4, slackLabel = 4, active = 4.0, reactive = 1.3147, conductance = 0.20, susceptance = 0.04, base = 230000.0)
    addBus!(system; label = 5, base = 230000.0)

    addGenerator!(system; label = 1, bus = 1, active = 0.4, maxActive = 0.4, minReactive = -0.3, maxReactive = 0.3, activeDataPoint = 2, activeCoefficient = [14.0; 0.0])
    addGenerator!(system; label = 2, bus = 1, active = 1.7, reactive = 0.14, maxActive = 1.7, minReactive = -1.275, maxReactive = 1.275, activeDataPoint = 2, activeCoefficient = [15.0; 0.0])
    addGenerator!(system; label = 3, bus = 6, active = 3.2349, reactive = 0.12, maxActive = 5.2, minReactive = -3.9, maxReactive = 3.9, activeDataPoint = 2, activeCoefficient = [30.0; 0.0])
    addGenerator!(system; label = 4, bus = 4, maxActive = 2.0, minReactive = -1.5, maxReactive = 1.5, activeDataPoint = 2, activeCoefficient = [40.0; 0.0])
    addGenerator!(system; label = 5, bus = 5, active = 4.6651, maxActive = 6.0, minReactive = -4.5, maxReactive = 4.5, activeDataPoint = 2, activeCoefficient = [10.0; 0.0])

    addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.00281, reactance = 0.0281, susceptance = 0.00712)
    addBranch!(system; label = 2, from = 1, to = 4, resistance = 0.00304, reactance = 0.0304, susceptance = 0.00658)
    addBranch!(system; label = 3, from = 1, to = 5, resistance = 0.00064, reactance = 0.0064, susceptance = 0.03126, turnsRatio = 0.96, shiftAngle = -3*(pi/180))
    addBranch!(system; label = 4, from = 2, to = 6, resistance = 0.00108, reactance = 0.0108, susceptance = 0.01852, turnsRatio = 0.98, shiftAngle = 2*(pi/180))
    addBranch!(system; label = 5, from = 6, to = 4, resistance = 0.00297, reactance = 0.0297, susceptance = 0.00674)
    addBranch!(system; label = 6, from = 4, to = 5, resistance = 0.00297, reactance = 0.0297, susceptance = 0.00674)

   ######## Bus Data ##########
   @test system.bus.label == systemH5.bus.label
   @test system.bus.number == systemH5.bus.number

   @test system.bus.layout.type == systemH5.bus.layout.type
   @test system.bus.layout.area == systemH5.bus.layout.area
   @test system.bus.layout.lossZone == systemH5.bus.layout.lossZone
   @test system.bus.layout.slackIndex == systemH5.bus.layout.slackIndex
   @test system.bus.layout.slackImmutable == systemH5.bus.layout.slackImmutable
   @test system.bus.layout.renumbering == systemH5.bus.layout.renumbering

   @test system.bus.demand.active == systemH5.bus.demand.active
   @test system.bus.demand.reactive == systemH5.bus.demand.reactive

   @test system.bus.shunt.conductance == systemH5.bus.shunt.conductance
   @test system.bus.shunt.susceptance == systemH5.bus.shunt.susceptance

   @test system.bus.voltage.magnitude == systemH5.bus.voltage.magnitude
   @test system.bus.voltage.angle == systemH5.bus.voltage.angle
   @test system.bus.voltage.minMagnitude == systemH5.bus.voltage.minMagnitude
   @test system.bus.voltage.maxMagnitude == systemH5.bus.voltage.maxMagnitude
   @test system.bus.voltage.base == systemH5.bus.voltage.base

   @test system.bus.supply.active == systemH5.bus.supply.active
   @test system.bus.supply.reactive == systemH5.bus.supply.reactive
   @test system.bus.supply.inService == systemH5.bus.supply.inService

   ######## Branch Data ##########
   @test system.branch.label == systemH5.branch.label
   @test system.branch.number == systemH5.branch.number

   @test system.branch.layout.from == systemH5.branch.layout.from
   @test system.branch.layout.to == systemH5.branch.layout.to
   @test system.branch.layout.status == systemH5.branch.layout.status
   @test system.branch.layout.renumbering == systemH5.branch.layout.renumbering

   @test system.branch.parameter.resistance == systemH5.branch.parameter.resistance
   @test system.branch.parameter.reactance == systemH5.branch.parameter.reactance
   @test system.branch.parameter.susceptance == systemH5.branch.parameter.susceptance
   @test system.branch.parameter.turnsRatio == systemH5.branch.parameter.turnsRatio
   @test system.branch.parameter.shiftAngle == systemH5.branch.parameter.shiftAngle

   @test system.branch.rating.longTerm == systemH5.branch.rating.longTerm
   @test system.branch.rating.shortTerm == systemH5.branch.rating.shortTerm
   @test system.branch.rating.emergency == systemH5.branch.rating.emergency

   @test system.branch.voltage.minAngleDifference == systemH5.branch.voltage.minAngleDifference
   @test system.branch.voltage.maxAngleDifference == systemH5.branch.voltage.maxAngleDifference

   ######## Generator Data ##########
   @test system.generator.label == systemH5.generator.label
   @test system.generator.number == systemH5.generator.number

   @test system.generator.layout.bus == systemH5.generator.layout.bus
   @test system.generator.layout.area == systemH5.generator.layout.area
   @test system.generator.layout.status == systemH5.generator.layout.status
   @test system.generator.layout.violate == systemH5.generator.layout.violate

   @test system.generator.output.active == systemH5.generator.output.active
   @test system.generator.output.reactive == systemH5.generator.output.reactive

   @test system.generator.voltage.magnitude == systemH5.generator.voltage.magnitude

   @test system.generator.capability.minActive == systemH5.generator.capability.minActive
   @test system.generator.capability.maxActive == systemH5.generator.capability.maxActive
   @test system.generator.capability.minReactive == systemH5.generator.capability.minReactive
   @test system.generator.capability.maxReactive ≈ systemH5.generator.capability.maxReactive
   @test system.generator.capability.lowerActive == systemH5.generator.capability.lowerActive
   @test system.generator.capability.minReactiveLower == systemH5.generator.capability.minReactiveLower
   @test system.generator.capability.maxReactiveLower == systemH5.generator.capability.maxReactiveLower
   @test system.generator.capability.upperActive == systemH5.generator.capability.upperActive
   @test system.generator.capability.minReactiveUpper == systemH5.generator.capability.minReactiveUpper
   @test system.generator.capability.maxReactiveUpper == systemH5.generator.capability.maxReactiveUpper

   @test system.generator.rampRate.loadFollowing == systemH5.generator.rampRate.loadFollowing
   @test system.generator.rampRate.reserve10minute == systemH5.generator.rampRate.reserve10minute
   @test system.generator.rampRate.reserve30minute == systemH5.generator.rampRate.reserve30minute
   @test system.generator.rampRate.reactiveTimescale == systemH5.generator.rampRate.reactiveTimescale

   @test system.generator.cost.activeModel == systemH5.generator.cost.activeModel
   @test system.generator.cost.activeStartup == systemH5.generator.cost.activeStartup
   @test system.generator.cost.activeShutdown == systemH5.generator.cost.activeShutdown
   @test system.generator.cost.activeDataPoint == systemH5.generator.cost.activeDataPoint
   @test system.generator.cost.activeCoefficient == systemH5.generator.cost.activeCoefficient

   ######## Base Power ##########
   @test system.basePower == systemH5.basePower
end
