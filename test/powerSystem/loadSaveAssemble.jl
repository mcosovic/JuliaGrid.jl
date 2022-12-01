@testset "Load, Save, Assemble" begin
    pathData = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/data/")

    systemMat = powerSystem(string(pathData, "case5test.m"))

    savePowerSystem(systemMat; path = string(pathData, "case5test.h5"))
    # systemH5 = powerSystem(string(pathData, "case5test.h5"))

    # systemIn = powerSystem()
    # systemIn.basePower = 1e8

    # addBus!(systemIn; label = 1, base = 230000.0)
    # addBus!(systemIn; label = 2, active = 3.0, reactive = 0.9861, base = 230000.0)
    # addBus!(systemIn; label = 6, active = 3.0, reactive = 0.9861, conductance = 0.15, susceptance = -0.04, base = 230000.0)
    # addBus!(systemIn; label = 4, slackLabel = 4, active = 4.0, reactive = 1.3147, conductance = 0.20, susceptance = 0.04, base = 230000.0)
    # addBus!(systemIn; label = 5, base = 230000.0)

    # addGenerator!(systemIn; label = 1, bus = 1, active = 0.4, maxActive = 0.4, minReactive = -0.3, maxReactive = 0.3, activeDataPoint = 2, activeCoefficient = [14.0; 0.0])
    # addGenerator!(systemIn; label = 2, bus = 1, active = 1.7, reactive = 0.14, maxActive = 1.7, minReactive = -1.275, maxReactive = 1.275, activeDataPoint = 2, activeCoefficient = [15.0; 0.0])
    # addGenerator!(systemIn; label = 3, bus = 6, active = 3.2349, reactive = 0.12, maxActive = 5.2, minReactive = -3.9, maxReactive = 3.9, activeDataPoint = 2, activeCoefficient = [30.0; 0.0])
    # addGenerator!(systemIn; label = 4, bus = 4, maxActive = 2.0, minReactive = -1.5, maxReactive = 1.5, activeDataPoint = 2, activeCoefficient = [40.0; 0.0])
    # addGenerator!(systemIn; label = 5, bus = 5, active = 4.6651, maxActive = 6.0, minReactive = -4.5, maxReactive = 4.5, activeDataPoint = 2, activeCoefficient = [10.0; 0.0])

    # addBranch!(systemIn; label = 1, from = 1, to = 2, resistance = 0.00281, reactance = 0.0281, susceptance = 0.00712)
    # addBranch!(systemIn; label = 2, from = 1, to = 4, resistance = 0.00304, reactance = 0.0304, susceptance = 0.00658)
    # addBranch!(systemIn; label = 3, from = 1, to = 5, resistance = 0.00064, reactance = 0.0064, susceptance = 0.03126, turnsRatio = 0.96, shiftAngle = -3*(pi/180))
    # addBranch!(systemIn; label = 4, from = 2, to = 6, resistance = 0.00108, reactance = 0.0108, susceptance = 0.01852, turnsRatio = 0.98, shiftAngle = 2*(pi/180))
    # addBranch!(systemIn; label = 5, from = 6, to = 4, resistance = 0.00297, reactance = 0.0297, susceptance = 0.00674)
    # addBranch!(systemIn; label = 6, from = 4, to = 5, resistance = 0.00297, reactance = 0.0297, susceptance = 0.00674)

    # @test systemMat.bus.label == systemH5.bus.label == systemIn.bus.label
    # @test systemMat.bus.demand.active == systemH5.bus.demand.active == systemIn.bus.demand.active
    # @test systemMat.bus.demand.reactive == systemH5.bus.demand.reactive == systemIn.bus.demand.reactive
    # @test systemMat.bus.shunt.conductance == systemH5.bus.shunt.conductance == systemIn.bus.shunt.conductance
    # @test systemMat.bus.shunt.susceptance == systemH5.bus.shunt.susceptance == systemIn.bus.shunt.susceptance
    # @test systemMat.bus.voltage.magnitude == systemH5.bus.voltage.magnitude == systemIn.bus.voltage.magnitude
    # @test systemMat.bus.voltage.angle == systemH5.bus.voltage.angle == systemIn.bus.voltage.angle
    # @test systemMat.bus.voltage.minMagnitude == systemH5.bus.voltage.minMagnitude == systemIn.bus.voltage.minMagnitude
    # @test systemMat.bus.voltage.maxMagnitude == systemH5.bus.voltage.maxMagnitude == systemIn.bus.voltage.maxMagnitude
    # @test systemMat.bus.voltage.base == systemH5.bus.voltage.base == systemIn.bus.voltage.base
    # @test systemMat.bus.layout.type == systemH5.bus.layout.type == systemIn.bus.layout.type
    # @test systemMat.bus.layout.area == systemH5.bus.layout.area == systemIn.bus.layout.area
    # @test systemMat.bus.layout.lossZone == systemH5.bus.layout.lossZone == systemIn.bus.layout.lossZone
    # @test systemMat.bus.layout.slackIndex == systemH5.bus.layout.slackIndex == systemIn.bus.layout.slackIndex
    # @test systemMat.bus.layout.slackImmutable == systemH5.bus.layout.slackImmutable == systemIn.bus.layout.slackImmutable
    # @test systemMat.bus.layout.renumbering == systemH5.bus.layout.renumbering == systemIn.bus.layout.renumbering
    # @test systemMat.bus.supply.active == systemH5.bus.supply.active == systemIn.bus.supply.active
    # @test systemMat.bus.supply.reactive == systemH5.bus.supply.reactive == systemIn.bus.supply.reactive
    # @test systemMat.bus.supply.inService == systemH5.bus.supply.inService == systemIn.bus.supply.inService
    # @test systemMat.bus.number == systemH5.bus.number == systemIn.bus.number

    # @test systemMat.branch.label == systemH5.branch.label == systemIn.branch.label
    # @test systemMat.branch.parameter.resistance == systemH5.branch.parameter.resistance == systemIn.branch.parameter.resistance
    # @test systemMat.branch.parameter.reactance == systemH5.branch.parameter.reactance == systemIn.branch.parameter.reactance
    # @test systemMat.branch.parameter.susceptance == systemH5.branch.parameter.susceptance == systemIn.branch.parameter.susceptance
    # @test systemMat.branch.parameter.turnsRatio == systemH5.branch.parameter.turnsRatio == systemIn.branch.parameter.turnsRatio
    # @test systemMat.branch.parameter.shiftAngle == systemH5.branch.parameter.shiftAngle == systemIn.branch.parameter.shiftAngle
    # @test systemMat.branch.rating.longTerm == systemH5.branch.rating.longTerm == systemIn.branch.rating.longTerm
    # @test systemMat.branch.rating.shortTerm == systemH5.branch.rating.shortTerm == systemIn.branch.rating.shortTerm
    # @test systemMat.branch.rating.emergency == systemH5.branch.rating.emergency == systemIn.branch.rating.emergency
    # @test systemMat.branch.voltage.minAngleDifference == systemH5.branch.voltage.minAngleDifference == systemIn.branch.voltage.minAngleDifference
    # @test systemMat.branch.voltage.maxAngleDifference == systemH5.branch.voltage.maxAngleDifference == systemIn.branch.voltage.maxAngleDifference
    # @test systemMat.branch.layout.from == systemH5.branch.layout.from == systemIn.branch.layout.from
    # @test systemMat.branch.layout.to == systemH5.branch.layout.to == systemIn.branch.layout.to
    # @test systemMat.branch.layout.status == systemH5.branch.layout.status == systemIn.branch.layout.status
    # @test systemMat.branch.layout.renumbering == systemH5.branch.layout.renumbering == systemIn.branch.layout.renumbering
    # @test systemMat.branch.number == systemH5.branch.number == systemIn.branch.number

    # @test systemMat.generator.label == systemH5.generator.label == systemIn.generator.label
    # @test systemMat.generator.output.active == systemH5.generator.output.active == systemIn.generator.output.active
    # @test systemMat.generator.output.reactive == systemH5.generator.output.reactive == systemIn.generator.output.reactive
    # @test systemMat.generator.capability.minActive == systemH5.generator.capability.minActive == systemIn.generator.capability.minActive
    # @test systemMat.generator.capability.maxActive == systemH5.generator.capability.maxActive == systemIn.generator.capability.maxActive
    # @test systemMat.generator.capability.minReactive == systemH5.generator.capability.minReactive ≈ systemIn.generator.capability.minReactive
    # @test systemMat.generator.capability.maxReactive == systemH5.generator.capability.maxReactive ≈ systemIn.generator.capability.maxReactive
    # @test systemMat.generator.capability.lowerActive == systemH5.generator.capability.lowerActive == systemIn.generator.capability.lowerActive
    # @test systemMat.generator.capability.minReactiveLower == systemH5.generator.capability.minReactiveLower == systemIn.generator.capability.minReactiveLower
    # @test systemMat.generator.capability.maxReactiveLower == systemH5.generator.capability.maxReactiveLower == systemIn.generator.capability.maxReactiveLower
    # @test systemMat.generator.capability.upperActive == systemH5.generator.capability.upperActive == systemIn.generator.capability.upperActive
    # @test systemMat.generator.capability.minReactiveUpper == systemH5.generator.capability.minReactiveUpper == systemIn.generator.capability.minReactiveUpper
    # @test systemMat.generator.capability.maxReactiveUpper == systemH5.generator.capability.maxReactiveUpper == systemIn.generator.capability.maxReactiveUpper
    # @test systemMat.generator.rampRate.loadFollowing == systemH5.generator.rampRate.loadFollowing == systemIn.generator.rampRate.loadFollowing
    # @test systemMat.generator.rampRate.reserve10minute == systemH5.generator.rampRate.reserve10minute == systemIn.generator.rampRate.reserve10minute
    # @test systemMat.generator.rampRate.reserve30minute == systemH5.generator.rampRate.reserve30minute == systemIn.generator.rampRate.reserve30minute
    # @test systemMat.generator.rampRate.reactiveTimescale == systemH5.generator.rampRate.reactiveTimescale == systemIn.generator.rampRate.reactiveTimescale
    # @test systemMat.generator.cost.activeModel == systemH5.generator.cost.activeModel == systemIn.generator.cost.activeModel
    # @test systemMat.generator.cost.activeStartup == systemH5.generator.cost.activeStartup == systemIn.generator.cost.activeStartup
    # @test systemMat.generator.cost.activeShutdown == systemH5.generator.cost.activeShutdown == systemIn.generator.cost.activeShutdown
    # @test systemMat.generator.cost.activeDataPoint == systemH5.generator.cost.activeDataPoint == systemIn.generator.cost.activeDataPoint
    # @test systemMat.generator.cost.activeCoefficient == systemH5.generator.cost.activeCoefficient == systemIn.generator.cost.activeCoefficient
    # @test systemMat.generator.cost.reactiveModel == systemH5.generator.cost.reactiveModel
    # @test systemMat.generator.cost.reactiveStartup == systemH5.generator.cost.reactiveStartup
    # @test systemMat.generator.cost.reactiveShutdown == systemH5.generator.cost.reactiveShutdown
    # @test systemMat.generator.cost.reactiveDataPoint == systemH5.generator.cost.reactiveDataPoint
    # @test systemMat.generator.cost.reactiveCoefficient == systemH5.generator.cost.reactiveCoefficient
    # @test systemMat.generator.voltage.magnitude == systemH5.generator.voltage.magnitude == systemIn.generator.voltage.magnitude
    # @test systemMat.generator.layout.bus == systemH5.generator.layout.bus == systemIn.generator.layout.bus
    # @test systemMat.generator.layout.area == systemH5.generator.layout.area == systemIn.generator.layout.area
    # @test systemMat.generator.layout.status == systemH5.generator.layout.status == systemIn.generator.layout.status
    # @test systemMat.generator.layout.violate == systemH5.generator.layout.violate == systemIn.generator.layout.violate
    # @test systemMat.generator.number == systemH5.generator.number == systemIn.generator.number

    # @test systemMat.basePower == systemH5.basePower == systemIn.basePower
end
