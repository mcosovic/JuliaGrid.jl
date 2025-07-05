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

    analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer; interval = false)
    powerFlow!(analysis; power = true)

    @testset "IEEE 14: Matpower" begin
        testVoltage(matpwr14, analysis; atol = 1e-6)
        testPower(matpwr14, analysis; atol = 1e-6)
    end

    @testset "IEEE 14: Apparent Power Native Flow Constraints" begin
        system14.branch.flow.type .= 2

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer)
        powerFlow!(analysis)

        testVoltage(matpwr14, analysis; atol = 1e-6)
        testGenPower(matpwr14, analysis; atol = 1e-6)

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer; interval = false)
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

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer; interval = false)
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

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer; interval = false)
        powerFlow!(analysis)

        testVoltage(matpwr14, analysis; atol = 1e-6)
        testGenPower(matpwr14, analysis; atol = 1e-6)
    end

    @testset "IEEE 14: Current Magnitude Squared Flow Constraints" begin
        system14.branch.flow.type .= 5

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer; interval = false)
        powerFlow!(analysis)

        testVoltage(matpwr14, analysis; atol = 1e-6)
        testGenPower(matpwr14, analysis; atol = 1e-6)

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

    opf = acOptimalPowerFlow(system14, Ipopt.Optimizer)

    @testset "IEEE 14: Add Duals" begin
        addDual!(opf, :slack; index = 1, dual = 10.0)
        @test opf.method.dual.slack.angle[1][:equality] == 10.0

        addDual!(opf, :capability, :active; index = 1, lower = 20.0, upper = 30.0)
        @test opf.method.dual.capability.active[1][:lower] == 20.0
        @test opf.method.dual.capability.active[1][:upper] == 30.0

        addDual!(opf, :capability, :reactive; index = 1, lower = 40.0, upper = 50.0)
        @test opf.method.dual.capability.reactive[1][:lower] == 40.0
        @test opf.method.dual.capability.reactive[1][:upper] == 50.0

        addDual!(opf, :capability, :upper; index = 2, dual = 60.0)
        @test opf.method.dual.capability.upper[2][:upper] == 60.0

        addDual!(opf, :capability, :lower; index = 2, dual = 70.0)
        @test opf.method.dual.capability.lower[2][:upper] == 70.0

        addDual!(opf, :balance, :active; index = 2, dual = 80.0)
        @test opf.method.dual.balance.active[2][:equality] == 80.0

        addDual!(opf, :balance, :reactive; index = 2, dual = 90.0)
        @test opf.method.dual.balance.reactive[2][:equality] == 90.0

        addDual!(opf, :voltage, :magnitude; index = 6, lower = 100.0, upper = 110.0)
        @test opf.method.dual.voltage.magnitude[6][:lower] == 100.0
        @test opf.method.dual.voltage.magnitude[6][:upper] == 110.0

        addDual!(opf, :voltage, :angle; index = 3, dual = 120.0)
        @test opf.method.dual.voltage.angle[3][:interval] == 120.0

        addDual!(opf, :flow, :from; index = 7, dual = 130.0)
        @test opf.method.dual.flow.from[7][:interval] == 130.0

        addDual!(opf, :flow, :to; index = 7, dual = 140.0)
        @test opf.method.dual.flow.to[7][:interval] == 140.0

        addDual!(opf, :piecewise, :active; index = 5, subindex = 2, dual = 150.0)
        @test opf.method.dual.piecewise.active[5][:upper][2] == 150.0

        addDual!(opf, :piecewise, :reactive; index = 5, subindex = 2, dual = 160.0)
        @test opf.method.dual.piecewise.reactive[5][:upper][2] == 160.0
    end

    @testset "IEEE 14: Remove" begin
        remove!(opf, :slack; index = 1)
        @test isempty(opf.method.constraint.slack.angle[1])
        @test isempty(opf.method.dual.slack.angle[1])

        remove!(opf, :capability, :active; index = 1)
        @test isempty(opf.method.constraint.capability.active[1])
        @test isempty(opf.method.dual.capability.active[1])

        remove!(opf, :capability, :reactive; index = 1)
        @test isempty(opf.method.constraint.capability.reactive[1])
        @test isempty(opf.method.dual.capability.reactive[1])

        remove!(opf, :capability, :upper; index = 2)
        @test isempty(opf.method.constraint.capability.upper[2])
        @test isempty(opf.method.dual.capability.upper[2])

        remove!(opf, :capability, :lower; index = 2)
        @test isempty(opf.method.constraint.capability.lower[2])
        @test isempty(opf.method.dual.capability.lower[2])

        remove!(opf, :balance, :active; index = 2)
        @test isempty(opf.method.constraint.balance.active[2])
        @test isempty(opf.method.dual.balance.active[2])

        remove!(opf, :balance, :reactive; index = 2)
        @test isempty(opf.method.constraint.balance.reactive[2])
        @test isempty(opf.method.dual.balance.reactive[2])

        remove!(opf, :voltage, :magnitude; index = 6)
        @test isempty(opf.method.constraint.voltage.magnitude[6])
        @test isempty(opf.method.dual.voltage.magnitude[6])

        remove!(opf, :voltage, :angle; index = 3)
        @test isempty(opf.method.constraint.voltage.angle[3])
        @test isempty(opf.method.dual.voltage.angle[3])

        remove!(opf, :flow, :from; index = 7)
        @test isempty(opf.method.constraint.flow.from[7])
        @test isempty(opf.method.dual.flow.from[7])

        remove!(opf, :flow, :to; index = 7)
        @test isempty(opf.method.constraint.flow.to[7])
        @test isempty(opf.method.dual.flow.to[7])

        remove!(opf, :piecewise, :active; index = 5)
        @test isempty(opf.method.constraint.piecewise.active[5])
        @test isempty(opf.method.dual.piecewise.active[5])

        remove!(opf, :piecewise, :reactive; index = 5)
        @test isempty(opf.method.constraint.piecewise.reactive[5])
        @test isempty(opf.method.dual.piecewise.reactive[5])
    end

        @testset "IEEE 14: Extended Model" begin
        @addVariable(opf, 0 <= x <= 1.0, primal = 2.0, lower = 3.0, upper = 4.0)
        @test is_valid(opf.method.jump, x)
        @test is_valid(opf.method.jump, opf.extended.variable[1])
        @test opf.extended.solution[1] == 2.0
        @test opf.extended.dual.variable[1][:lower] == 3.0
        @test opf.extended.dual.variable[1][:upper] == 4.0

        @addVariable(opf, 0 <= y[i = 1:2] <= 1.0, primal = [2.1; 3.1], upper = [4.1; 5.1])
        @test is_valid(opf.method.jump, y[1])
        @test is_valid(opf.method.jump, y[2])
        @test is_valid(opf.method.jump, opf.extended.variable[2])
        @test is_valid(opf.method.jump, opf.extended.variable[3])
        @test opf.extended.solution[2] == 2.1
        @test opf.extended.solution[3] == 3.1
        @test opf.extended.dual.variable[2][:upper] == 4.1
        @test opf.extended.dual.variable[3][:upper] == 5.1

        @addConstraint(opf, con, x + y[1] <= 2.5, dual = 6.0)
        @test is_valid(opf.method.jump, con)
        @test is_valid(opf.method.jump, opf.extended.constraint[1])
        @test opf.extended.dual.constraint[1] == 6.0

        remove!(opf, :constraint; index = 1)
        @test isempty(opf.extended.constraint) && isempty(opf.extended.dual.constraint)
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

    analysis = dcOptimalPowerFlow(system14, HiGHS.Optimizer; interval = false)
    powerFlow!(analysis; power = true)

    @testset "IEEE 14: Matpower" begin
        @test analysis.voltage.angle ≈ matpwr14["voltage"] atol = 1e-6
        testPower(matpwr14, analysis; atol = 1e-6)
    end

    opf = dcOptimalPowerFlow(system14, HiGHS.Optimizer)

    @testset "IEEE 14: Add Duals" begin
        addDual!(opf, :slack; index = 1, dual = 10.0)
        @test opf.method.dual.slack.angle[1][:equality] == 10.0

        addDual!(opf, :capability; index = 1, lower = 20.0, upper = 30.0)
        @test opf.method.dual.capability.active[1][:lower] == 20.0
        @test opf.method.dual.capability.active[1][:upper] == 30.0

        addDual!(opf, :balance; index = 2, dual = 40.0)
        @test opf.method.dual.balance.active[2][:equality] == 40.0

        addDual!(opf, :voltage; index = 6, dual = 50.0)
        @test opf.method.dual.voltage.angle[6][:interval] == 50.0

        addDual!(opf, :flow; index = 9, dual = 60.0)
        @test opf.method.dual.flow.active[9][:interval] == 60.0

        addDual!(opf, :piecewise; index = 8, subindex = 2, dual = 80.0)
        @test opf.method.dual.piecewise.active[8][:upper][2] == 80.0
    end

    @testset "IEEE 14: Remove" begin
        remove!(opf, :slack; index = 1)
        @test isempty(opf.method.constraint.slack.angle[1])
        @test isempty(opf.method.dual.slack.angle[1])

        remove!(opf, :capability; index = 1)
        @test isempty(opf.method.constraint.capability.active[1])
        @test isempty(opf.method.dual.capability.active[1])

        remove!(opf, :balance; index = 2)
        @test isempty(opf.method.constraint.balance.active[2])
        @test isempty(opf.method.dual.balance.active[2])

        remove!(opf, :voltage; index = 6)
        @test isempty(opf.method.constraint.voltage.angle[6])
        @test isempty(opf.method.dual.voltage.angle[6])

        remove!(opf, :flow; index = 9)
        @test isempty(opf.method.constraint.flow.active[9])
        @test isempty(opf.method.dual.flow.active[9])

        remove!(opf, :piecewise; index = 8)
        @test isempty(opf.method.constraint.piecewise.active[8])
        @test isempty(opf.method.dual.piecewise.active[8])
    end

    ########## IEEE 30-bus Test Case ##########
    analysis = dcOptimalPowerFlow(system30, HiGHS.Optimizer; interval = false)
    powerFlow!(analysis; power = true)

    @testset "IEEE 30: Matpower" begin
        @test analysis.voltage.angle ≈ matpwr30["voltage"] atol = 1e-10
        testPower(matpwr30, analysis; atol = 1e-6)
    end

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
    analysis = dcOptimalPowerFlow(system14, Ipopt.Optimizer; interval = false)
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
    @suppress print(analysis.method.constraint.voltage.angle)
    @suppress print(system14.bus.label, analysis.method.constraint.balance.active)
    @suppress print(system14.bus.label, analysis.method.constraint.voltage.angle)
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
    analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer; interval = false)
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