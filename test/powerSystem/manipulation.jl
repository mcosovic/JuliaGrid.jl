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

    @test manual.bus.shunt.conductance == assemble.bus.shunt.conductance
    @test manual.bus.shunt.susceptance == assemble.bus.shunt.susceptance
    @test manual.model.ac.nodalMatrix == assemble.model.ac.nodalMatrix
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

    @test manual.bus.shunt.conductance == assemble.bus.shunt.conductance
    @test manual.bus.shunt.susceptance == assemble.bus.shunt.susceptance
    @test manual.model.ac.nodalMatrix == assemble.model.ac.nodalMatrix
end

@testset "statusBranch!" begin
    manual = powerSystem(string(pathData, "part300.m"))

    assemble = deepcopy(manual)

    manual.branch.layout.status[3] = 0
    acModel!(manual); dcModel!(manual)

    acModel!(assemble); dcModel!(assemble)
    statusBranch!(assemble; label = 3, status = 0)

    @test manual.branch.layout.status == assemble.branch.layout.status
    @test manual.model.ac.nodalMatrix ≈ assemble.model.ac.nodalMatrix
    @test manual.model.dc.nodalMatrix ≈ assemble.model.dc.nodalMatrix

    manual.branch.layout.status[3] = 1
    acModel!(manual); dcModel!(manual)

    statusBranch!(assemble; label = 3, status = 1)
    @test manual.branch.layout.status == assemble.branch.layout.status
    @test manual.model.ac.nodalMatrix ≈ assemble.model.ac.nodalMatrix
    @test manual.model.dc.nodalMatrix ≈ assemble.model.dc.nodalMatrix
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

    @test manual.branch.parameter.resistance == assemble.branch.parameter.resistance
    @test manual.branch.parameter.reactance == assemble.branch.parameter.reactance
    @test manual.branch.parameter.susceptance == assemble.branch.parameter.susceptance
    @test manual.branch.parameter.turnsRatio == assemble.branch.parameter.turnsRatio
    @test manual.branch.parameter.shiftAngle == assemble.branch.parameter.shiftAngle
    @test manual.model.ac.nodalMatrix ≈ assemble.model.ac.nodalMatrix
    @test manual.model.dc.nodalMatrix ≈ assemble.model.dc.nodalMatrix
end

@testset "SI Units: parameterBranch!" begin
    manual = powerSystem(string(pathData, "part300.m"))
    assemble = deepcopy(manual)
    acModel!(assemble); dcModel!(assemble)
    acModel!(manual); dcModel!(manual)

    @voltage(V, deg, kV)
    @parameter(kΩ, S)
    parameterBranch!(assemble; label = 1, resistance = 0.0004351, reactance = 0.0111682, susceptance = -0.0683e-03, turnsRatio = 0.956, shiftAngle = 10.2)

    @test manual.branch.parameter.resistance ≈ assemble.branch.parameter.resistance atol=1.0e-6
    @test manual.branch.parameter.reactance ≈ assemble.branch.parameter.reactance atol=1.0e-6
    @test manual.branch.parameter.susceptance ≈ assemble.branch.parameter.susceptance atol=1.0e-4
    @test manual.branch.parameter.turnsRatio ≈ assemble.branch.parameter.turnsRatio
    @test manual.branch.parameter.shiftAngle ≈ assemble.branch.parameter.shiftAngle
    @test manual.model.ac.nodalMatrix ≈ assemble.model.ac.nodalMatrix atol=1.0e-3
    @test manual.model.dc.nodalMatrix ≈ assemble.model.dc.nodalMatrix atol=1.0e-3
end

@testset "statusGenerator!" begin
    system1 = powerSystem(string(pathData, "part300Gen.m"))

    system2 = powerSystem(string(pathData, "part300.m"))
    system3 = deepcopy(system2)
    statusGenerator!(system2; label = 3, status = 0)

    @test system1.generator.layout.status == system2.generator.layout.status
    @test system1.bus.supply.active ≈ system2.bus.supply.active
    @test system1.bus.supply.reactive ≈ system2.bus.supply.reactive
    @test system1.bus.supply.generator == system2.bus.supply.generator
    @test system1.bus.layout.type == system2.bus.layout.type

    statusGenerator!(system2; label = 3, status = 1)

    @test system3.generator.layout.status == system2.generator.layout.status
    @test system3.bus.supply.active ≈ system2.bus.supply.active
    @test system3.bus.supply.reactive ≈ system2.bus.supply.reactive
    @test system3.bus.supply.generator == system2.bus.supply.generator
    @test system3.bus.layout.type == system2.bus.layout.type
end

@testset "outputGenerator!" begin
    system1 = powerSystem(string(pathData, "part300Gen2.m"))

    system2 = powerSystem(string(pathData, "part300.m"))
    outputGenerator!(system2; label = 3, active = 1.1, reactive = 1)

    @test system1.generator.output.active == system2.generator.output.active
    @test system1.generator.output.reactive == system2.generator.output.reactive
    @test system1.bus.supply.active ≈ system2.bus.supply.active
    @test system1.bus.supply.reactive ≈ system2.bus.supply.reactive
    @test system1.bus.supply.generator == system2.bus.supply.generator
    @test system1.bus.layout.type == system2.bus.layout.type
end

@testset "SI Units: outputGenerator!" begin
    @default(unit)

    system1 = powerSystem(string(pathData, "part300Gen2.m"))
    system2 = powerSystem(string(pathData, "part300.m"))

    @power(MW, MVAr, MVA)
    outputGenerator!(system2; label = 3, active = 110, reactive = 100)

    @test system1.generator.output.active == system2.generator.output.active
    @test system1.generator.output.reactive == system2.generator.output.reactive
    @test system1.bus.supply.active ≈ system2.bus.supply.active
    @test system1.bus.supply.reactive ≈ system2.bus.supply.reactive
    @test system1.bus.supply.generator == system2.bus.supply.generator
    @test system1.bus.layout.type == system2.bus.layout.type
end