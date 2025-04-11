@testset "Reusing Newton-Raphson Method" begin
    @default(unit)
    @default(template)
    @config(label = Integer)

    system = powerSystem(path * "case14test.m")
    nr = newtonRaphson(system)

    @testset "Buses" begin
        updateBus!(nr; label = 14, active = 0.12, reactive = 0.13)
        testReusing(nr)

        updateBus!(nr; label = 14, conductance = 0.1, susceptance = 0.2)
        testReusing(nr)

        updateBus!(nr; label = 14, conductance = 0.3, susceptance = 0.1)
        testReusing(nr)

        updateBus!(nr; label = 14, magnitude = 1.2, angle = -0.17)
        testReusing(nr)

        updateBus!(nr; label = 7, active = 0.15)
        testReusing(nr)

        updateBus!(nr; label = 10, active = 0.12, susceptance = 0.05, angle = -0.21)
        testReusing(nr)

        updateBus!(system; label = 10, magnitude = 0.29, angle = -0.2, active = 0.2, reactive = 0.1)
        updateBus!(nr; label = 10, conductance = 0.1, susceptance = 0.2)
        testReusing(nr)

        power!(nr)
        current!(nr)
        testBus(nr)
        testBranch(nr)
        testGenerator(nr)
    end

    @testset "Branches" begin
        addBranch!(nr; from = 2, to = 3, resistance = 0.02, reactance = 0.35)
        testReusing(nr)

        addBranch!(nr; from = 3, to = 5, resistance = 0.02, reactance = 0.35, conductance = 0.001)
        testReusing(nr)

        addBranch!(nr; from = 11, to = 12, reactance = 0.12, turnsRatio = 0.95, shiftAngle = -0.17)
        testReusing(nr)

        addBranch!(nr; from = 16, to = 7, resistance = 0.01, reactance = 0.23, susceptance = 0.1)
        testReusing(nr)

        updateBranch!(nr; label = 12, resistance = 0.02, status = 1)
        testReusing(nr)

        updateBranch!(nr; label = 5, reactance = 0.28, susceptance = 0.001, status = 1)
        testReusing(nr)

        updateBranch!(nr; label = 5, turnsRatio = 0.99, status = 0)
        testReusing(nr)

        updateBranch!(nr; label = 5, status = 1)
        testReusing(nr)

        updateBranch!(nr; label = 5, status = 0)
        testReusing(nr)

        updateBranch!(nr; label = 12, status = 0)
        testReusing(nr)

        updateBranch!(system; label = 12, resistance = 0.03, reactance = 0.4, susceptance = 0.1)
        updateBranch!(nr; label = 12, conductance = 0.01, status = 1)
        testReusing(nr)

        addBranch!(system; from = 14, to = 13, resistance = 0.01, reactance = 0.23)
        updateBranch!(nr; label = 25, conductance = 0.01, status = 1)
        testReusing(nr)

        power!(nr)
        current!(nr)
        testBus(nr)
        testBranch(nr)
        testGenerator(nr)
    end

    @testset "Generators" begin
        addGenerator!(nr; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
        testReusing(nr)

        addGenerator!(nr; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)
        testReusing(nr)

        updateGenerator!(nr; label = 4, status = 0)
        testReusing(nr)

        updateGenerator!(nr; label = 4, status = 1)
        testReusing(nr)

        updateGenerator!(nr; label = 4, status = 0)
        testReusing(nr)

        updateGenerator!(nr; label = 7, active = 0.15, magnitude = 0.92)
        testReusing(nr)

        updateGenerator!(system; label = 4, active = 0.5, reactive = 0.3, magnitude = 0.98)
        updateGenerator!(nr; label = 4, status = 1)
        testReusing(nr)

        addGenerator!(system; bus = 2, active = 0.5, reactive = 0.1, magnitude = 0.97)
        updateGenerator!(nr; label = 11)
        testReusing(nr)

        power!(nr)
        current!(nr)
        testBus(nr)
        testBranch(nr)
        testGenerator(nr)
    end
end

@testset "Reusing Fast Newton-Raphson Method" begin
    @default(unit)
    @default(template)
    @config(label = Integer)

    system = powerSystem(path * "case14test.m")
    fnr = fastNewtonRaphsonBX(system)

    @testset "Buses" begin
        updateBus!(fnr; label = 14, active = 0.12, reactive = 0.13)
        testReusing(fnr)

        updateBus!(fnr; label = 14, conductance = 0.1, susceptance = 0.2)
        testReusing(fnr)

        updateBus!(fnr; label = 14, conductance = 0.3, susceptance = 0.0)
        testReusing(fnr)

        updateBus!(fnr; label = 14, magnitude = 1.2, angle = -0.17, susceptance = 0.3)
        testReusing(fnr)

        updateBus!(fnr; label = 7, active = 0.15)
        testReusing(fnr)

        updateBus!(fnr; label = 10, active = 0.12, susceptance = 0.005, angle = -0.21)
        testReusing(fnr)

        updateBus!(system; label = 10, magnitude = 0.29, angle = -0.2, susceptance = 0.2)
        updateBus!(fnr; label = 10, conductance = 0.1, active = 0.2, reactive = 0.1)
        testReusing(fnr)
    end

    @testset "Branches" begin
        addBranch!(fnr; from = 2, to = 3, resistance = 0.02, reactance = 0.35)
        testReusing(fnr)

        addBranch!(fnr; from = 3, to = 5, resistance = 0.02, reactance = 0.35, conductance = 0.001)
        testReusing(fnr)

        addBranch!(fnr; from = 11, to = 12, reactance = 0.12, turnsRatio = 0.95, shiftAngle = -0.17)
        testReusing(fnr)

        addBranch!(fnr; from = 16, to = 7, resistance = 0.01, reactance = 0.23, susceptance = 0.1)
        testReusing(fnr)

        updateBranch!(fnr; label = 12, resistance = 0.02, status = 1)
        testReusing(fnr)

        updateBranch!(fnr; label = 5, reactance = 0.28, susceptance = 0.001, status = 1)
        testReusing(fnr)

        updateBranch!(fnr; label = 5, turnsRatio = 0.99, status = 0)
        testReusing(fnr)

        updateBranch!(fnr; label = 5, status = 1)
        testReusing(fnr)

        updateBranch!(fnr; label = 5, status = 0)
        testReusing(fnr)

        updateBranch!(fnr; label = 12, status = 0)
        testReusing(fnr)

        addBranch!(system; from = 14, to = 13, resistance = 0.01, reactance = 0.23)
        updateBranch!(fnr; label = 25, conductance = 0.01, status = 1)
        testReusing(fnr)

        addBranch!(system; from = 1, to = 2, resistance = 0.01, reactance = 0.23)
        updateBranch!(fnr; label = 26)
        testReusing(fnr)

        addBranch!(system; from = 2, to = 1, resistance = 0.05, reactance = 0.42)
        updateBranch!(fnr; label = 27, susceptance = 0.1)
        testReusing(fnr)

        updateBranch!(fnr; label = 27, status = 0)
        testReusing(fnr)

        updateBranch!(system; label = 12, resistance = 0.03, reactance = 0.4, susceptance = 0.1)
        updateBranch!(fnr; label = 12, conductance = 0.01, status = 1)
        testReusing(fnr)
    end

    @testset "Generators" begin
        addGenerator!(fnr;  bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
        testReusing(fnr)

        addGenerator!(fnr; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)
        testReusing(fnr)

        updateGenerator!(fnr; label = 4, status = 0)
        testReusing(fnr)

        updateGenerator!(fnr; label = 4, status = 1)
        testReusing(fnr)

        updateGenerator!(fnr; label = 4, status = 0)
        testReusing(fnr)

        updateGenerator!(fnr; label = 7, active = 0.15, magnitude = 0.92)
        testReusing(fnr)

        updateGenerator!(system; label = 4, active = 0.5, reactive = 0.3, magnitude = 0.98)
        updateGenerator!(fnr; label = 4, status = 1)
        testReusing(fnr)

        addGenerator!(system; bus = 2, active = 0.5, reactive = 0.1, magnitude = 0.97)
        updateGenerator!(fnr; label = 11)
        testReusing(fnr)
    end
end

@testset "Reusing Gauss-Seidel Method" begin
    @default(template)

    system = powerSystem(path * "case14test.m")
    gs = gaussSeidel(system)

    @testset "Buses" begin
        updateBus!(gs; label = 14, active = 0.12, reactive = 0.13)
        testReusing(gs)

        updateBus!(gs; label = 14, conductance = 0.1, susceptance = 0.2)
        testReusing(gs)

        updateBus!(gs; label = 14, conductance = 0.3, susceptance = 0.1)
        testReusing(gs)

        updateBus!(gs; label = 14, magnitude = 1.2, angle = -0.17)
        testReusing(gs)

        updateBus!(gs; label = 7, active = 0.15)
        testReusing(gs)

        updateBus!(gs; label = 10, active = 0.12, susceptance = 0.005, angle = -0.21)
        testReusing(gs)

        updateBus!(system; label = 10, magnitude = 0.29, angle = -0.2, susceptance = 0.2)
        updateBus!(gs; label = 10, conductance = 0.1, active = 0.2, reactive = 0.1)
        testReusing(gs)
    end

    @testset "Branches" begin
        addBranch!(gs; from = 2, to = 3, resistance = 0.02, reactance = 0.35)
        testReusing(gs)

        addBranch!(gs; from = 3, to = 5, resistance = 0.02, reactance = 0.35, conductance = 0.001)
        testReusing(gs)

        addBranch!(gs; from = 11, to = 12, reactance = 0.12, turnsRatio = 0.95, shiftAngle = -0.17)
        testReusing(gs)

        addBranch!(gs; from = 16, to = 7, resistance = 0.01, reactance = 0.23, susceptance = 0.1)
        testReusing(gs)

        updateBranch!(gs; label = 12, resistance = 0.02, status = 1)
        testReusing(gs)

        updateBranch!(gs; label = 5, reactance = 0.28, susceptance = 0.001, status = 1)
        testReusing(gs)

        updateBranch!(gs; label = 5, turnsRatio = 0.99, status = 0)
        testReusing(gs)

        updateBranch!(gs; label = 5, status = 1)
        testReusing(gs)

        updateBranch!(gs; label = 5, status = 0)
        testReusing(gs)

        updateBranch!(gs; label = 12, status = 0)
        testReusing(gs)

        addBranch!(system; from = 14, to = 13, resistance = 0.01, reactance = 0.23)
        updateBranch!(gs; label = 25, conductance = 0.01, status = 1)
        testReusing(gs)
    end

    @testset "Generators" begin
        addGenerator!(gs;  bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
        testReusing(gs)

        addGenerator!(gs; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)
        testReusing(gs)

        updateGenerator!(gs; label = 4, status = 0)
        testReusing(gs)

        updateGenerator!(gs; label = 4, status = 1)
        testReusing(gs)

        updateGenerator!(gs; label = 4, status = 0)
        testReusing(gs)

        updateGenerator!(gs; label = 7, active = 0.15, magnitude = 0.92)
        testReusing(gs)

        addGenerator!(system; bus = 2, active = 0.5, reactive = 0.1, magnitude = 0.97)
        updateGenerator!(gs; label = 11)
        testReusing(gs)
    end
end

@testset "Reusing DC Power Flow" begin
    system = powerSystem(path * "case14test.m")
    dc = dcPowerFlow(system)

    @testset "Buses" begin
        updateBus!(dc; label = 3, active = 0.15, conductance = 0.16)
        testReusing(dc)

        updateBus!(dc; label = 3, conductance = 0.26)
        testReusing(dc)

        updateBus!(system; label = 4, conductance = 0.26)
        updateBus!(dc; label = 4)
        testReusing(dc)

        power!(dc)
        testBus(dc)
        testBranch(dc)
        testGenerator(dc)
    end

    @testset "Branches" begin
        addBranch!(dc; from = 16, to = 7, reactance = 0.03)
        testReusing(dc)

        addBranch!(dc; from = 16, to = 7, reactance = 0.08, status = 0)
        testReusing(dc)

        updateBranch!(dc; label = 4, shiftAngle = -1.2)
        testReusing(dc)

        updateBranch!(dc; label = 14, reactance = 0.03, status = 1)
        testReusing(dc)

        updateBranch!(dc; label = 10, reactance = 0.03, status = 0)
        testReusing(dc)

        updateBranch!(dc; label = 10, status = 1)
        testReusing(dc)

        updateBranch!(dc; label = 10, status = 0)
        testReusing(dc)

        addBranch!(system; from = 14, to = 13, resistance = 0.01, reactance = 0.23)
        updateBranch!(dc; label = 23, conductance = 0.01, status = 1)
        testReusing(dc)

        addBranch!(system; from = 14, to = 13, resistance = 0.01, reactance = 0.23, status = 0)
        updateBranch!(dc; label = 24)
        testReusing(dc)

        updateBranch!(dc; label = 24, status = 1)
        testReusing(dc)

        power!(dc)
        testBus(dc)
        testBranch(dc)
        testGenerator(dc)
    end

    @testset "Generators" begin
        addGenerator!(dc; bus = 2, active = 0.8)
        testReusing(dc)

        addGenerator!(dc; bus = 14, active = 0.5, status = 0)
        testReusing(dc)

        updateGenerator!(dc; label = 9, active = 1.2)
        testReusing(dc)

        updateGenerator!(dc; label = 7, status = 0)
        testReusing(dc)

        updateGenerator!(dc; label = 7, status = 1)
        testReusing(dc)

        updateGenerator!(dc; label = 7, status = 0)
        testReusing(dc)

        addGenerator!(system; bus = 2, active = 0.5, reactive = 0.1)
        updateGenerator!(dc; label = 11)
        testReusing(dc)

        addGenerator!(system; bus = 3, active = 0.8, status = 0)
        updateGenerator!(dc; label = 12)
        testReusing(dc)

        updateGenerator!(dc; label = 12, status = 1)
        testReusing(dc)

        power!(dc)
        testBus(dc)
        testBranch(dc)
        testGenerator(dc)
    end
end