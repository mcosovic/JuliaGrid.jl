@testset "Reusing Newton-Raphson Method" begin
    @default(unit)
    @default(template)
    @label(integer)

    ########## First Pass ##########
    system = powerSystem(path * "case14test.m")

    updateBus!(
        system; label = 14, active = 0.12, reactive = 0.13, conductance = 0.1,
        susceptance = 0.15, magnitude = 1.2, angle = -0.17
    )
    updateBus!(system; label = 7, active = 0.15)

    addBranch!(
        system; from = 2, to = 3, resistance = 0.02, reactance = 0.03,
        susceptance = 0.01, conductance = 0.0001, turnsRatio = 0.95, shiftAngle = -0.17
    )
    updateBranch!(
        system; label = 12, status = 0, resistance = 0.02, reactance = 0.03,
        susceptance = 0.001
    )
    updateBranch!(system; label = 12, status = 1)

    addGenerator!(system;  bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(system; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)
    updateGenerator!(system; label = 4, status = 0)
    updateGenerator!(system; label = 7, active = 0.15, magnitude = 0.92)

    acModel!(system)
    analysis = newtonRaphson(system)
    for iteration = 1:100
        stopping = mismatch!(system, analysis)
        if all(stopping .< 1e-12)
            break
        end
        solve!(system, analysis)
    end
    power!(system, analysis)
    current!(system, analysis)

    # Reuse Newton-Raphson Model
    resystem = powerSystem(path * "case14test.m")
    acModel!(resystem)
    reusing = newtonRaphson(resystem)

    updateBus!(
        resystem, reusing; label = 14, active = 0.12, reactive = 0.13, conductance = 0.1,
        susceptance = 0.15, magnitude = 1.2, angle = -0.17
    )
    updateBus!(resystem, reusing; label = 7, active = 0.15)

    addBranch!(
        resystem, reusing; from = 2, to = 3, resistance = 0.02, reactance = 0.03,
        susceptance = 0.01, conductance = 0.0001, turnsRatio = 0.95, shiftAngle = -0.17
    )
    updateBranch!(
        resystem, reusing;
        label = 12, status = 0, resistance = 0.02, reactance = 0.03, susceptance = 0.001
    )
    updateBranch!(resystem, reusing; label = 12, status = 1)

    addGenerator!(resystem, reusing; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(resystem, reusing; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)
    updateGenerator!(resystem, reusing; label = 4, status = 0)
    updateGenerator!(resystem, reusing; label = 7, active = 0.15, magnitude = 0.92)

    for iteration = 1:100
        stopping = mismatch!(resystem, reusing)
        if all(stopping .< 1e-12)
            break
        end
        solve!(resystem, reusing)
    end
    power!(resystem, reusing)
    current!(resystem, reusing)

    @testset "First Pass" begin
        compstruct(analysis.voltage, reusing.voltage; atol = 1e-10)
        compstruct(analysis.power, reusing.power; atol = 1e-10)
        compstruct(analysis.current, reusing.current; atol = 1e-8)
    end

    ########## Second Pass ##########
    updateBus!(
        system;
        label = 10, active = 0.12, susceptance = 0.005, magnitude = 1.02, angle = -0.21
    )

    addBranch!(
        system;
        from = 16, to = 7, resistance = 0.001, reactance = 0.03, susceptance = 0.001
    )
    updateBranch!(
        system;
        label = 14, status = 1, resistance = 0.02, reactance = 0.03, susceptance = 0.01
    )

    addGenerator!(system; bus = 2, active = 0.2, magnitude = 0.92)
    addGenerator!(system; bus = 16, active = 0.3, reactive = 0.2)
    updateGenerator!(system; label = 4, status = 0)
    updateGenerator!(system; label = 7, reactive = 0.13, magnitude = 0.91)

    acModel!(system)
    analysis = newtonRaphson(system)
    for iteration = 1:100
        stopping = mismatch!(system, analysis)
        if all(stopping .< 1e-12)
            break
        end
        solve!(system, analysis)
    end
    power!(system, analysis)
    current!(system, analysis)

    # Reuse Newton-Raphson Model
    updateBus!(
        resystem, reusing;
        label = 10, active = 0.12, susceptance = 0.005, magnitude = 1.02, angle = -0.21
    )

    addBranch!(
        resystem, reusing;
        from = 16, to = 7, resistance = 0.001, reactance = 0.03, susceptance = 0.001
    )
    updateBranch!(
        resystem, reusing;
        label = 14, status = 1, resistance = 0.02, reactance = 0.03, susceptance = 0.01
    )

    addGenerator!(resystem, reusing; bus = 2, active = 0.2, magnitude = 0.92)
    addGenerator!(resystem, reusing; bus = 16, active = 0.3, reactive = 0.2)
    updateGenerator!(resystem, reusing; label = 4, status = 0)
    updateGenerator!(resystem, reusing; label = 7, reactive = 0.13, magnitude = 0.91)

    for iteration = 1:100
        stopping = mismatch!(resystem, reusing)
        if all(stopping .< 1e-12)
            break
        end
        solve!(resystem, reusing)
    end
    power!(resystem, reusing)
    current!(resystem, reusing)

    @testset "Second Pass" begin
        compstruct(analysis.voltage, reusing.voltage; atol = 1e-10)
        compstruct(analysis.power, reusing.power; atol = 1e-10)
        compstruct(analysis.current, reusing.current; atol = 1e-8)
    end
end

@testset "Reusing Gauss-Seidel Method" begin
    @default(template)

    ########## First Pass ##########
    system = powerSystem(path * "case14test.m")

    updateBus!(
        system; label = 14, active = 0.12, reactive = 0.13, conductance = 0.1,
        susceptance = 0.15, magnitude = 1.2, angle = -0.17
    )
    updateBus!(system; label = 7, active = 0.15)

    addBranch!(
        system; from = 2, to = 3, resistance = 0.02, reactance = 0.03, susceptance = 0.01,
        conductance = 0.0001, turnsRatio = 0.95, shiftAngle = -0.17
    )
    updateBranch!(
        system;
        label = 12, status = 0, resistance = 0.02, reactance = 0.03, susceptance = 0.01
    )
    updateBranch!(system; label = 12, status = 1)

    addGenerator!(system; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(system; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)
    updateGenerator!(system; label = 4, status = 0)
    updateGenerator!(system; label = 7, active = 0.15, magnitude = 0.92)

    acModel!(system)
    analysis = gaussSeidel(system)
    for iteration = 1:1000
        stopping = mismatch!(system, analysis)
        if all(stopping .< 1e-12)
            break
        end
        solve!(system, analysis)
    end
    power!(system, analysis)
    current!(system, analysis)

    # Reuse Gauss-Seidel Model
    resystem = powerSystem(path * "case14test.m")
    acModel!(resystem)
    reusing = gaussSeidel(resystem)

    updateBus!(
        resystem, reusing; label = 14, active = 0.12, reactive = 0.13, conductance = 0.1,
        susceptance = 0.15, magnitude = 1.2, angle = -0.17
    )
    updateBus!(resystem, reusing; label = 7, active = 0.15)

    addBranch!(
        resystem, reusing; from = 2, to = 3, resistance = 0.02, reactance = 0.03,
        susceptance = 0.01, conductance = 0.0001, turnsRatio = 0.95, shiftAngle = -0.17
    )
    updateBranch!(
        resystem, reusing;
        label = 12, status = 0, resistance = 0.02, reactance = 0.03, susceptance = 0.01
    )
    updateBranch!(resystem, reusing; label = 12, status = 1)

    addGenerator!(resystem, reusing; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(resystem, reusing; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)
    updateGenerator!(resystem, reusing; label = 4, status = 0)
    updateGenerator!(resystem, reusing; label = 7, active = 0.15, magnitude = 0.92)

    for iteration = 1:1000
        stopping = mismatch!(resystem, reusing)
        if all(stopping .< 1e-12)
            break
        end
        solve!(resystem, reusing)
    end
    power!(resystem, reusing)
    current!(resystem, reusing)

    @testset "First Pass" begin
        compstruct(analysis.voltage, reusing.voltage; atol = 1e-10)
        compstruct(analysis.power, reusing.power; atol = 1e-10)
        compstruct(analysis.current, reusing.current; atol = 1e-8)
    end

    ########## Second Pass ##########
    updateBus!(
        system;
        label = 10, active = 0.12, susceptance = 0.005, magnitude = 1.02, angle = -0.21
    )

    addBranch!(
        system;
        from = 16, to = 7, resistance = 0.001, reactance = 0.03, susceptance = 0.001
    )
    updateBranch!(
        system;
        label = 14, status = 1, resistance = 0.02, reactance = 0.03, susceptance = 0.01
    )

    addGenerator!(system; bus = 2, active = 0.2, magnitude = 0.92)
    addGenerator!(system; bus = 16, active = 0.3, reactive = 0.2)
    updateGenerator!(system; label = 4, status = 0)
    updateGenerator!(system; label = 7, reactive = 0.13, magnitude = 0.91)

    acModel!(system)
    analysis = gaussSeidel(system)
    for iteration = 1:1000
        stopping = mismatch!(system, analysis)
        if all(stopping .< 1e-12)
            break
        end
        solve!(system, analysis)
    end
    power!(system, analysis)
    current!(system, analysis)

    # Reuse Gauss-Seidel Model
    updateBus!(
        resystem, reusing;
        label = 10, active = 0.12, susceptance = 0.005, magnitude = 1.02, angle = -0.21
    )

    addBranch!(
        resystem, reusing;
        from = 16, to = 7, resistance = 0.001, reactance = 0.03, susceptance = 0.001
    )
    updateBranch!(
        resystem, reusing;
        label = 14, status = 1, resistance = 0.02, reactance = 0.03, susceptance = 0.01
    )

    addGenerator!(resystem, reusing; bus = 2, active = 0.2, magnitude = 0.92)
    addGenerator!(resystem, reusing; bus = 16, active = 0.3, reactive = 0.2)
    updateGenerator!(resystem, reusing; label = 4, status = 0)
    updateGenerator!(resystem, reusing; label = 7, reactive = 0.13, magnitude = 0.91)

    setInitialPoint!(resystem, reusing)
    for iteration = 1:1000
        stopping = mismatch!(resystem, reusing)
        if all(stopping .< 1e-12)
            break
        end
        solve!(resystem, reusing)
    end
    power!(resystem, reusing)
    current!(resystem, reusing)

    @testset "Second Pass" begin
        compstruct(analysis.voltage, reusing.voltage; atol = 1e-10)
        compstruct(analysis.power, reusing.power; atol = 1e-10)
        compstruct(analysis.current, reusing.current; atol = 1e-8)
    end
end

@testset "Reusing Fast Newton-Raphson Method" begin
    ########## First Pass ##########
    system = powerSystem(path * "case14test.m")

    updateBus!(
        system; label = 14, active = 0.12, reactive = 0.13, magnitude = 1.2, angle = -0.17
    )
    updateBus!(
        system;
        label = 10, active = 0.12, susceptance = 0.005, magnitude = 1.02, angle = -0.21
    )
    updateBus!(system; label = 7, active = 0.15)

    addBranch!(
        system; from = 16, to = 7, resistance = 0.001, reactance = 0.03, susceptance = 0.001
    )
    updateBranch!(
        system; label = 14, status = 1, resistance = 0.02, reactance = 0.03, susceptance = 0.01
    )
    updateBranch!(system; label = 13, status = 0)

    addGenerator!(system; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(system; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)
    updateGenerator!(system; label = 4, status = 0)
    updateGenerator!(system; label = 7, active = 0.15, magnitude = 0.92)

    acModel!(system)
    analysis = fastNewtonRaphsonBX(system)
    for iteration = 1:1000
        stopping = mismatch!(system, analysis)
        if all(stopping .< 1e-12)
            break
        end
        solve!(system, analysis)
    end
    power!(system, analysis)
    current!(system, analysis)

    # Reuse Fast Newton-Raphson Model
    resystem = powerSystem(path * "case14test.m")
    acModel!(resystem)
    reusing = fastNewtonRaphsonBX(resystem)

    updateBus!(
        resystem, reusing;
        label = 14, active = 0.12, reactive = 0.13, magnitude = 1.2, angle = -0.17
    )
    updateBus!(
        resystem, reusing;
        label = 10, active = 0.12, susceptance = 0.005, magnitude = 1.02, angle = -0.21
    )
    updateBus!(resystem, reusing; label = 7, active = 0.15)

    addBranch!(
        resystem, reusing;
        from = 16, to = 7, resistance = 0.001, reactance = 0.03, susceptance = 0.001
    )
    updateBranch!(
        resystem, reusing;
        label = 14, status = 1, resistance = 0.02, reactance = 0.03, susceptance = 0.01
    )
    updateBranch!(resystem, reusing; label = 13, status = 0)

    addGenerator!(resystem, reusing; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(resystem, reusing; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)
    updateGenerator!(resystem, reusing; label = 4, status = 0)
    updateGenerator!(resystem, reusing; label = 7, active = 0.15, magnitude = 0.92)

    for iteration = 1:1000
        stopping = mismatch!(resystem, reusing)
        if all(stopping .< 1e-12)
            break
        end
        solve!(resystem, reusing)
    end
    power!(resystem, reusing)
    current!(resystem, reusing)

    @testset "First Pass" begin
        compstruct(analysis.voltage, reusing.voltage; atol = 1e-10)
        compstruct(analysis.power, reusing.power; atol = 1e-10)
        compstruct(analysis.current, reusing.current; atol = 1e-8)
    end

    ########## Second Pass ##########
    updateBus!(system; label = 10, active = 0.12, magnitude = 1.02, angle = -0.21)
    addGenerator!(system; bus = 2, active = 0.2, magnitude = 0.92)
    addGenerator!(system; bus = 16, active = 0.3, reactive = 0.2)
    updateGenerator!(system; label = 4, status = 0)
    updateGenerator!(system; label = 7, reactive = 0.13, magnitude = 0.91)

    acModel!(system)
    analysis = fastNewtonRaphsonBX(system)
    for iteration = 1:1000
        stopping = mismatch!(system, analysis)
        if all(stopping .< 1e-12)
            break
        end
        solve!(system, analysis)
    end
    power!(system, analysis)
    current!(system, analysis)

    # Reuse Fast Newton-Raphson Model
    updateBus!(resystem, reusing; label = 10, active = 0.12, magnitude = 1.02, angle = -0.21)
    addGenerator!(resystem, reusing; bus = 2, active = 0.2, magnitude = 0.92)
    addGenerator!(resystem, reusing; bus = 16, active = 0.3, reactive = 0.2)
    updateGenerator!(resystem, reusing; label = 4, status = 0)
    updateGenerator!(resystem, reusing; label = 7, reactive = 0.13, magnitude = 0.91)

    for iteration = 1:1000
        stopping = mismatch!(resystem, reusing)
        if all(stopping .< 1e-12)
            break
        end
        solve!(resystem, reusing)
    end
    power!(resystem, reusing)
    current!(resystem, reusing)

    @testset "Second Pass" begin
        compstruct(analysis.voltage, reusing.voltage; atol = 1e-10)
        compstruct(analysis.power, reusing.power; atol = 1e-10)
        compstruct(analysis.current, reusing.current; atol = 1e-8)
    end
end

@testset "Reusing DC Power Flow" begin
    @default(unit)
    @default(template)

    ########## First Pass ##########
    system = powerSystem(path * "case14test.m")

    updateBus!(system; label = 1, active = 0.15, conductance = 0.16)
    addGenerator!(system; bus = 2, active = 0.8)
    updateGenerator!(system; label = 9, active = 1.2)
    updateGenerator!(system; label = 1, status = 0)
    updateGenerator!(system; label = 3, status = 0)

    dcModel!(system)
    analysis = dcPowerFlow(system)
    solve!(system, analysis)
    power!(system, analysis)

    # Reuse DC Power Flow Model
    resystem = powerSystem(path * "case14test.m")
    dcModel!(resystem)
    reusing = dcPowerFlow(resystem)

    updateBus!(resystem, reusing; label = 1, active = 0.15, conductance = 0.16)
    addGenerator!(resystem, reusing; bus = 2, active = 0.8)
    updateGenerator!(resystem, reusing; label = 9, active = 1.2)
    updateGenerator!(resystem, reusing; label = 1, status = 0)
    updateGenerator!(resystem, reusing; label = 1, status = 1)
    updateGenerator!(resystem, reusing; label = 1, status = 0)
    updateGenerator!(resystem; label = 3, status = 0)

    solve!(resystem, reusing)
    power!(resystem, reusing)
    releaseSystem = copy(resystem.model.dc.model)
    releaseReusing = copy(reusing.method.dcmodel)

    @testset "First Pass" begin
        compstruct(analysis.voltage, reusing.voltage; atol = 1e-10)
        compstruct(analysis.power, reusing.power; atol = 1e-10)
    end

    ########## Second Pass ##########
    updateBus!(system; label = 3, active = 0.25, susceptance = 0.21)
    updateBus!(system; label = 4, conductance = 0.21)
    updateBranch!(system; label = 4, shiftAngle = -1.2)
    updateGenerator!(system; label = 8, active = 1.2)

    dcModel!(system)
    analysis = dcPowerFlow(system)
    solve!(system, analysis)
    power!(system, analysis)

    # Reuse DC Power Flow Model
    updateBus!(resystem, reusing; label = 3, active = 0.25, susceptance = 0.21)
    updateBus!(resystem, reusing; label = 4, conductance = 0.21)
    updateBranch!(resystem, reusing; label = 4, shiftAngle = -1.2)
    updateGenerator!(resystem, reusing; label = 8, active = 1.2)

    solve!(resystem, reusing)
    power!(resystem, reusing)

    @testset "Second Pass" begin
        compstruct(analysis.voltage, reusing.voltage; atol = 1e-10)
        compstruct(analysis.power, reusing.power; atol = 1e-10)

        @test releaseSystem == resystem.model.dc.model
        @test releaseReusing == reusing.method.dcmodel
    end

    ########## Third Pass ##########
    updateBus!(system; label = 2, active = 0.15, susceptance = 0.16, type = 2)
    addBranch!(system; from = 16, to = 7, reactance = 0.03)
    updateBranch!(system; label = 14, status = 1, reactance = 0.03)
    updateBranch!(system; label = 10, status = 0, reactance = 0.03)
    updateBranch!(system; label = 3, status = 1)
    addGenerator!(system; bus = 2, active = 0.8)
    updateGenerator!(system; label = 9, status = 0)
    updateGenerator!(system; label = 1, status = 1)
    updateGenerator!(system; label = 3, status = 1)

    dcModel!(system)
    analysis = dcPowerFlow(system)
    solve!(system, analysis)
    power!(system, analysis)

    # Reuse DC Power Flow Model
    updateBus!(resystem, reusing; label = 2, active = 0.15, susceptance = 0.16, type = 2)
    addBranch!(resystem, reusing; from = 16, to = 7, reactance = 0.03)
    updateBranch!(resystem, reusing; label = 14, status = 1, reactance = 0.03)
    updateBranch!(resystem, reusing; label = 10, status = 0, reactance = 0.03)
    updateBranch!(resystem, reusing; label = 3, status = 1)
    addGenerator!(resystem, reusing; bus = 2, active = 0.8)
    updateGenerator!(resystem, reusing; label = 9, status = 0)
    updateGenerator!(resystem, reusing; label = 1, status = 1)
    updateGenerator!(resystem, reusing; label = 3, status = 1)

    solve!(resystem, reusing)
    power!(resystem, reusing)

    @testset "Third Pass" begin
        compstruct(analysis.voltage, reusing.voltage; atol = 1e-10)
        compstruct(analysis.power, reusing.power; atol = 1e-10)

        @test releaseSystem != resystem.model.dc.model
        @test releaseReusing != reusing.method.dcmodel

        dropZeros!(resystem.model.dc)
        solve!(resystem, reusing)
        @test analysis.voltage.angle ≈ reusing.voltage.angle
    end
end