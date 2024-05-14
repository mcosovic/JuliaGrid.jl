@testset "Load and Save Power System Data" begin
    systemMatlab = powerSystem(string(pathData, "case14test.m"))
    @base(systemMatlab, MVA, kV)

    savePowerSystem(systemMatlab; path = string(pathData, "case14test.h5"), reference = "IEEE 14", note = "Test Data")
    systemHDF5 = powerSystem(string(pathData, "case14test.h5"))
    @base(systemHDF5, MVA, kV)

    ####### Test Bus Data #######
    @test systemMatlab.bus.label == systemHDF5.bus.label
    @test systemMatlab.bus.number == systemHDF5.bus.number

    equalStruct(systemMatlab.bus.demand, systemHDF5.bus.demand)
    equalStruct(systemMatlab.bus.supply, systemHDF5.bus.supply)
    equalStruct(systemMatlab.bus.shunt, systemHDF5.bus.shunt)
    equalStruct(systemMatlab.bus.voltage, systemHDF5.bus.voltage)
    equalStruct(systemMatlab.bus.layout, systemHDF5.bus.layout)

    ####### Test Branch Data #######
    @test systemMatlab.branch.label == systemHDF5.branch.label
    @test systemMatlab.branch.number == systemHDF5.branch.number

    equalStruct(systemMatlab.branch.parameter, systemHDF5.branch.parameter)
    equalStruct(systemMatlab.branch.flow, systemHDF5.branch.flow)
    equalStruct(systemMatlab.branch.voltage, systemHDF5.branch.voltage)
    equalStruct(systemMatlab.branch.layout, systemHDF5.branch.layout)

    ####### Test Generator Data #######
    @test systemMatlab.generator.label == systemHDF5.generator.label
    @test systemMatlab.generator.number == systemHDF5.generator.number

    equalStruct(systemMatlab.generator.output, systemHDF5.generator.output)
    equalStruct(systemMatlab.generator.capability, systemHDF5.generator.capability)
    equalStruct(systemMatlab.generator.ramping, systemHDF5.generator.ramping)
    equalStruct(systemMatlab.generator.voltage, systemHDF5.generator.voltage)
    equalStruct(systemMatlab.generator.cost.active, systemHDF5.generator.cost.active)
    equalStruct(systemMatlab.generator.cost.reactive, systemHDF5.generator.cost.reactive)
    equalStruct(systemMatlab.generator.layout, systemHDF5.generator.layout)

    ####### Test Base Data #######
    equalStruct(systemMatlab.base.power, systemHDF5.base.power)
    equalStruct(systemMatlab.base.voltage, systemHDF5.base.voltage)

    @test systemMatlab.base.power.value == 100.0
    @test systemMatlab.base.power.unit == "MVA"
    @test systemMatlab.base.power.prefix == 1e6
    @test all(systemMatlab.base.voltage.value .== 138.0)
    @test systemMatlab.base.voltage.unit == "kV"
    @test systemMatlab.base.voltage.prefix == 1e3
end