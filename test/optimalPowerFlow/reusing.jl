@testset "Reusing AC Optimal Power Flow" begin
    @default(unit)
    @default(template)
    @config(label = Integer)

    ########## First Pass ##########
    system1 = powerSystem(path * "case14optimal.m")

    updateBus!(system1; label = 1, type = 1, active = 0.15, reactive = 0.2, conductance = 0.16)
    updateBus!(system1; label = 1, angle = -0.1)
    updateBus!(system1; label = 2, type = 3, angle = -0.01, magnitude = 0.99, minMagnitude = 0.98)

    addBranch!(system1; label = 21, from = 5, to = 7, reactance = 0.25, turnsRatio = 0.98)
    addBranch!(system1; label = 22, from = 4, to = 5, reactance = 0.25, type = 2)

    updateBranch!(system1; label = 21, shiftAngle = -0.1, status = 0)
    updateBranch!(system1; label = 21, status = 1, reactance = 0.35, maxDiffAngle = 0.22)
    updateBranch!(system1; label = 22, minToBus = -0.18, maxToBus = 0.18, maxDiffAngle = 0.15)
    updateBranch!(system1; label = 22, minToBus = -0.18, maxToBus = 0.18, maxDiffAngle = 0.15)
    updateBranch!(system1; label = 5, status = 0)

    addGenerator!(system1; label = 9, bus = 3, active = 0.3, minActive = 0.0, maxActive = 0.5)
    addGenerator!(system1; label = 10, bus = 3, active = 0.3, maxActive = 1.0, maxReactive = Inf)

    updateGenerator!(system1; label = 9, maxReactive = Inf, status = 0)
    updateGenerator!(system1; label = 9, status = 1, maxActive = 0.8, maxReactive = 0.8)
    updateGenerator!(system1; label = 10, status = 0, maxActive = 0.8)
    updateGenerator!(system1; label = 9, status = 0)

    cost!(system1; generator = 10, active = 2, polynomial = [452.2; 31; 18; 5])
    cost!(system1; generator = 9, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system1; generator = 5, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system1; generator = 5, active = 2, polynomial = [452.2; 31; 18; 5])
    cost!(system1; generator = 5, active = 2, polynomial = [452.2; 31; 18])
    cost!(system1; generator = 5, active = 2, polynomial = [452.2; 31; 18; 6])
    cost!(system1; generator = 4, reactive = 2, polynomial = [452.2; 31; 18; 5])
    cost!(system1; generator = 4, reactive = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])

    acModel!(system1)
    opf1 = acOptimalPowerFlow(system1, Ipopt.Optimizer)
    powerFlow!(system1, opf1; power = true)

    # Reuse AC Optimal Power Flow Model
    system2 = powerSystem(path * "case14optimal.m")
    acModel!(system2)
    opf2 = acOptimalPowerFlow(system2, Ipopt.Optimizer)

    updateBus!(system2, opf2; label = 1, type = 1, active = 0.15, reactive = 0.2, conductance = 0.16)
    updateBus!(system2, opf2; label = 1, angle = -0.1)
    updateBus!(system2, opf2; label = 2, type = 3, angle = -0.01, magnitude = 0.99, minMagnitude = 0.98)

    addBranch!(system2, opf2; label = 21, from = 5, to = 7, reactance = 0.25, turnsRatio = 0.98)
    addBranch!(system2, opf2; label = 22, from = 4, to = 5, reactance = 0.25, type = 2)

    updateBranch!(system2, opf2; label = 21, shiftAngle = -0.1, status = 0)
    updateBranch!(system2, opf2; label = 21, status = 1, reactance = 0.35, maxDiffAngle = 0.22)
    updateBranch!(system2, opf2; label = 22, minToBus = -0.18, maxToBus = 0.18, maxDiffAngle = 0.15)
    updateBranch!(system2, opf2; label = 22, minToBus = -0.18, maxToBus = 0.18, maxDiffAngle = 0.15)
    updateBranch!(system2, opf2; label = 5, status = 0)

    addGenerator!(system2, opf2; label = 9, bus = 3, active = 0.3, minActive = 0.0, maxActive = 0.5)
    addGenerator!(system2, opf2; label = 10, bus = 3, active = 0.3, maxActive = 1.0, maxReactive = Inf)

    updateGenerator!(system2, opf2; label = 9, maxReactive = Inf, status = 0)
    updateGenerator!(system2, opf2; label = 9, status = 1, maxActive = 0.8, maxReactive = 0.8)
    updateGenerator!(system2, opf2; label = 10, status = 0, maxActive = 0.8)
    updateGenerator!(system2, opf2; label = 9, status = 0)

    cost!(system2, opf2; generator = 5, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system2, opf2; generator = 10, active = 2, polynomial = [452.2; 31; 18; 5])
    cost!(system2, opf2; generator = 5, active = 2, polynomial = [452.2; 31; 18; 5])
    cost!(system2, opf2; generator = 5, active = 2, polynomial = [452.2; 31; 18])
    cost!(system2, opf2; generator = 5, active = 2, polynomial = [452.2; 31; 18])
    cost!(system2, opf2; generator = 5, active = 2, polynomial = [452.2; 31; 18; 6])
    cost!(system2, opf2; generator = 4, reactive = 2, polynomial = [452.2; 31; 18; 5])
    cost!(system2, opf2; generator = 4, reactive = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])

    powerFlow!(system2, opf2; power = true)

    @testset "First Pass" begin
        compstruct(opf1.voltage, opf2.voltage; atol = 1e-10)
        compstruct(opf1.power, opf2.power; atol = 1e-10)
        @test objective_value(opf1.method.jump) ≈ objective_value(opf2.method.jump)

        for list in list_of_constraint_types(opf1.method.jump)
            @test num_constraints(opf1.method.jump, list[1], list[2]) ==
                num_constraints(opf2.method.jump, list[1], list[2])
        end
    end

    ########## Second Pass ##########
    updateBus!(system1; label = 1, type = 1, conductance = 0.06, susceptance = 0.8, angle = -0.01)

    updateBranch!(system1; label = 22, reactance = 0.35, minFromBus = -0.22, maxFromBus = 0.22)
    updateBranch!(system1; label = 22, minToBus = -0.22, maxToBus = 0.22)
    updateBranch!(system1; label = 21, status = 0)

    addGenerator!(system1; label = 11, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5)
    addGenerator!(system1; label = 12, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5)

    cost!(system1; generator = 11, active = 2, polynomial = [165.0])
    cost!(system1; generator = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system1; generator = 9, active = 2, polynomial = [856.2; 135.3; 80])

    acModel!(system1)
    analysis = acOptimalPowerFlow(system1, Ipopt.Optimizer)
    opf1 = acOptimalPowerFlow(system1, Ipopt.Optimizer)
    powerFlow!(system1, opf1; power = true)

    # Reuse AC Optimal Power Flow Model
    updateBus!(system2, opf2; label = 1, type = 1, conductance = 0.06, susceptance = 0.8, angle = -0.01)

    updateBranch!(system2, opf2; label = 22, reactance = 0.35, minFromBus = -0.22, maxFromBus = 0.22)
    updateBranch!(system2, opf2; label = 22, minToBus = -0.22, maxToBus = 0.22)
    updateBranch!(system2, opf2; label = 21, status = 0)

    addGenerator!(system2, opf2; label = 11, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5)
    addGenerator!(system2, opf2; label = 12, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5)

    cost!(system2, opf2; generator = 11, active = 2, polynomial = [165.0])
    cost!(system2, opf2; generator = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system2, opf2; generator = 9, active = 2, polynomial = [856.2; 135.3; 80])

    setInitialPoint!(system2, opf2)
    powerFlow!(system2, opf2; power = true)

    @testset "Second Pass" begin
        compstruct(opf1.voltage, opf2.voltage; atol = 1e-10)
        compstruct(opf1.power, opf2.power; atol = 1e-10)
        @test objective_value(opf1.method.jump) ≈ objective_value(opf2.method.jump)

        for list in list_of_constraint_types(opf1.method.jump)
            @test num_constraints(opf1.method.jump, list[1], list[2]) ==
                num_constraints(opf2.method.jump, list[1], list[2])
        end
    end
end

@testset "Reusing DC Optimal Power Flow" begin
    @default(unit)
    @default(template)

    ########## First Pass ##########
    system1 = powerSystem(path * "case14test.m")

    updateBus!(system1; label = 1, type = 1, active = 0.15, angle = -0.1)
    updateBus!(system1; label = 1, type = 1, conductance = 0.16)
    updateBus!(system1; label = 2, type = 3, angle = -0.01)

    addBranch!(system1; label = 21, from = 5, to = 7, reactance = 0.25, turnsRatio = 0.98)
    addBranch!(system1; label = 22, from = 4, to = 5, reactance = 0.25, minFromBus = -0.18)

    updateBranch!(system1; label = 21, shiftAngle = -0.1, status = 0)
    updateBranch!(system1; label = 21, status = 1)
    updateBranch!(system1; label = 22, status = 0)
    updateBranch!(system1; label = 22, maxFromBus = 0.18, minToBus = -0.18)
    updateBranch!(system1; label = 22, maxToBus = 0.18, maxDiffAngle = 0.15)
    updateBranch!(system1; label = 21, reactance = 0.35, maxDiffAngle = 0.22)

    addGenerator!(system1; label = 9, bus = 3, active = 0.3, minActive = 0.0)
    addGenerator!(system1; label = 10, bus = 3, active = 0.3)

    updateGenerator!(system1; label = 9, maxActive = 0.5, status = 0)
    updateGenerator!(system1; label = 9, status = 1, maxActive = 0.8)
    updateGenerator!(system1; label = 10, status = 0, maxActive = 0.8)
    updateGenerator!(system1; label = 9, status = 0)

    cost!(system1; generator = 9, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system1; generator = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1])
    cost!(system1; generator = 5, active = 2, polynomial = [854.0, 116.0])

    dcModel!(system1)
    opf1 = dcOptimalPowerFlow(system1, Ipopt.Optimizer)
    powerFlow!(system1, opf1; power = true)

    # Reuse DC Optimal Power Flow Model
    system2 = powerSystem(path * "case14test.m")
    dcModel!(system2)
    opf2 = dcOptimalPowerFlow(system2, Ipopt.Optimizer)

    updateBus!(system2, opf2; label = 1, type = 1, active = 0.15, angle = -0.1)
    updateBus!(system2, opf2; label = 1, type = 1, conductance = 0.16)
    updateBus!(system2, opf2; label = 2, type = 3, angle = -0.01)

    addBranch!(system2, opf2; label = 21, from = 5, to = 7, reactance = 0.25, turnsRatio = 0.98)
    addBranch!(system2, opf2; label = 22, from = 4, to = 5, reactance = 0.25, minFromBus = -0.18)

    updateBranch!(system2, opf2; label = 21, shiftAngle = -0.1, status = 0)
    updateBranch!(system2, opf2; label = 21, status = 1)
    updateBranch!(system2, opf2; label = 22, status = 0)
    updateBranch!(system2, opf2; label = 22, maxFromBus = 0.18, minToBus = -0.18)
    updateBranch!(system2, opf2; label = 22, maxToBus = 0.18, maxDiffAngle = 0.15)
    updateBranch!(system2, opf2; label = 21, reactance = 0.35, maxDiffAngle = 0.22)

    addGenerator!(system2, opf2; label = 9, bus = 3, active = 0.3, minActive = 0.0)
    addGenerator!(system2, opf2; label = 10, bus = 3, active = 0.3)

    updateGenerator!(system2, opf2; label = 9, maxActive = 0.5, status = 0)
    updateGenerator!(system2, opf2; label = 9, status = 1, maxActive = 0.8)
    updateGenerator!(system2, opf2; label = 10, status = 0, maxActive = 0.8)
    updateGenerator!(system2, opf2; label = 9, status = 0)

    cost!(system2, opf2; generator = 9, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system2, opf2; generator = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1])
    cost!(system2, opf2; generator = 5, active = 2, polynomial = [854.0, 116.0])

    powerFlow!(system2, opf2; power = true)

    @testset "First Pass" begin
        compstruct(opf1.voltage, opf2.voltage; atol = 1e-10)
        compstruct(opf1.power, opf2.power; atol = 1e-10)
        @test objective_value(opf1.method.jump) ≈ objective_value(opf2.method.jump)

        for list in list_of_constraint_types(opf1.method.jump)
            @test num_constraints(opf1.method.jump, list[1], list[2]) ==
                num_constraints(opf2.method.jump, list[1], list[2])
        end
    end

    ########## Second Pass ##########
    updateBus!(system1; label = 1, type = 1, conductance = 0.06, angle = -0.01)

    updateBranch!(system1; label = 22, reactance = 0.35, minFromBus = -0.22)
    updateBranch!(system1; label = 22, maxFromBus = 0.22, minToBus = -0.22, maxToBus = 0.22)
    updateBranch!(system1; label = 21, status = 0)

    addGenerator!(system1; label = 11, bus = 14, active = 0.3, minActive = 0.0)

    updateGenerator!(system1; label = 11, maxActive = 0.5, status = 0)

    cost!(system1; generator = 11, active = 2, polynomial = [165.0])
    cost!(system1; generator = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system1; generator = 9, active = 2, polynomial = [856.2; 135.3; 80])

    dcModel!(system1)
    opf1 = dcOptimalPowerFlow(system1, Ipopt.Optimizer)
    powerFlow!(system1, opf1; power = true)

    # Reuse DC Optimal Power Flow Model
    updateBus!(system2, opf2; label = 1, type = 1, conductance = 0.06, angle = -0.01)

    updateBranch!(system2, opf2; label = 22, reactance = 0.35, minFromBus = -0.22)
    updateBranch!(system2, opf2; label = 22, maxFromBus = 0.22, minToBus = -0.22, maxToBus = 0.22)
    updateBranch!(system2, opf2; label = 21, status = 0)

    addGenerator!(system2, opf2; label = 11, bus = 14, active = 0.3, minActive = 0.0)

    updateGenerator!(system2, opf2; label = 11, maxActive = 0.5, status = 0)

    cost!(system2, opf2; generator = 11, active = 2, polynomial = [165.0])
    cost!(system2, opf2; generator = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system2, opf2; generator = 9, active = 2, polynomial = [856.2; 135.3; 80])

    setInitialPoint!(system2, opf2)
    powerFlow!(system2, opf2; power = true)

    @testset "Second Pass" begin
        compstruct(opf1.voltage, opf2.voltage; atol = 1e-10)
        compstruct(opf1.power, opf2.power; atol = 1e-10)
        @test objective_value(opf1.method.jump) ≈ objective_value(opf2.method.jump)

        for list in list_of_constraint_types(opf1.method.jump)
            @test num_constraints(opf1.method.jump, list[1], list[2]) ==
                num_constraints(opf2.method.jump, list[1], list[2])
        end
    end
end