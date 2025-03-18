system14 = powerSystem(path * "case14optimal.m")
@testset "AC Optimal Power Flow" begin
    matpwr14 = h5read(path * "results.h5", "case14optimal/acOptimalPowerFlow")

    ########## IEEE 14-bus Test Case ##########
    analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
    powerFlow!(system14, analysis; power = true, current = true)

    @testset "IEEE 14: Matpower" begin
        testVoltageMatpower(matpwr14, analysis; atol = 1e-6)
        testPowerMatpower(matpwr14, analysis; atol = 1e-6)
    end

    @testset "IEEE 14: Powers and Currents" begin
        testCurrent(system14, analysis)
        testBus(system14, analysis)
        testBranch(system14, analysis)
        testGenerator(system14, analysis)
    end

    @testset "IEEE 14: Apparent Power Native Flow Constraints" begin
        system14.branch.flow.type .= 2

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
        powerFlow!(system14, analysis)

        testVoltageMatpower(matpwr14, analysis; atol = 1e-6)
        testGeneratorMatpower(matpwr14, analysis; atol = 1e-6)
    end

    @testset "IEEE 14: Active Power Flow Constraints" begin
        matpwr14 = h5read(path * "results.h5", "case14optimal/acOptimalPowerFlowActive")
        system14.branch.flow.type .= 1

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
        powerFlow!(system14, analysis)

        testVoltageMatpower(matpwr14, analysis; atol = 1e-6)
        testGeneratorMatpower(matpwr14, analysis; atol = 1e-6)
    end

    @testset "IEEE 14: Current Magnitude Native Flow Constraints" begin
        matpwr14 = h5read(path * "results.h5", "case14optimal/acOptimalPowerFlowCurrent")
        system14.branch.flow.type .= 4

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
        powerFlow!(system14, analysis)

        testVoltageMatpower(matpwr14, analysis; atol = 1e-6)
        testGeneratorMatpower(matpwr14, analysis; atol = 1e-6)
    end

    @testset "IEEE 14: Current Magnitude Squared Flow Constraints" begin
        system14.branch.flow.type .= 5

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
        powerFlow!(system14, analysis)

        testVoltageMatpower(matpwr14, analysis; atol = 1e-6)
        testGeneratorMatpower(matpwr14, analysis; atol = 1e-6)
    end
end

system14 = powerSystem(path * "case14test.m")
system30 = powerSystem(path * "case30test.m")
@testset "DC Optimal Power Flow" begin
    matpwr14 = h5read(path * "results.h5", "case14test/dcOptimalPowerFlow")
    matpwr30 = h5read(path * "results.h5", "case30test/dcOptimalPowerFlow")

    ########## IEEE 14-bus Test Case ##########
    dcModel!(system14)
    analysis = dcOptimalPowerFlow(system14, Ipopt.Optimizer)
    powerFlow!(system14, analysis; power = true)

    @testset "IEEE 14: Matpower" begin
        @test analysis.voltage.angle ≈ matpwr14["voltage"] atol = 1e-6
        testPowerMatpower(matpwr14, analysis; atol = 1e-6)
    end

    @testset "IEEE 14: Powers" begin
        testBus(system14, analysis)
        testBranch(system14, analysis)
        testGenerator(system14, analysis)
    end

    ########## IEEE 30-bus Test Case ##########
    analysis = dcOptimalPowerFlow(system30, HiGHS.Optimizer)
    powerFlow!(system30, analysis; power = true)

    @testset "IEEE 30: Matpower" begin
        @test analysis.voltage.angle ≈ matpwr30["voltage"] atol = 1e-10
        testPowerMatpower(matpwr30, analysis; atol = 1e-6)
    end

    @testset "IEEE 30: Powers" begin
        testBus(system30, analysis)
        testBranch(system30, analysis)
        testGenerator(system30, analysis)
    end
end

@testset "Errors and Prints" begin
    @default(unit)
    @default(template)
    system = powerSystem()

    addBus!(system; label = "Bus 1", type = 2)
    addBus!(system; label = "Bus 2")
    addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)
    addGenerator!(system; label = "Gen 1", bus = "Bus 1", active = 0.2)

    err = ErrorException("The slack bus is missing.")
    @test_throws err dcOptimalPowerFlow(system, Ipopt.Optimizer)

    cost!(system; generator = "Gen 1", active = 1, piecewise = [5.1 6.2])
    updateBus!(system; label = "Bus 1", type = 3)
    err = ErrorException(
        "The generator labeled Gen 1 has a piecewise linear cost " *
        "function with only one defined point."
    )
    @test_throws err dcOptimalPowerFlow(system, Ipopt.Optimizer)

    cost!(system; generator = "Gen 1", active = 1, piecewise = [5.1 6.2; 4.1 5.2])
    dc = dcOptimalPowerFlow(system, Ipopt.Optimizer)
    err = ErrorException(
        "The generator labeled Gen 1 has a piecewise linear cost " *
        "function with only one defined point."
    )
    @test_throws err cost!(system, dc; generator = "Gen 1", active = 1, piecewise = [5.1 6.2])

    @capture_out print(dc.method.constraint.balance.active)
    @capture_out print(system.bus.label, dc.method.constraint.balance.active)

    cost!(system; generator = "Gen 1", active = 1, piecewise = [1.1 2.2; 2.1 3.2])
    dc = dcOptimalPowerFlow(system, Ipopt.Optimizer)
    @capture_out print(system.generator.label, dc.method.constraint.piecewise.active)
    @capture_out print(dc.method.constraint.piecewise.active)
end

@testset "Print Data in Per-Units" begin
    ########## Print AC Data ##########
    analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
    solve!(system14, analysis)

    @capture_out @testset "Bus Constraint AC Data" begin
        printBusConstraint(system14, analysis; delimiter = "")
        printBusConstraint(system14, analysis; style = false)
        printBusConstraint(system14, analysis; label = 1, header = true)
        printBusConstraint(system14, analysis; label = 2, footer = true)
    end

    @capture_out @testset "Branch Constraint AC Data" begin
        printBranchConstraint(system14, analysis; delimiter = "")
        printBranchConstraint(system14, analysis; label = 5, header = true)
        printBranchConstraint(system14, analysis; label = 6, footer = true)
        printBranchConstraint(system14, analysis; style = false)
    end

    @capture_out @testset "Generator Constraint AC Data" begin
        printGeneratorConstraint(system14, analysis; delimiter = "")
        printGeneratorConstraint(system14, analysis; label = 5, header = true)
        printGeneratorConstraint(system14, analysis; label = 6, footer = true)
        printGeneratorConstraint(system14, analysis; style = false)
    end

    ########## Print DC Data ##########
    analysis = dcOptimalPowerFlow(system14, Ipopt.Optimizer)
    solve!(system14, analysis)

    @capture_out @testset "Bus Constraint DC Data" begin
        printBusConstraint(system14, analysis; delimiter = "")
        printBusConstraint(system14, analysis; style = false)
        printBusConstraint(system14, analysis; label = 1, header = true)
        printBusConstraint(system14, analysis; label = 2, footer = true)
    end

    @capture_out @testset "Branch Constraint DC Data" begin
        printBranchConstraint(system14, analysis; delimiter = "")
        printBranchConstraint(system14, analysis; label = 5, header = true)
        printBranchConstraint(system14, analysis; label = 6, footer = true)
        printBranchConstraint(system14, analysis; style = false)
    end

    @capture_out @testset "Generator Constraint DC Data" begin
        printGeneratorConstraint(system14, analysis; delimiter = "")
        printGeneratorConstraint(system14, analysis; label = 5, header = true)
        printGeneratorConstraint(system14, analysis; label = 6, footer = true)
        printGeneratorConstraint(system14, analysis; style = false)
    end
end

@testset "Print Data in SI Units" begin
    @power(kW, MVAr, MVA)
    @voltage(kV, deg, V)
    @current(MA, deg)

    ########## Print AC Data ##########
    analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
    solve!(system14, analysis)

    @capture_out @testset "Bus Constraint AC Data" begin
        printBusConstraint(system14, analysis; delimiter = "")
        printBusConstraint(system14, analysis; style = false)
        printBusConstraint(system14, analysis; label = 1, header = true)
        printBusConstraint(system14, analysis; label = 2, footer = true)
    end

    @capture_out @testset "Branch Constraint AC Data" begin
        printBranchConstraint(system14, analysis; delimiter = "")
        printBranchConstraint(system14, analysis; label = 5, header = true)
        printBranchConstraint(system14, analysis; label = 6, footer = true)
        printBranchConstraint(system14, analysis; style = false)
    end

    @capture_out @testset "Generator Constraint AC Data" begin
        printGeneratorConstraint(system14, analysis; delimiter = "")
        printGeneratorConstraint(system14, analysis; label = 5, header = true)
        printGeneratorConstraint(system14, analysis; label = 6, footer = true)
        printGeneratorConstraint(system14, analysis; style = false)
    end

    ########## Print DC Data ##########
    analysis = dcOptimalPowerFlow(system14, Ipopt.Optimizer)
    solve!(system14, analysis)

    @capture_out @testset "Bus Constraint DC Data" begin
        printBusConstraint(system14, analysis; delimiter = "")
        printBusConstraint(system14, analysis; style = false)
        printBusConstraint(system14, analysis; label = 1, header = true)
        printBusConstraint(system14, analysis; label = 2, footer = true)
    end

    @capture_out @testset "Branch Constraint DC Data" begin
        printBranchConstraint(system14, analysis; delimiter = "")
        printBranchConstraint(system14, analysis; label = 5, header = true)
        printBranchConstraint(system14, analysis; label = 6, footer = true)
        printBranchConstraint(system14, analysis; style = false)
    end

    @capture_out @testset "Generator Constraint DC Data" begin
        printGeneratorConstraint(system14, analysis; delimiter = "")
        printGeneratorConstraint(system14, analysis; label = 5, header = true)
        printGeneratorConstraint(system14, analysis; label = 6, footer = true)
        printGeneratorConstraint(system14, analysis; style = false)
    end
end