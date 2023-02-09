@testset "slackBus!" begin
    manual = powerSystem(string(pathData, "part300.m"))

    slackBus!(manual; label = 154)
    @test manual.bus.layout.type[1] == 2
    @test manual.bus.layout.type[3] == 3
    
    slackBus!(manual; label = 153)
    @test manual.bus.layout.type[3] == 1 
    @test manual.bus.layout.type[2] == 3 
end

@testset "shuntBus!" begin
    @power(pu, pu, pu)

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
    @test manual.acModel.nodalMatrix == assemble.acModel.nodalMatrix
end

@testset "shuntBus!, SI Units" begin
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
    @test manual.acModel.nodalMatrix == assemble.acModel.nodalMatrix
end

@testset "statusBranch!" begin
    manual = powerSystem(string(pathData, "part300.m"))

    assemble = deepcopy(manual)

    manual.branch.layout.status[3] = 0
    acModel!(manual); dcModel!(manual)
    
    acModel!(assemble); dcModel!(assemble)
    statusBranch!(assemble; label = 3, status = 0)

    @test manual.branch.layout.status == assemble.branch.layout.status
    @test manual.acModel.nodalMatrix ≈ assemble.acModel.nodalMatrix
    @test manual.dcModel.nodalMatrix ≈ assemble.dcModel.nodalMatrix

    manual.branch.layout.status[3] = 1
    acModel!(manual); dcModel!(manual)

    statusBranch!(assemble; label = 3, status = 1)
    @test manual.branch.layout.status == assemble.branch.layout.status
    @test manual.acModel.nodalMatrix ≈ assemble.acModel.nodalMatrix
    @test manual.dcModel.nodalMatrix ≈ assemble.dcModel.nodalMatrix
end

@testset "parameterBranch!" begin
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
    @test manual.acModel.nodalMatrix ≈ assemble.acModel.nodalMatrix
    @test manual.dcModel.nodalMatrix ≈ assemble.dcModel.nodalMatrix
end

@testset "parameterBranch!, SI Units" begin
    manual = powerSystem(string(pathData, "part300.m"))
    assemble = deepcopy(manual)
    acModel!(assemble); dcModel!(assemble)
    acModel!(manual); dcModel!(manual)

    @voltage(V, deg)
    @parameter(kΩ, S)
    parameterBranch!(assemble; label = 1, resistance = 0.0004351, reactance = 0.0111682, susceptance = -0.0683e-03, turnsRatio = 0.956, shiftAngle = 10.2)

    @test manual.branch.parameter.resistance ≈ round.(assemble.branch.parameter.resistance, digits=4)
    @test manual.branch.parameter.reactance ≈ round.(assemble.branch.parameter.reactance, digits=4)
    @test manual.branch.parameter.susceptance ≈ round.(assemble.branch.parameter.susceptance, digits=4)
    @test manual.branch.parameter.turnsRatio ≈ assemble.branch.parameter.turnsRatio
    @test manual.branch.parameter.shiftAngle ≈ assemble.branch.parameter.shiftAngle
    @test round.(manual.acModel.nodalMatrix, digits=2) ≈ round.(assemble.acModel.nodalMatrix, digits=2)
    @test round.(manual.dcModel.nodalMatrix, digits=2) ≈ round.(assemble.dcModel.nodalMatrix, digits=2)
end