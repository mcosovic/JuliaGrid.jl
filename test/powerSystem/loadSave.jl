@testset "Load and Save Power System" begin
    systemMat = powerSystem(string(pathData, "case14test.m"))
    @base(systemMat, MVA, kV)

    savePowerSystem(systemMat; path = string(pathData, "case14test.h5"))
    systemH5 = powerSystem(string(pathData, "case14test.h5"))
    @base(systemH5, MVA, kV)

    ####### Bus Data #######
    @test systemMat.bus.label == systemH5.bus.label
    @test systemMat.bus.number == systemH5.bus.number

    equalStruct(systemMat.bus.demand, systemH5.bus.demand)
    equalStruct(systemMat.bus.supply, systemH5.bus.supply)
    equalStruct(systemMat.bus.shunt, systemH5.bus.shunt)
    equalStruct(systemMat.bus.voltage, systemH5.bus.voltage)
    equalStruct(systemMat.bus.layout, systemH5.bus.layout)

    ####### Branch Data #######
    @test systemMat.branch.label == systemH5.branch.label
    @test systemMat.branch.number == systemH5.branch.number

    equalStruct(systemMat.branch.parameter, systemH5.branch.parameter)
    equalStruct(systemMat.branch.flow, systemH5.branch.flow)
    equalStruct(systemMat.branch.voltage, systemH5.branch.voltage)
    equalStruct(systemMat.branch.layout, systemH5.branch.layout)

    ####### Generator Data #######
    @test systemMat.generator.label == systemH5.generator.label
    @test systemMat.generator.number == systemH5.generator.number

    equalStruct(systemMat.generator.output, systemH5.generator.output)
    equalStruct(systemMat.generator.capability, systemH5.generator.capability)
    equalStruct(systemMat.generator.ramping, systemH5.generator.ramping)
    equalStruct(systemMat.generator.voltage, systemH5.generator.voltage)
    equalStruct(systemMat.generator.cost.active, systemH5.generator.cost.active)
    equalStruct(systemMat.generator.cost.reactive, systemH5.generator.cost.reactive)
    equalStruct(systemMat.generator.layout, systemH5.generator.layout)

    ####### Base Power #######
    equalStruct(systemMat.base.power, systemH5.base.power)
    equalStruct(systemMat.base.voltage, systemH5.base.voltage)

    @test systemMat.base.power.value == 100.0
    @test systemMat.base.power.unit == "MVA"
    @test systemMat.base.power.prefix == 1e6
    @test all(systemMat.base.voltage.value .== 138.0)
    @test systemMat.base.voltage.unit == "kV"
    @test systemMat.base.voltage.prefix == 1e3
end