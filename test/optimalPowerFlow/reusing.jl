@testset "Reusing AC Optimal Power Flow" begin
    @default(unit)
    @default(template)
    @label(Integer)

    ########## First Pass ##########
    system = powerSystem(path * "case14optimal.m")

    updateBus!(
        system;
        label = 1, type = 1, active = 0.15, reactive = 0.2, conductance = 0.16, angle = -0.1
    )
    updateBus!(
        system; label = 2, type = 3, angle = -0.01, magnitude = 0.99, minMagnitude = 0.98
    )

    addBranch!(
        system; label = 21, from = 5, to = 7, reactance = 0.25,
        turnsRatio = 0.98, shiftAngle = -0.1, status = 0
    )
    addBranch!(
        system; label = 22, from = 4, to = 5, reactance = 0.25, minFromBus = -0.18,
        maxFromBus = 0.18, minToBus = -0.18, maxToBus = 0.18, maxDiffAngle = 0.15, type = 2
    )
    updateBranch!(system; label = 21, status = 1)
    updateBranch!(system; label = 5, status = 0)
    updateBranch!(system; label = 21, reactance = 0.35, maxDiffAngle = 0.22)

    addGenerator!(
        system; label = 9, bus = 3, active = 0.3, minActive = 0.0,
        maxActive = 0.5, maxReactive = Inf, status = 0
    )
    addGenerator!(
        system; label = 10, bus = 3, active = 0.3, maxActive = 1.0, maxReactive = Inf
    )
    updateGenerator!(system; label = 9, status = 1, maxActive = 0.8, maxReactive = 0.8)
    updateGenerator!(system; label = 10, status = 0, maxActive = 0.8)
    updateGenerator!(system; label = 9, status = 0)

    cost!(system; generator = 10, active = 2, polynomial = [452.2; 31; 18; 5])
    cost!(system; generator = 9, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system; generator = 5, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system; generator = 5, active = 2, polynomial = [452.2; 31; 18; 5])
    cost!(system; generator = 5, active = 2, polynomial = [452.2; 31; 18])
    cost!(system; generator = 5, active = 2, polynomial = [452.2; 31; 18; 6])
    cost!(system; generator = 4, reactive = 2, polynomial = [452.2; 31; 18; 5])
    cost!(system; generator = 4, reactive = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])

    acModel!(system)
    analysis = acOptimalPowerFlow(system, Ipopt.Optimizer; print = false)

    solve!(system, analysis)
    power!(system, analysis)

    # Reuse AC Optimal Power Flow Model
    resystem = powerSystem(path * "case14optimal.m")
    acModel!(resystem)
    reusing = acOptimalPowerFlow(resystem, Ipopt.Optimizer; print = false)

    updateBus!(
        resystem, reusing;
        label = 1, type = 1, active = 0.15, reactive = 0.2, conductance = 0.16, angle = -0.1
    )
    updateBus!(
        resystem, reusing;
        label = 2, type = 3, angle = -0.01, magnitude = 0.99, minMagnitude = 0.98
    )

    addBranch!(
        resystem, reusing; label = 21, from = 5, to = 7, reactance = 0.25,
        turnsRatio = 0.98, shiftAngle = -0.1, status = 0
    )
    addBranch!(
        resystem, reusing; label = 22, from = 4, to = 5, reactance = 0.25,
        minFromBus = -0.18, maxFromBus = 0.18, minToBus = -0.18, maxToBus = 0.18,
        maxDiffAngle = 0.15, type = 2
    )
    updateBranch!(resystem, reusing; label = 21, status = 1)
    updateBranch!(resystem, reusing; label = 5, status = 0)
    updateBranch!(resystem, reusing; label = 21, reactance = 0.35, maxDiffAngle = 0.22)

    addGenerator!(
        resystem, reusing; label = 9, bus = 3, active = 0.3, minActive = 0.0,
        maxActive = 0.5, maxReactive = Inf, status = 0
    )
    cost!(
        resystem, reusing;
        generator = 9, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6]
    )
    addGenerator!(
        resystem, reusing;
        label = 10, bus = 3, active = 0.3, maxActive = 1.0, maxReactive = Inf
    )
    updateGenerator!(
        resystem, reusing; label = 9, status = 1, maxActive = 0.8, maxReactive = 0.8
    )
    updateGenerator!(resystem, reusing; label = 10, status = 0, maxActive = 0.8)
    updateGenerator!(resystem, reusing; label = 9, status = 0)

    cost!(
        resystem, reusing;
        generator = 5, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6]
    )
    cost!(resystem, reusing; generator = 10, active = 2, polynomial = [452.2; 31; 18; 5])
    cost!(resystem, reusing; generator = 5, active = 2, polynomial = [452.2; 31; 18; 5])
    cost!(resystem, reusing; generator = 5, active = 2, polynomial = [452.2; 31; 18])
    cost!(resystem, reusing; generator = 5, active = 2, polynomial = [452.2; 31; 18])
    cost!(resystem, reusing; generator = 5, active = 2, polynomial = [452.2; 31; 18; 6])
    cost!(resystem, reusing; generator = 4, reactive = 2, polynomial = [452.2; 31; 18; 5])
    cost!(
        resystem,
        reusing; generator = 4, reactive = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6]
    )

    solve!(resystem, reusing)
    power!(resystem, reusing)

    @testset "First Pass" begin
        compstruct(analysis.voltage, reusing.voltage; atol = 1e-10)
        compstruct(analysis.power, reusing.power; atol = 1e-10)
        @test objective_value(analysis.method.jump) ≈ objective_value(reusing.method.jump)

        for list in list_of_constraint_types(analysis.method.jump)
            @test num_constraints(analysis.method.jump, list[1], list[2]) ==
                num_constraints(reusing.method.jump, list[1], list[2])
        end
    end

    ########## Second Pass ##########
    updateBus!(
        system; label = 1, type = 1, conductance = 0.06, susceptance = 0.8, angle = -0.01
    )

    updateBranch!(
        system; label = 22, reactance = 0.35, minFromBus = -0.22, maxFromBus = 0.22,
        minToBus = -0.22, maxToBus = 0.22
    )
    updateBranch!(system; label = 21, status = 0)

    addGenerator!(
        system;
        label = 11, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5, status = 1
    )
    addGenerator!(
        system; label = 12, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5
    )

    cost!(system; generator = 11, active = 2, polynomial = [165.0])
    cost!(system; generator = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system; generator = 9, active = 2, polynomial = [856.2; 135.3; 80])

    acModel!(system)
    analysis = acOptimalPowerFlow(system, Ipopt.Optimizer; print = false)

    solve!(system, analysis)
    power!(system, analysis)

    # Reuse AC Optimal Power Flow Model
    updateBus!(
        resystem, reusing;
        label = 1, type = 1, conductance = 0.06, susceptance = 0.8, angle = -0.01
    )

    updateBranch!(
        resystem, reusing; label = 22, reactance = 0.35, minFromBus = -0.22,
        maxFromBus = 0.22, minToBus = -0.22, maxToBus = 0.22
    )
    updateBranch!(resystem, reusing; label = 21, status = 0)

    addGenerator!(
        resystem, reusing;
        label = 11, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5, status = 1
    )
    addGenerator!(
        resystem, reusing;
        label = 12, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5
    )

    cost!(
        resystem, reusing;
        generator = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6]
    )
    cost!(resystem, reusing; generator = 11, active = 2, polynomial = [165.0])
    cost!(resystem, reusing; generator = 9, active = 2, polynomial = [856.2; 135.3; 80])

    setInitialPoint!(resystem, reusing)
    solve!(resystem, reusing)
    power!(resystem, reusing)

    @testset "Second Pass" begin
        compstruct(analysis.voltage, reusing.voltage; atol = 1e-10)
        compstruct(analysis.power, reusing.power; atol = 1e-10)
        @test objective_value(analysis.method.jump) ≈ objective_value(reusing.method.jump)

        for list in list_of_constraint_types(analysis.method.jump)
            @test num_constraints(analysis.method.jump, list[1], list[2]) ==
                num_constraints(reusing.method.jump, list[1], list[2])
        end
    end
end

@testset "Reusing DC Optimal Power Flow" begin
    @default(unit)
    @default(template)

    ########## First Pass ##########
    system = powerSystem(path * "case14test.m")

    updateBus!(
        system; label = 1, type = 1, active = 0.15, conductance = 0.16, angle = -0.1
    )
    updateBus!(system; label = 2, type = 3, angle = -0.01)

    addBranch!(
        system; label = 21, from = 5, to = 7, reactance = 0.25,
        turnsRatio = 0.98, shiftAngle = -0.1, status = 0
    )
    addBranch!(
        system; label = 22, from = 4, to = 5, reactance = 0.25, minFromBus = -0.18,
        maxFromBus = 0.18, minToBus = -0.18, maxToBus = 0.18, maxDiffAngle = 0.15
    )
    updateBranch!(system; label = 21, status = 1)
    updateBranch!(system; label = 22, status = 0)
    updateBranch!(system; label = 21, reactance = 0.35, maxDiffAngle = 0.22)

    addGenerator!(
        system;
        label = 9, bus = 3, active = 0.3, minActive = 0.0, maxActive = 0.5, status = 0
    )
    cost!(system; generator = 9, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    addGenerator!(system; label = 10, bus = 3, active = 0.3)
    cost!(system; generator = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1])
    updateGenerator!(system; label = 9, status = 1, maxActive = 0.8)
    updateGenerator!(system; label = 10, status = 0, maxActive = 0.8)
    updateGenerator!(system; label = 9, status = 0)
    cost!(system; generator = 5, active = 2, polynomial = [854.0, 116.0])

    dcModel!(system)
    analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer; print = false)
    solve!(system, analysis)
    power!(system, analysis)

    # Reuse DC Optimal Power Flow Model
    resystem = powerSystem(path * "case14test.m")
    dcModel!(resystem)
    reusing = dcOptimalPowerFlow(resystem, Ipopt.Optimizer; print = false)

    updateBus!(
        resystem, reusing;
        label = 1, type = 1, active = 0.15, conductance = 0.16, angle = -0.1
    )
    updateBus!(resystem, reusing; label = 2, type = 3, angle = -0.01)

    addBranch!(
        resystem, reusing; label = 21, from = 5, to = 7, reactance = 0.25,
        turnsRatio = 0.98, shiftAngle = -0.1, status = 0
    )
    addBranch!(
        resystem, reusing;
        label = 22, from = 4, to = 5, reactance = 0.25, minFromBus = -0.18,
        maxFromBus = 0.18, minToBus = -0.18, maxToBus = 0.18, maxDiffAngle = 0.15
    )
    updateBranch!(resystem, reusing; label = 21, status = 1)
    updateBranch!(resystem, reusing; label = 22, status = 0)
    updateBranch!(resystem, reusing; label = 21, reactance = 0.35, maxDiffAngle = 0.22)

    addGenerator!(
        resystem, reusing;
        label = 9, bus = 3, active = 0.3, minActive = 0.0, maxActive = 0.5, status = 0
    )
    cost!(
        resystem, reusing;
        generator = 9, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6]
    )
    addGenerator!(resystem, reusing; label = 10, bus = 3, active = 0.3)
    cost!(resystem, reusing; generator = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1])
    updateGenerator!(resystem, reusing; label = 9, status = 1, maxActive = 0.8)
    updateGenerator!(resystem, reusing; label = 10, status = 0, maxActive = 0.8)
    updateGenerator!(resystem, reusing; label = 9, status = 0)
    cost!(resystem, reusing; generator = 5, active = 2, polynomial = [854.0, 116.0])

    solve!(resystem, reusing)
    power!(resystem, reusing)

    @testset "First Pass" begin
        compstruct(analysis.voltage, reusing.voltage; atol = 1e-10)
        compstruct(analysis.power, reusing.power; atol = 1e-10)
        @test objective_value(analysis.method.jump) ≈ objective_value(reusing.method.jump)

        for list in list_of_constraint_types(analysis.method.jump)
            @test num_constraints(analysis.method.jump, list[1], list[2]) ==
                num_constraints(reusing.method.jump, list[1], list[2])
        end
    end

    ########## Second Pass ##########
    updateBus!(system; label = 1, type = 1, conductance = 0.06, angle = -0.01)

    updateBranch!(
        system; label = 22, reactance = 0.35, minFromBus = -0.22, maxFromBus = 0.22,
        minToBus = -0.22, maxToBus = 0.22
    )
    updateBranch!(system; label = 21, status = 0)

    addGenerator!(
        system;
        label = 11, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5, status = 0
    )
    cost!(system; generator = 11, active = 2, polynomial = [165.0])
    cost!(system; generator = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system; generator = 9, active = 2, polynomial = [856.2; 135.3; 80])

    dcModel!(system)
    analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer; print = false)
    solve!(system, analysis)
    power!(system, analysis)

    # Reuse DC Optimal Power Flow Model
    updateBus!(resystem, reusing; label = 1, type = 1, conductance = 0.06, angle = -0.01)

    updateBranch!(
        resystem, reusing;
        label = 22, reactance = 0.35, minFromBus = -0.22, maxFromBus = 0.22,
        minToBus = -0.22, maxToBus = 0.22
    )
    updateBranch!(resystem, reusing; label = 21, status = 0)

    addGenerator!(
        resystem, reusing;
        label = 11, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5, status = 0
    )
    cost!(resystem, reusing; generator = 11, active = 2, polynomial = [165.0])
    cost!(resystem, reusing; generator = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(resystem, reusing; generator = 9, active = 2, polynomial = [856.2; 135.3; 80])

    setInitialPoint!(resystem, reusing)
    solve!(resystem, reusing)
    power!(resystem, reusing)

    @testset "Second Pass" begin
        compstruct(analysis.voltage, reusing.voltage; atol = 1e-10)
        compstruct(analysis.power, reusing.power; atol = 1e-10)
        @test objective_value(analysis.method.jump) ≈ objective_value(reusing.method.jump)

        for list in list_of_constraint_types(analysis.method.jump)
            @test num_constraints(analysis.method.jump, list[1], list[2]) ==
                num_constraints(reusing.method.jump, list[1], list[2])
        end
    end
end