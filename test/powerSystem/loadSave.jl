@testset "Load and Save Power System" begin
    systemMat = powerSystem(string(pathData, "case14test.m"))
    savePowerSystem(systemMat; path = string(pathData, "case14test.h5"))
    systemH5 = powerSystem(string(pathData, "case14test.h5"))

    ####### Bus Data ##########
    @test systemMat.bus.label == systemH5.bus.label
    @test systemMat.bus.number == systemH5.bus.number

    @test systemMat.bus.demand.active == systemH5.bus.demand.active
    @test systemMat.bus.demand.reactive == systemH5.bus.demand.reactive

    @test systemMat.bus.supply.active == systemH5.bus.supply.active
    @test systemMat.bus.supply.reactive == systemH5.bus.supply.reactive
    @test systemMat.bus.supply.inService == systemH5.bus.supply.inService
    @test systemMat.bus.supply.generator == systemH5.bus.supply.generator

    @test systemMat.bus.shunt.conductance == systemH5.bus.shunt.conductance
    @test systemMat.bus.shunt.susceptance == systemH5.bus.shunt.susceptance

    @test systemMat.bus.voltage.magnitude == systemH5.bus.voltage.magnitude
    @test systemMat.bus.voltage.angle == systemH5.bus.voltage.angle
    @test systemMat.bus.voltage.minMagnitude == systemH5.bus.voltage.minMagnitude
    @test systemMat.bus.voltage.maxMagnitude == systemH5.bus.voltage.maxMagnitude

    @test systemMat.bus.layout.type == systemH5.bus.layout.type
    @test systemMat.bus.layout.area == systemH5.bus.layout.area
    @test systemMat.bus.layout.lossZone == systemH5.bus.layout.lossZone
    @test systemMat.bus.layout.slack == systemH5.bus.layout.slack
    @test systemMat.bus.layout.renumbering == systemH5.bus.layout.renumbering

    ######## Branch Data ##########
    @test systemMat.branch.label == systemH5.branch.label
    @test systemMat.branch.number == systemH5.branch.number

    @test systemMat.branch.parameter.resistance == systemH5.branch.parameter.resistance
    @test systemMat.branch.parameter.reactance == systemH5.branch.parameter.reactance
    @test systemMat.branch.parameter.conductance == systemH5.branch.parameter.conductance
    @test systemMat.branch.parameter.susceptance == systemH5.branch.parameter.susceptance
    @test systemMat.branch.parameter.turnsRatio == systemH5.branch.parameter.turnsRatio
    @test systemMat.branch.parameter.shiftAngle == systemH5.branch.parameter.shiftAngle

    @test systemMat.branch.rating.longTerm == systemH5.branch.rating.longTerm
    @test systemMat.branch.rating.shortTerm == systemH5.branch.rating.shortTerm
    @test systemMat.branch.rating.emergency == systemH5.branch.rating.emergency
    @test systemMat.branch.rating.type == systemH5.branch.rating.type

    @test systemMat.branch.voltage.minDiffAngle == systemH5.branch.voltage.minDiffAngle
    @test systemMat.branch.voltage.maxDiffAngle == systemH5.branch.voltage.maxDiffAngle

    @test systemMat.branch.layout.from == systemH5.branch.layout.from
    @test systemMat.branch.layout.to == systemH5.branch.layout.to
    @test systemMat.branch.layout.status == systemH5.branch.layout.status
    @test systemMat.branch.layout.renumbering == systemH5.branch.layout.renumbering

    ######## Generator Data ##########
    @test systemMat.generator.label == systemH5.generator.label
    @test systemMat.generator.number == systemH5.generator.number

    @test systemMat.generator.output.active == systemH5.generator.output.active
    @test systemMat.generator.output.reactive == systemH5.generator.output.reactive

    @test systemMat.generator.capability.minActive == systemH5.generator.capability.minActive
    @test systemMat.generator.capability.maxActive == systemH5.generator.capability.maxActive
    @test systemMat.generator.capability.minReactive == systemH5.generator.capability.minReactive
    @test systemMat.generator.capability.maxReactive == systemH5.generator.capability.maxReactive
    @test systemMat.generator.capability.lowActive == systemH5.generator.capability.lowActive
    @test systemMat.generator.capability.minLowReactive == systemH5.generator.capability.minLowReactive
    @test systemMat.generator.capability.maxLowReactive == systemH5.generator.capability.maxLowReactive
    @test systemMat.generator.capability.upActive == systemH5.generator.capability.upActive
    @test systemMat.generator.capability.minUpReactive == systemH5.generator.capability.minUpReactive
    @test systemMat.generator.capability.maxUpReactive == systemH5.generator.capability.maxUpReactive

    @test systemMat.generator.ramping.loadFollowing == systemH5.generator.ramping.loadFollowing
    @test systemMat.generator.ramping.reserve10min == systemH5.generator.ramping.reserve10min
    @test systemMat.generator.ramping.reserve30min == systemH5.generator.ramping.reserve30min
    @test systemMat.generator.ramping.reactiveTimescale == systemH5.generator.ramping.reactiveTimescale

    @test systemMat.generator.voltage.magnitude == systemH5.generator.voltage.magnitude

    @test systemMat.generator.cost.active.model == systemH5.generator.cost.active.model
    @test systemMat.generator.cost.active.polynomial == systemH5.generator.cost.active.polynomial
    @test systemMat.generator.cost.active.piecewise == systemH5.generator.cost.active.piecewise
    @test systemMat.generator.cost.reactive.model == systemH5.generator.cost.reactive.model
    @test systemMat.generator.cost.reactive.polynomial == systemH5.generator.cost.reactive.polynomial
    @test systemMat.generator.cost.reactive.piecewise == systemH5.generator.cost.reactive.piecewise

    @test systemMat.generator.layout.bus == systemH5.generator.layout.bus
    @test systemMat.generator.layout.area == systemH5.generator.layout.area
    @test systemMat.generator.layout.status == systemH5.generator.layout.status

    ######## Base Power ##########
    @test systemMat.base.power.value == systemH5.base.power.value
    @test systemMat.base.power.unit == systemH5.base.power.unit
    @test systemMat.base.power.prefix == systemH5.base.power.prefix

    @test systemMat.base.voltage.value == systemH5.base.voltage.value
    @test systemMat.base.voltage.unit == systemH5.base.voltage.unit
    @test systemMat.base.voltage.prefix == systemH5.base.voltage.prefix
end

@testset "Base Values" begin
    systemMat = powerSystem(string(pathData, "case14test.m"))
    @base(systemMat, MVA, kV)

    savePowerSystem(systemMat; path = string(pathData, "case14test_temp.h5"))
    systemH5 = powerSystem(string(pathData, "case14test.h5"))
    @base(systemH5, MVA, kV)

    ######## Base Power ##########
    @test systemMat.base.power.value == 100.0
    @test systemH5.base.power.value == 100.0

    @test systemMat.base.power.unit == "MVA"
    @test systemH5.base.power.unit == "MVA"

    @test systemMat.base.power.prefix == 1e6
    @test systemH5.base.power.prefix == 1e6

    @test all(systemMat.base.voltage.value .== 138.0)
    @test all(systemMat.base.voltage.value .== 138.0)

    @test systemMat.base.voltage.unit == "kV"
    @test systemH5.base.voltage.unit == "kV"

    @test systemMat.base.voltage.prefix == 1e3
    @test systemH5.base.voltage.prefix == 1e3
end