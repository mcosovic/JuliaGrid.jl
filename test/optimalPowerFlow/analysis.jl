system14 = powerSystem(path * "case14optimal.m")
@testset "AC Optimal Power Flow" begin
    matpwr14 = h5read(path * "results.h5", "case14optimal/acOptimalPowerFlow")

    ########## IEEE 14-bus Test Case ##########
    analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
    powerFlow!(analysis; power = true, current = true)

    @testset "IEEE 14: Matpower" begin
        testVoltage(matpwr14, analysis; atol = 1e-6)
        testPower(matpwr14, analysis; atol = 1e-6)
    end

    @testset "IEEE 14: Powers and Currents" begin
        testBus(analysis)
        testBranch(analysis)
        testGenerator(analysis)
        testCurrent(analysis)
    end

    @testset "IEEE 14: Apparent Power Native Flow Constraints" begin
        system14.branch.flow.type .= 2

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
        powerFlow!(analysis)

        testVoltage(matpwr14, analysis; atol = 1e-6)
        testGenPower(matpwr14, analysis; atol = 1e-6)
    end

    @testset "IEEE 14: Active Power Flow Constraints" begin
        matpwr14 = h5read(path * "results.h5", "case14optimal/acOptimalPowerFlowActive")
        system14.branch.flow.type .= 1

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
        powerFlow!(analysis)

        testVoltage(matpwr14, analysis; atol = 1e-6)
        testGenPower(matpwr14, analysis; atol = 1e-6)
    end

    @testset "IEEE 14: Current Magnitude Native Flow Constraints" begin
        matpwr14 = h5read(path * "results.h5", "case14optimal/acOptimalPowerFlowCurrent")
        system14.branch.flow.type .= 4

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
        powerFlow!(analysis)

        testVoltage(matpwr14, analysis; atol = 1e-6)
        testGenPower(matpwr14, analysis; atol = 1e-6)
    end

    @testset "IEEE 14: Current Magnitude Squared Flow Constraints" begin
        system14.branch.flow.type .= 5

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
        powerFlow!(analysis)

        testVoltage(matpwr14, analysis; atol = 1e-6)
        testGenPower(matpwr14, analysis; atol = 1e-6)
    end

    @testset "IEEE 14: Set Initial Point" begin
        pf = newtonRaphson(system14)
        powerFlow!(pf; power = true)
        setInitialPoint!(analysis, pf)
        teststruct(analysis.voltage, pf.voltage)
        teststruct(analysis.power.generator, pf.power.generator)

        pf = dcPowerFlow(system14)
        powerFlow!(pf; power = true)
        setInitialPoint!(analysis, pf)
        @test analysis.voltage.angle == pf.voltage.angle
        @test analysis.power.generator.active == pf.power.generator.active

        opf = acOptimalPowerFlow(system14, Ipopt.Optimizer)
        powerFlow!(opf; power = true)
        setInitialPoint!(analysis, opf)
        teststruct(analysis.voltage, opf.voltage)
        teststruct(analysis.power.generator, opf.power.generator)
        teststruct(analysis.method.dual, opf.method.dual)

        opf = dcOptimalPowerFlow(system14, Ipopt.Optimizer)
        powerFlow!(opf; power = true)
        setInitialPoint!(analysis, opf)
        @test analysis.voltage.angle == opf.voltage.angle
        @test analysis.power.generator.active == opf.power.generator.active
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
    powerFlow!(analysis; power = true)

    @testset "IEEE 14: Matpower" begin
        @test analysis.voltage.angle ≈ matpwr14["voltage"] atol = 1e-6
        testPower(matpwr14, analysis; atol = 1e-6)
    end

    @testset "IEEE 14: Powers" begin
        testBus(analysis)
        testBranch(analysis)
        testGenerator(analysis)
    end

    ########## IEEE 30-bus Test Case ##########
    analysis = dcOptimalPowerFlow(system30, HiGHS.Optimizer)
    powerFlow!(analysis; power = true)

    @testset "IEEE 30: Matpower" begin
        @test analysis.voltage.angle ≈ matpwr30["voltage"] atol = 1e-10
        testPower(matpwr30, analysis; atol = 1e-6)
    end

    @testset "IEEE 30: Powers" begin
        testBus(analysis)
        testBranch(analysis)
        testGenerator(analysis)
    end

    @testset "IEEE 30: Set Initial Point" begin
        pf = newtonRaphson(system30)
        powerFlow!(pf; power = true)
        setInitialPoint!(analysis, pf)
        @test analysis.voltage.angle == pf.voltage.angle
        @test analysis.power.generator.active == pf.power.generator.active

        pf = dcPowerFlow(system30)
        powerFlow!(pf; power = true)
        setInitialPoint!(analysis, pf)
        @test analysis.voltage.angle == pf.voltage.angle
        @test analysis.power.generator.active == pf.power.generator.active

        opf = acOptimalPowerFlow(system30, Ipopt.Optimizer)
        powerFlow!(opf; power = true)
        setInitialPoint!(analysis, opf)
        @test analysis.voltage.angle == opf.voltage.angle
        @test analysis.power.generator.active == opf.power.generator.active

        opf = dcOptimalPowerFlow(system30, Ipopt.Optimizer)
        powerFlow!(opf; power = true)
        setInitialPoint!(analysis, opf)
        teststruct(analysis.voltage, opf.voltage)
        teststruct(analysis.power.generator, opf.power.generator)
        teststruct(analysis.method.dual, opf.method.dual)
    end
end

@testset "Errors" begin
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

    @test_throws err cost!(dc; generator = "Gen 1", active = 1, piecewise = [5.1 6.2])
end

@testset "Print Data in Per-Units" begin
    @config(label = Integer)
    @bus(label = String)

    ########## Print AC Data ##########
    system14 = powerSystem(path * "case14test.m")
    analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
    @suppress powerFlow!(analysis; verbose = 3)

    @suppress @testset "Bus Constraint AC Data" begin
        printBusConstraint(analysis; delimiter = "")
        printBusConstraint(analysis; style = false)
        printBusConstraint(analysis; label = "Bus 1 HV", header = true)
        printBusConstraint(analysis; label = "Bus 2 HV", footer = true)
    end

    @suppress @testset "Branch Constraint AC Data" begin
        printBranchConstraint(analysis; delimiter = "")
        printBranchConstraint(analysis; label = 5, header = true)
        printBranchConstraint(analysis; label = 6, footer = true)
        printBranchConstraint(analysis; style = false)
    end

    @suppress @testset "Generator Constraint AC Data" begin
        printGeneratorConstraint(analysis; delimiter = "")
        printGeneratorConstraint(analysis; label = 5, header = true)
        printGeneratorConstraint(analysis; label = 6, footer = true)
        printGeneratorConstraint(analysis; style = false)
    end

    ########## Print DC Data ##########
    analysis = dcOptimalPowerFlow(system14, Ipopt.Optimizer)
    @suppress powerFlow!(analysis; verbose = 3)

    @suppress @testset "Bus Constraint DC Data" begin
        printBusConstraint(analysis; delimiter = "")
        printBusConstraint(analysis; style = false)
        printBusConstraint(analysis; label = "Bus 3 HV", header = true)
        printBusConstraint(analysis; label = "Bus 2 HV", footer = true)
    end

    @suppress @testset "Branch Constraint DC Data" begin
        printBranchConstraint(analysis; delimiter = "")
        printBranchConstraint(analysis; label = 5, header = true)
        printBranchConstraint(analysis; label = 6, footer = true)
        printBranchConstraint(analysis; style = false)
    end

    @suppress @testset "Generator Constraint DC Data" begin
        printGeneratorConstraint(analysis; delimiter = "")
        printGeneratorConstraint(analysis; label = 5, header = true)
        printGeneratorConstraint(analysis; label = 6, footer = true)
        printGeneratorConstraint(analysis; style = false)
    end

    @suppress print(analysis.method.constraint.balance.active)
    @suppress print(system14.bus.label, analysis.method.constraint.balance.active)
    @suppress print(system14.generator.label, analysis.method.constraint.piecewise.active)
    @suppress print(analysis.method.constraint.piecewise.active)
end

@testset "Print Data in SI Units" begin
    @default(template)
    @power(kW, MVAr, MVA)
    @voltage(kV, deg, V)
    @current(MA, deg)
    @bus(label = Int64)
    @branch(label = "B?")
    @generator(label = "G?")

    ########## Print AC Data ##########
    system14 = powerSystem(path * "case14test.m")
    analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
    powerFlow!(analysis)

    @suppress @testset "Bus Constraint AC Data" begin
        printBusConstraint(analysis; delimiter = "")
        printBusConstraint(analysis; style = false)
        printBusConstraint(analysis; label = 1, header = true)
        printBusConstraint(analysis; label = 2, footer = true)
    end

    @suppress @testset "Branch Constraint AC Data" begin
        printBranchConstraint(analysis; delimiter = "")
        printBranchConstraint(analysis; label = "B5", header = true)
        printBranchConstraint(analysis; label = "B6", footer = true)
        printBranchConstraint(analysis; style = false)
    end

    @suppress @testset "Generator Constraint AC Data" begin
        printGeneratorConstraint(analysis; delimiter = "")
        printGeneratorConstraint(analysis; label = "G5", header = true)
        printGeneratorConstraint(analysis; label = "G6", footer = true)
        printGeneratorConstraint(analysis; style = false)
    end

    ########## Print DC Data ##########
    analysis = dcOptimalPowerFlow(system14, Ipopt.Optimizer)
    powerFlow!(analysis)

    @suppress @testset "Bus Constraint DC Data" begin
        printBusConstraint(analysis; delimiter = "")
        printBusConstraint(analysis; style = false)
        printBusConstraint(analysis; label = 1, header = true)
        printBusConstraint(analysis; label = 2, footer = true)
    end

    @suppress @testset "Branch Constraint DC Data" begin
        printBranchConstraint(analysis; delimiter = "")
        printBranchConstraint(analysis; label = "B5", header = true)
        printBranchConstraint(analysis; label = "B6", footer = true)
        printBranchConstraint(analysis; style = false)
    end

    @suppress @testset "Generator Constraint DC Data" begin
        printGeneratorConstraint(analysis; delimiter = "")
        printGeneratorConstraint(analysis; label = "G5", header = true)
        printGeneratorConstraint(analysis; label = "G6", footer = true)
        printGeneratorConstraint(analysis; style = false)
    end
end