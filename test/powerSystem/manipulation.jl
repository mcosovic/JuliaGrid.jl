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

    # @test manual.bus.shunt.conductance == assemble.bus.shunt.conductance
    @test manual.bus.shunt.susceptance == assemble.bus.shunt.susceptance
    @test manual.acModel.nodalMatrix == assemble.acModel.nodalMatrix
end

@testset "shuntBus!, SI Units" begin
    @base(MVA, kV)
    @power(kW, MVAr, pu)

    manual = powerSystem(string(pathData, "part300.m"))
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