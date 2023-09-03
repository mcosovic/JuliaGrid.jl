@testset "shuntBus!" begin
    @default(unit)
    @default(template)

    manual = powerSystem(string(pathData, "part300.m"))
    assemble = deepcopy(manual)

    manual.bus.shunt.conductance[1] = 0.5
    manual.bus.shunt.susceptance[1] = 0.3
    manual.bus.shunt.susceptance[7] = 3.4
    acModel!(manual)

    acModel!(assemble)
    shuntBus!(assemble; label = 152, conductance = 0.5, susceptance = 0.3)
    shuntBus!(assemble; label = 164, susceptance = 3.4)
    shuntBus!(assemble; label = 154)

    equalStruct(manual.bus.shunt, assemble.bus.shunt)
    equalStruct(manual.model.ac, assemble.model.ac)
end

@testset "SI Units: shuntBus!" begin
    @power(kW, MVAr, pu)

    manual = powerSystem(string(pathData, "part300.m"))
    @base(manual, MVA, kV)

    assemble = deepcopy(manual)

    manual.bus.shunt.conductance[1] = 0.5
    manual.bus.shunt.susceptance[1] = 0.3
    manual.bus.shunt.susceptance[7] = 3.4
    acModel!(manual)

    acModel!(assemble)
    shuntBus!(assemble; label = 152, conductance = 50e3, susceptance = 30)
    shuntBus!(assemble; label = 164, susceptance = 340)
    shuntBus!(assemble; label = 154)

    equalStruct(manual.bus.shunt, assemble.bus.shunt)
    equalStruct(manual.model.ac, assemble.model.ac)
end

@testset "statusBranch!" begin
    manual = powerSystem(string(pathData, "part300.m"))

    assemble = deepcopy(manual)

    manual.branch.layout.status[3] = 0
    acModel!(manual); dcModel!(manual)

    acModel!(assemble); dcModel!(assemble)
    statusBranch!(assemble; label = 3, status = 0)

    equalStruct(manual.branch.layout, assemble.branch.layout)
    approxStruct(manual.model.ac, assemble.model.ac)

    manual.branch.layout.status[3] = 1
    acModel!(manual); dcModel!(manual)

    statusBranch!(assemble; label = 3, status = 1)

    equalStruct(manual.branch.layout, assemble.branch.layout)
    approxStruct(manual.model.ac, assemble.model.ac)
    approxStruct(manual.model.dc, assemble.model.dc)
end

@testset "parameterBranch!" begin
    @default(unit)

    manual = powerSystem(string(pathData, "part300.m"))
    assemble = deepcopy(manual)
    acModel!(assemble); dcModel!(assemble)

    manual.branch.parameter.resistance[3] = 0.5
    manual.branch.parameter.reactance[3] = 0.2
    manual.branch.parameter.susceptance[3] = 0.3
    manual.branch.parameter.turnsRatio[3] = 0.72
    manual.branch.parameter.shiftAngle[3] = 0.25
    acModel!(manual); dcModel!(manual)

    parameterBranch!(assemble; label = 3, resistance = 0.5, reactance = 0.2, susceptance = 0.3, turnsRatio = 0.72, shiftAngle = 0.25)

    equalStruct(manual.branch.parameter, assemble.branch.parameter)
    approxStruct(manual.model.ac, assemble.model.ac)
    approxStruct(manual.model.dc, assemble.model.dc)
end

@testset "SI Units: parameterBranch!" begin
    manual = powerSystem(string(pathData, "part300.m"))
    assemble = deepcopy(manual)
    acModel!(assemble); dcModel!(assemble)
    acModel!(manual); dcModel!(manual)

    @voltage(V, deg, kV)
    @parameter(kΩ, S)
    parameterBranch!(assemble; label = 1, resistance = 0.0004351, reactance = 0.0111682, susceptance = -0.0683e-03, turnsRatio = 0.956, shiftAngle = 10.2)

    approxStruct(manual.branch.parameter, assemble.branch.parameter, 1.0e-4)
    approxStruct(manual.model.ac, assemble.model.ac, 1.0e-3)
end

@testset "statusGenerator!" begin
    system1 = powerSystem(string(pathData, "part300Gen.m"))

    system2 = powerSystem(string(pathData, "part300.m"))
    system3 = deepcopy(system2)
    statusGenerator!(system2; label = 3, status = 0)

    equalStruct(system1.generator.layout, system2.generator.layout)
    approxStruct(system1.bus.supply, system2.bus.supply)

    statusGenerator!(system2; label = 3, status = 1)

    equalStruct(system3.generator.layout, system2.generator.layout)
    approxStruct(system3.bus.supply, system2.bus.supply)
end

@testset "outputGenerator!" begin
    system1 = powerSystem(string(pathData, "part300Gen2.m"))

    system2 = powerSystem(string(pathData, "part300.m"))
    outputGenerator!(system2; label = 3, active = 1.1, reactive = 1)

    equalStruct(system1.generator.output, system2.generator.output)
    approxStruct(system1.bus.supply, system2.bus.supply)
    equalStruct(system1.generator.layout, system2.generator.layout)
end

@testset "SI Units: outputGenerator!" begin
    @default(unit)

    system1 = powerSystem(string(pathData, "part300Gen2.m"))
    system2 = powerSystem(string(pathData, "part300.m"))

    @power(MW, MVAr, MVA)
    outputGenerator!(system2; label = 3, active = 110, reactive = 100)

    equalStruct(system1.generator.output, system2.generator.output)
    approxStruct(system1.bus.supply, system2.bus.supply)
    equalStruct(system1.generator.layout, system2.generator.layout)
end