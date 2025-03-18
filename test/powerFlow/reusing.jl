@testset "Reusing Newton-Raphson Method" begin
    @default(unit)
    @default(template)
    @config(label = Integer)

    ########## First Pass ##########
    system1 = powerSystem(path * "case14test.m")

    updateBus!(system1; label = 14, active = 0.12, reactive = 0.13)
    updateBus!(system1; label = 14, conductance = 0.1, susceptance = 0.2)
    updateBus!(system1; label = 14, magnitude = 1.2, angle = -0.17)
    updateBus!(system1; label = 7, active = 0.15)

    addBranch!(system1; from = 2, to = 3, resistance = 0.02, reactance = 0.35)
    addBranch!(system1; from = 3, to = 5, resistance = 0.02, reactance = 0.35, conductance = 0.001)
    addBranch!(system1; from = 11, to = 12, reactance = 0.12, turnsRatio = 0.95, shiftAngle = -0.17)

    updateBranch!(system1; label = 12, resistance = 0.02, status = 1)
    updateBranch!(system1; label = 5, reactance = 0.28, susceptance = 0.001, status = 1)
    updateBranch!(system1; label = 5, turnsRatio = 0.99, status = 0)

    addGenerator!(system1;  bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(system1; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)

    updateGenerator!(system1; label = 4, status = 0)
    updateGenerator!(system1; label = 7, active = 0.15, magnitude = 0.92)

    acModel!(system1)
    nr1 = newtonRaphson(system1)
    powerFlow!(system1, nr1; tolerance = 1e-12, power = true, current = true)

    # Reuse Newton-Raphson Model
    system2 = powerSystem(path * "case14test.m")
    acModel!(system2)
    nr2 = newtonRaphson(system2)

    updateBus!(system2, nr2; label = 14, active = 0.12, reactive = 0.13)
    updateBus!(system2, nr2; label = 14, conductance = 0.1, susceptance = 0.2)
    updateBus!(system2, nr2; label = 14, magnitude = 1.2, angle = -0.17)
    updateBus!(system2, nr2; label = 7, active = 0.15)

    addBranch!(system2, nr2; from = 2, to = 3, resistance = 0.02, reactance = 0.35)
    addBranch!(system2, nr2; from = 3, to = 5, resistance = 0.02, reactance = 0.35, conductance = 0.001)
    addBranch!(system2, nr2; from = 11, to = 12, reactance = 0.12, turnsRatio = 0.95, shiftAngle = -0.17)

    updateBranch!(system2, nr2; label = 12, resistance = 0.02, status = 1)
    updateBranch!(system2, nr2; label = 5, reactance = 0.28, susceptance = 0.001, status = 1)
    updateBranch!(system2, nr2; label = 5, turnsRatio = 0.99, status = 0)

    addGenerator!(system2, nr2;  bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(system2, nr2; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)

    updateGenerator!(system2, nr2; label = 4, status = 0)
    updateGenerator!(system2, nr2; label = 7, active = 0.15, magnitude = 0.92)

    powerFlow!(system2, nr2; tolerance = 1e-12, power = true, current = true)

    @testset "First Pass" begin
        compstruct(nr1.voltage, nr2.voltage; atol = 1e-10)
        compstruct(nr1.power, nr2.power; atol = 1e-10)
        compstruct(nr1.current, nr2.current; atol = 1e-8)
        @test nr1.method.iteration == nr2.method.iteration
    end

    ########## Second Pass ##########
    updateBus!(system1; label = 10, active = 0.12, susceptance = 0.005, angle = -0.21)
    updateBus!(system1; label = 10, reactive = 0.2, magnitude = 1.02)

    addBranch!(system1; from = 16, to = 7, resistance = 0.001, reactance = 0.23, susceptance = 0.1)

    updateBranch!(system1; label = 14, resistance = 0.02, reactance = 0.18, status = 1)
    updateBranch!(system1; label = 5, status = 1)

    addGenerator!(system1; bus = 2, active = 0.2, magnitude = 0.92)
    addGenerator!(system1; bus = 16, active = 0.3, reactive = 0.2)
    updateGenerator!(system1; label = 4, status = 0)
    updateGenerator!(system1; label = 7, reactive = 0.13, magnitude = 0.91)

    acModel!(system1)
    nr1 = newtonRaphson(system1)
    powerFlow!(system1, nr1; tolerance = 1e-12, power = true, current = true)

    # Reuse Newton-Raphson Model
    updateBus!(system2, nr2; label = 10, active = 0.12, susceptance = 0.005, angle = -0.21)
    updateBus!(system2, nr2; label = 10, reactive = 0.2, magnitude = 1.02)

    addBranch!(system2, nr2; from = 16, to = 7, resistance = 0.001, reactance = 0.23, susceptance = 0.1)

    updateBranch!(system2, nr2; label = 14, resistance = 0.02, reactance = 0.18, status = 1)
    updateBranch!(system2, nr2; label = 5, status = 1)

    addGenerator!(system2, nr2; bus = 2, active = 0.2, magnitude = 0.92)
    addGenerator!(system2, nr2; bus = 16, active = 0.3, reactive = 0.2)

    updateGenerator!(system2, nr2; label = 4, status = 0)
    updateGenerator!(system2, nr2; label = 7, reactive = 0.13, magnitude = 0.91)

    powerFlow!(system2, nr2; tolerance = 1e-12, power = true, current = true)

    @testset "Second Pass" begin
        compstruct(nr1.voltage, nr2.voltage; atol = 1e-10)
        compstruct(nr1.power, nr2.power; atol = 1e-10)
        compstruct(nr1.current, nr2.current; atol = 1e-8)
    end
end

@testset "Reusing Fast Newton-Raphson Method" begin
    ########## First Pass ##########
    system1 = powerSystem(path * "case14test.m")

    updateBus!(system1; label = 14, active = 0.12, reactive = 0.13, magnitude = 1.2)
    updateBus!(system1; label = 10, active = 0.12, susceptance = 0.05, angle = -0.21)
    updateBus!(system1; label = 7, active = 0.15)

    addBranch!(system1; from = 16, to = 7, resistance = 0.001, reactance = 0.13)
    addBranch!(system1; from = 11, to = 12, reactance = 0.12, turnsRatio = 0.95, shiftAngle = -0.17)

    updateBranch!(system1; label = 14, resistance = 0.02, reactance = 0.41, status = 1)
    updateBranch!(system1; label = 2, susceptance = 0.2)
    updateBranch!(system1; label = 13, status = 0)

    addGenerator!(system1; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(system1; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)

    updateGenerator!(system1; label = 4, status = 0)
    updateGenerator!(system1; label = 7, active = 0.15, magnitude = 0.92)

    acModel!(system1)
    fnr1 = fastNewtonRaphsonBX(system1)
    powerFlow!(system1, fnr1; iteration = 100, tolerance = 1e-12, power = true, current = true)

    # Reuse Fast Newton-Raphson Model
    system2 = powerSystem(path * "case14test.m")
    acModel!(system2)
    fnr2 = fastNewtonRaphsonBX(system2)

    updateBus!(system2, fnr2; label = 14, active = 0.12, reactive = 0.13, magnitude = 1.2)
    updateBus!(system2, fnr2; label = 10, active = 0.12, susceptance = 0.05, angle = -0.21)
    updateBus!(system2, fnr2; label = 7, active = 0.15)

    addBranch!(system2, fnr2; from = 16, to = 7, resistance = 0.001, reactance = 0.13)
    addBranch!(system2, fnr2; from = 11, to = 12, reactance = 0.12, turnsRatio = 0.95, shiftAngle = -0.17)

    updateBranch!(system2, fnr2; label = 14, resistance = 0.02, reactance = 0.41, status = 1)
    updateBranch!(system2, fnr2; label = 2, susceptance = 0.2)
    updateBranch!(system2, fnr2; label = 13, status = 0)

    addGenerator!(system2, fnr2; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(system2, fnr2; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)
    updateGenerator!(system2, fnr2; label = 4, status = 0)
    updateGenerator!(system2, fnr2; label = 7, active = 0.15, magnitude = 0.92)

    powerFlow!(system2, fnr2; iteration = 100, tolerance = 1e-12, power = true, current = true)

    @testset "First Pass" begin
        compstruct(fnr1.voltage, fnr2.voltage; atol = 1e-10)
        compstruct(fnr1.power, fnr2.power; atol = 1e-10)
        compstruct(fnr1.current, fnr2.current; atol = 1e-8)
        @test fnr1.method.iteration == fnr2.method.iteration
    end

    ########## Second Pass ##########
    updateBus!(system1; label = 10, active = 0.12, magnitude = 1.02, angle = -0.21)
    updateBus!(system1; label = 5, reactive = 0.12, conductance = 0.2)

    updateBranch!(system1; label = 22, status = 0)
    updateBranch!(system1; label = 13, reactance = 0.21, status = 1)

    addGenerator!(system1; bus = 2, active = 0.2, magnitude = 0.92)
    addGenerator!(system1; bus = 16, active = 0.3, reactive = 0.2)

    updateGenerator!(system1; label = 4, status = 0)
    updateGenerator!(system1; label = 7, reactive = 0.13, magnitude = 0.91)

    acModel!(system1)
    fnr1 = fastNewtonRaphsonBX(system1)
    powerFlow!(system1, fnr1; iteration = 100, tolerance = 1e-12, power = true, current = true)

    # Reuse Fast Newton-Raphson Model
    updateBus!(system2, fnr2; label = 10, active = 0.12, magnitude = 1.02, angle = -0.21)
    updateBus!(system2, fnr2; label = 5, reactive = 0.12, conductance = 0.2)

    updateBranch!(system2, fnr2; label = 22, status = 0)
    updateBranch!(system2, fnr2; label = 13, reactance = 0.21, status = 1)

    addGenerator!(system2, fnr2; bus = 2, active = 0.2, magnitude = 0.92)
    addGenerator!(system2, fnr2; bus = 16, active = 0.3, reactive = 0.2)

    updateGenerator!(system2, fnr2; label = 4, status = 0)
    updateGenerator!(system2, fnr2; label = 7, reactive = 0.13, magnitude = 0.91)

    powerFlow!(system2, fnr2; iteration = 100, tolerance = 1e-12, power = true, current = true)

    @testset "Second Pass" begin
        compstruct(fnr1.voltage, fnr2.voltage; atol = 1e-10)
        compstruct(fnr1.power, fnr2.power; atol = 1e-10)
        compstruct(fnr1.current, fnr2.current; atol = 1e-8)
    end
end

@testset "Reusing Gauss-Seidel Method" begin
    @default(template)

    ########## First Pass ##########
    system1 = powerSystem(path * "case14test.m")

    updateBus!(system1; label = 14, reactive = 0.13, conductance = 0.1, angle = -0.17)
    updateBus!(system1; label = 14, active = 0.12, susceptance = 0.2, magnitude = 1.2)
    updateBus!(system1; label = 7, active = 0.15)

    addBranch!(system1; from = 2, to = 5, resistance = 0.02, reactance = 0.35)
    addBranch!(system1; from = 3, to = 5, resistance = 0.02, reactance = 0.35, conductance = 0.001)
    addBranch!(system1; from = 11, to = 12, reactance = 0.12, turnsRatio = 0.95, shiftAngle = -0.17)

    updateBranch!(system1; label = 12, resistance = 0.02, reactance = 0.31, status = 0)
    updateBranch!(system1; label = 2, resistance = 0.02, reactance = 0.15, status = 0)
    updateBranch!(system1; label = 2, status = 1)

    addGenerator!(system1; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(system1; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)

    updateGenerator!(system1; label = 4, status = 0)
    updateGenerator!(system1; label = 7, active = 0.15, magnitude = 0.92)

    acModel!(system1)
    gs1 = gaussSeidel(system1)
    powerFlow!(system1, gs1; iteration = 1000, tolerance = 1e-12, power = true, current = true)

    # Reuse Gauss-Seidel Model
    system2 = powerSystem(path * "case14test.m")
    acModel!(system2)
    gs2 = gaussSeidel(system2)

    updateBus!(system2, gs2; label = 14, reactive = 0.13, conductance = 0.1, angle = -0.17)
    updateBus!(system2, gs2; label = 14, active = 0.12, susceptance = 0.2, magnitude = 1.2)
    updateBus!(system2, gs2; label = 7, active = 0.15)

    addBranch!(system2, gs2; from = 2, to = 5, resistance = 0.02, reactance = 0.35)
    addBranch!(system2, gs2; from = 3, to = 5, resistance = 0.02, reactance = 0.35, conductance = 0.001)
    addBranch!(system2, gs2; from = 11, to = 12, reactance = 0.12, turnsRatio = 0.95, shiftAngle = -0.17)

    updateBranch!(system2, gs2; label = 12, resistance = 0.02, reactance = 0.31, status = 0)
    updateBranch!(system2, gs2; label = 2, resistance = 0.02, reactance = 0.15, status = 0)
    updateBranch!(system2, gs2; label = 2, status = 1)

    addGenerator!(system2, gs2; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(system2, gs2; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)

    updateGenerator!(system2, gs2; label = 4, status = 0)
    updateGenerator!(system2, gs2; label = 7, active = 0.15, magnitude = 0.92)

    powerFlow!(system2, gs2; iteration = 1000, tolerance = 1e-12, power = true, current = true)

    @testset "First Pass" begin
        compstruct(gs1.voltage, gs2.voltage; atol = 1e-10)
        compstruct(gs1.power, gs2.power; atol = 1e-10)
        compstruct(gs1.current, gs2.current; atol = 1e-8)
        @test gs1.method.iteration == gs2.method.iteration
    end

    ########## Second Pass ##########
    updateBus!(system1; label = 10, active = 0.12, susceptance = 0.05, magnitude = 1.02)
    updateBus!(system1; label = 4, reactive = 0.1, conductance = 0.5, angle = -0.2)

    addBranch!(system1; from = 16, to = 7, resistance = 0.01, reactance = 0.3, susceptance = 0.1)
    addBranch!(system1; from = 16, to = 2, resistance = 0.01, reactance = 0.16)

    updateBranch!(system1; label = 14, resistance = 0.02, reactance = 0.11, status = 1)
    updateBranch!(system1; label = 25, status = 0)

    addGenerator!(system1; bus = 2, active = 0.2, magnitude = 0.92)
    addGenerator!(system1; bus = 16, active = 0.3, reactive = 0.2)

    updateGenerator!(system1; label = 4, status = 0)
    updateGenerator!(system1; label = 7, reactive = 0.13, magnitude = 0.91)

    acModel!(system1)
    gs1 = gaussSeidel(system1)
    powerFlow!(system1, gs1; iteration = 1000, tolerance = 1e-12, power = true, current = true)

    # Reuse Gauss-Seidel Model
    updateBus!(system2, gs2; label = 10, active = 0.12, susceptance = 0.05, magnitude = 1.02)
    updateBus!(system2, gs2; label = 4, reactive = 0.1, conductance = 0.5, angle = -0.2)

    addBranch!(system2, gs2; from = 16, to = 7, resistance = 0.01, reactance = 0.3, susceptance = 0.1)
    addBranch!(system2, gs2; from = 16, to = 2, resistance = 0.01, reactance = 0.16)

    updateBranch!(system2, gs2; label = 14, resistance = 0.02, reactance = 0.11, status = 1)
    updateBranch!(system2, gs2; label = 25, status = 0)

    addGenerator!(system2, gs2; bus = 2, active = 0.2, magnitude = 0.92)
    addGenerator!(system2, gs2; bus = 16, active = 0.3, reactive = 0.2)

    updateGenerator!(system2, gs2; label = 4, status = 0)
    updateGenerator!(system2, gs2; label = 7, reactive = 0.13, magnitude = 0.91)

    setInitialPoint!(system2, gs2)
    powerFlow!(system2, gs2; iteration = 1000, tolerance = 1e-12, power = true, current = true)

    @testset "Second Pass" begin
        compstruct(gs1.voltage, gs2.voltage; atol = 1e-10)
        compstruct(gs1.power, gs2.power; atol = 1e-10)
        compstruct(gs1.current, gs2.current; atol = 1e-8)
    end
end

@testset "Reusing DC Power Flow" begin
    ########## First Pass ##########
    system1 = powerSystem(path * "case14test.m")

    updateBus!(system1; label = 1, active = 0.15, conductance = 0.16)

    addGenerator!(system1; bus = 2, active = 0.8)
    addGenerator!(system1; bus = 14, active = 0.5, status = 0)

    updateGenerator!(system1; label = 9, active = 1.2)
    updateGenerator!(system1; label = 1, status = 0)
    updateGenerator!(system1; label = 7, status = 1)

    dc1 = dcPowerFlow(system1)
    powerFlow!(system1, dc1; power = true)

    # Reuse DC Power Flow Model
    system2 = powerSystem(path * "case14test.m")
    dc2 = dcPowerFlow(system2)

    updateBus!(system2, dc2; label = 1, active = 0.15, conductance = 0.16)

    addGenerator!(system2, dc2; bus = 2, active = 0.8)
    addGenerator!(system2, dc2; bus = 14, active = 0.5, status = 0)

    updateGenerator!(system2, dc2; label = 9, active = 1.2)
    updateGenerator!(system2, dc2; label = 1, status = 0)
    updateGenerator!(system2, dc2; label = 7, status = 1)

    powerFlow!(system2, dc2; power = true)

    relsystem2 = copy(system2.model.dc.model)
    reldc2 = copy(dc2.method.dcmodel)

    @testset "First Pass" begin
        compstruct(dc1.voltage, dc2.voltage; atol = 1e-10)
        compstruct(dc1.power, dc2.power; atol = 1e-10)
    end

    ######### Second Pass ##########
    updateBus!(system1; label = 3, active = 0.25, susceptance = 0.21)
    updateBus!(system1; label = 4, conductance = 0.21)

    updateBranch!(system1; label = 4, shiftAngle = -1.2)

    updateGenerator!(system1; label = 8, active = 1.2)
    updateGenerator!(system1; label = 1, status = 1)

    dc1 = dcPowerFlow(system1)
    powerFlow!(system1, dc1; power = true)

    # Reuse DC Power Flow Model
    updateBus!(system2, dc2; label = 3, active = 0.25, susceptance = 0.21)
    updateBus!(system2, dc2; label = 4, conductance = 0.21)

    updateBranch!(system2, dc2; label = 4, shiftAngle = -1.2)

    updateGenerator!(system2, dc2; label = 8, active = 1.2)
    updateGenerator!(system2, dc2; label = 1, status = 1)

    powerFlow!(system2, dc2; power = true)

    @testset "Second Pass" begin
        compstruct(dc1.voltage, dc2.voltage; atol = 1e-10)
        compstruct(dc1.power, dc2.power; atol = 1e-10)

        @test relsystem2 == system2.model.dc.model
        @test reldc2 == dc2.method.dcmodel
    end

    ######### Third Pass ##########
    addBranch!(system1; from = 16, to = 7, reactance = 0.03)

    updateBranch!(system1; label = 14, reactance = 0.03, status = 1)
    updateBranch!(system1; label = 10, reactance = 0.03, status = 0)
    updateBranch!(system1; label = 3, status = 1)

    addGenerator!(system1; bus = 2, active = 0.8)

    updateGenerator!(system1; label = 9, status = 0)
    updateGenerator!(system1; label = 1, status = 1)
    updateGenerator!(system1; label = 3, status = 1)

    dc1 = dcPowerFlow(system1)
    powerFlow!(system1, dc1; power = true)

    # Reuse DC Power Flow Model
    addBranch!(system2, dc2; from = 16, to = 7, reactance = 0.03)

    updateBranch!(system2, dc2; label = 14, reactance = 0.03, status = 1)
    updateBranch!(system2, dc2; label = 10, reactance = 0.03, status = 0)
    updateBranch!(system2, dc2; label = 3, status = 1)

    addGenerator!(system2, dc2; bus = 2, active = 0.8)

    updateGenerator!(system2, dc2; label = 9, status = 0)
    updateGenerator!(system2, dc2; label = 1, status = 1)
    updateGenerator!(system2, dc2; label = 3, status = 1)

    powerFlow!(system2, dc2; power = true)

    @testset "Third Pass" begin
        compstruct(dc1.voltage, dc2.voltage; atol = 1e-10)
        compstruct(dc1.power, dc2.power; atol = 1e-10)

        @test relsystem2 != system2.model.dc.model
        @test reldc2 != dc2.method.dcmodel

        dropZeros!(system2.model.dc)
        solve!(system2, dc2)
        @test dc1.voltage.angle ≈ dc2.voltage.angle
    end
end