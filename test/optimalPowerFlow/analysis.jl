system14 = powerSystem(path * "case14optimal.m")
@testset "AC Optimal Power Flow" begin
    matpwr14 = h5read(path * "results.h5", "case14optimal/acOptimalPowerFlow")

    ########## IEEE 14-bus Test Case ##########
    analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer; print = false)
    solve!(system14, analysis)
    power!(system14, analysis)
    current!(system14, analysis)

    power = analysis.power
    voltage = analysis.voltage
    current = analysis.current
    branch = system14.branch
    to = branch.layout.to
    from = branch.layout.from

    @testset "IEEE 14: Voltages" begin
        @test voltage.magnitude ≈ matpwr14["voltageMagnitude"] atol = 1e-6
        @test voltage.angle ≈ matpwr14["voltageAngle"] atol = 1e-6
    end

    @testset "IEEE 14: Powers" begin
        @test power.injection.active ≈ matpwr14["injectionActive"] atol = 1e-6
        @test power.injection.reactive ≈ matpwr14["injectionReactive"] atol = 1e-6
        @test power.supply.active ≈ matpwr14["supplyActive"] atol = 1e-6
        @test power.supply.reactive ≈ matpwr14["supplyReactive"] atol = 1e-6
        @test power.shunt.active ≈ matpwr14["shuntActive"] atol = 1e-6
        @test power.shunt.reactive ≈ matpwr14["shuntReactive"] atol = 1e-6
        @test power.from.active ≈ matpwr14["fromActive"] atol = 1e-6
        @test power.from.reactive ≈ matpwr14["fromReactive"] atol = 1e-6
        @test power.to.active ≈ matpwr14["toActive"] atol = 1e-6
        @test power.to.reactive ≈ matpwr14["toReactive"] atol = 1e-6
        @test power.charging.reactive ≈ matpwr14["chargingFrom"] + matpwr14["chargingTo"] atol = 1e-6
        @test power.series.active ≈ matpwr14["lossActive"] atol = 1e-6
        @test power.series.reactive ≈ matpwr14["lossReactive"] atol = 1e-6
        @test power.generator.active ≈ matpwr14["generatorActive"] atol = 1e-6
        @test power.generator.reactive ≈ matpwr14["generatorReactive"] atol = 1e-6
    end

    @testset "IEEE 14: Currents" begin
        Si = complex.(power.injection.active, power.injection.reactive)
        Vi = voltage.magnitude .* cis.(voltage.angle)
        @test current.injection.magnitude .* cis.(-current.injection.angle) ≈ Si ./ Vi

        Sij = complex.(power.from.active, power.from.reactive)
        Vi = voltage.magnitude[from] .* cis.(voltage.angle[from])
        @test current.from.magnitude .* cis.(-current.from.angle) ≈ Sij ./ Vi

        Sji = complex.(power.to.active, power.to.reactive)
        Vj = voltage.magnitude[to] .* cis.(voltage.angle[to])
        @test current.to.magnitude .* cis.(-current.to.angle) ≈ Sji ./ Vj

        ratio = (1 ./ branch.parameter.turnsRatio) .* cis.(-branch.parameter.shiftAngle)
        Sijb = complex.(power.series.active, power.series.reactive)
        @test current.series.magnitude .* cis.(-current.series.angle) ≈ Sijb ./ (ratio .* Vi - Vj)
    end

    @testset "IEEE 14: Specific Bus Powers and Currents" begin
        for (key, value) in system14.bus.label
            active, reactive = injectionPower(system14, analysis; label = key)
            @test active ≈ power.injection.active[value]
            @test reactive ≈ power.injection.reactive[value]

            active, reactive = supplyPower(system14, analysis; label = key)
            @test active ≈ power.supply.active[value]
            @test reactive ≈ power.supply.reactive[value]

            active, reactive = shuntPower(system14, analysis; label = key)
            @test active ≈ power.shunt.active[value] atol = 1e-15
            @test reactive ≈ power.shunt.reactive[value] atol = 1e-15

            magnitude, angle = injectionCurrent(system14, analysis; label = key)
            @test magnitude ≈ current.injection.magnitude[value]
            @test angle ≈ current.injection.angle[value]
        end
    end

    @testset "IEEE 14: Specific Branch Powers and Currents" begin
        for (key, value) in system14.branch.label
            active, reactive = fromPower(system14, analysis; label = key)
            @test active ≈ power.from.active[value]
            @test reactive ≈ power.from.reactive[value]

            active, reactive = toPower(system14, analysis; label = key)
            @test active ≈ power.to.active[value]
            @test reactive ≈ power.to.reactive[value]

            active, reactive = chargingPower(system14, analysis; label = key)
            @test active ≈ power.charging.active[value]
            @test reactive ≈ power.charging.reactive[value]

            active, reactive = seriesPower(system14, analysis; label = key)
            @test active ≈ power.series.active[value]
            @test reactive ≈ power.series.reactive[value]

            magnitude, angle = fromCurrent(system14, analysis; label = key)
            @test magnitude ≈ current.from.magnitude[value]
            @test angle ≈ current.from.angle[value]

            magnitude, angle = toCurrent(system14, analysis; label = key)
            @test magnitude ≈ current.to.magnitude[value]
            @test angle ≈ current.to.angle[value]

            magnitude, angle = seriesCurrent(system14, analysis; label = key)
            @test magnitude ≈ current.series.magnitude[value]
            @test angle ≈ current.series.angle[value]
        end
    end

    @testset "IEEE 14: Specific Generator Powers" begin
        for (key, value) in system14.generator.label
            active, reactive = generatorPower(system14, analysis; label = key)
            @test active ≈ power.generator.active[value]
            @test reactive ≈ power.generator.reactive[value]
        end
    end

    @testset "IEEE 14: Apparent Power Native Flow Constraints" begin
        system14.branch.flow.type .= 2

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer; print = false)
        solve!(system14, analysis)

        @test analysis.voltage.magnitude ≈ matpwr14["voltageMagnitude"] atol = 1e-6
        @test analysis.voltage.angle ≈ matpwr14["voltageAngle"] atol = 1e-6

        @test analysis.power.generator.active ≈ matpwr14["generatorActive"] atol = 1e-6
        @test analysis.power.generator.reactive ≈ matpwr14["generatorReactive"] atol = 1e-6
    end

    @testset "IEEE 14: Active Power Flow Constraints" begin
        matpwr14 = h5read(path * "results.h5", "case14optimal/acOptimalPowerFlowActive")
        system14.branch.flow.type .= 1

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer; print = false)
        solve!(system14, analysis)

        @test analysis.voltage.magnitude ≈ matpwr14["voltageMagnitude"] atol = 1e-6
        @test analysis.voltage.angle ≈ matpwr14["voltageAngle"] atol = 1e-6

        @test analysis.power.generator.active ≈ matpwr14["generatorActive"] atol = 1e-6
        @test analysis.power.generator.reactive ≈ matpwr14["generatorReactive"] atol = 1e-6
    end

    @testset "IEEE 14: Current Magnitude Native Flow Constraints" begin
        matpwr14 = h5read(path * "results.h5", "case14optimal/acOptimalPowerFlowCurrent")
        system14.branch.flow.type .= 4

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer; print = false)
        solve!(system14, analysis)
        solve!(system14, analysis)

        @test analysis.voltage.magnitude ≈ matpwr14["voltageMagnitude"] atol = 1e-6
        @test analysis.voltage.angle ≈ matpwr14["voltageAngle"] atol = 1e-6

        @test analysis.power.generator.active ≈ matpwr14["generatorActive"] atol = 1e-6
        @test analysis.power.generator.reactive ≈ matpwr14["generatorReactive"] atol = 1e-6
    end

    @testset "IEEE 14: Current Magnitude Squared Flow Constraints" begin
        system14.branch.flow.type .= 5

        analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer; print = false)
        solve!(system14, analysis)
        solve!(system14, analysis)

        @test analysis.voltage.magnitude ≈ matpwr14["voltageMagnitude"] atol = 1e-6
        @test analysis.voltage.angle ≈ matpwr14["voltageAngle"] atol = 1e-6

        @test analysis.power.generator.active ≈ matpwr14["generatorActive"] atol = 1e-6
        @test analysis.power.generator.reactive ≈ matpwr14["generatorReactive"] atol = 1e-6
    end
end

system14 = powerSystem(path * "case14test.m")
system30 = powerSystem(path * "case30test.m")
@testset "DC Optimal Power Flow" begin
    matpwr14 = h5read(path * "results.h5", "case14test/dcOptimalPowerFlow")
    matpwr30 = h5read(path * "results.h5", "case30test/dcOptimalPowerFlow")

    ########## IEEE 14-bus Test Case ##########
    dcModel!(system14)
    analysis = dcOptimalPowerFlow(system14, Ipopt.Optimizer; print = false)
    solve!(system14, analysis)
    power!(system14, analysis)

    @testset "IEEE 14: Voltage Angles" begin
        @test analysis.voltage.angle ≈ matpwr14["voltage"] atol = 1e-6
    end

    @testset "IEEE 14: Active Powers" begin
        @test analysis.power.injection.active ≈ matpwr14["injection"] atol = 1e-6
        @test analysis.power.supply.active ≈ matpwr14["supply"] atol = 1e-6
        @test analysis.power.from.active ≈ matpwr14["from"] atol = 1e-6
        @test analysis.power.to.active ≈ -matpwr14["from"] atol = 1e-6
        @test analysis.power.generator.active ≈ matpwr14["generator"] atol = 1e-6
    end

    @testset "IEEE 14: Specific Bus Active Powers" begin
        for (key, value) in system14.bus.label
            injection = injectionPower(system14, analysis; label = key)
            supply = supplyPower(system14, analysis; label = key)

            @test injection ≈ analysis.power.injection.active[value]
            @test supply ≈ analysis.power.supply.active[value]
        end
    end

    @testset "IEEE 14: Specific Branch Active Powers" begin
        for (key, value) in system14.branch.label
            from = fromPower(system14, analysis; label = key)
            to = toPower(system14, analysis; label = key)

            @test from ≈ analysis.power.from.active[value]
            @test to ≈ analysis.power.to.active[value]
        end
    end

    # Test  Generator Active Powers
    @testset "IEEE 14: Specific Generator Active Powers" begin
        for (key, value) in system14.generator.label
            generator = generatorPower(system14, analysis; label = key)
            @test generator ≈ analysis.power.generator.active[value]
        end
    end

    ########## IEEE 30-bus Test Case ##########
    analysis = dcOptimalPowerFlow(system30, HiGHS.Optimizer; print = false)
    solve!(system30, analysis)
    solve!(system30, analysis)
    power!(system30, analysis)

    @testset "IEEE 30: Voltage Angles" begin
        @test analysis.voltage.angle ≈ matpwr30["voltage"] atol = 1e-10
    end

    @testset "IEEE 30: Active Powers" begin
        @test analysis.power.injection.active ≈ matpwr30["injection"] atol = 1e-6
        @test analysis.power.supply.active ≈ matpwr30["supply"] atol = 1e-10
        @test analysis.power.from.active ≈ matpwr30["from"] atol = 1e-10
        @test analysis.power.to.active ≈ -matpwr30["from"] atol = 1e-10
        @test analysis.power.generator.active ≈ matpwr30["generator"] atol = 1e-10
    end

    @testset "IEEE 30: Specific Bus Active Powers" begin
        for (key, value) in system30.bus.label
            injection = injectionPower(system30, analysis; label = key)
            supply = supplyPower(system30, analysis; label = key)

            @test injection ≈ analysis.power.injection.active[value]
            @test supply ≈ analysis.power.supply.active[value]
        end
    end

    @testset "IEEE 30: Specific Branch Active Powers" begin
        for (key, value) in system30.branch.label
            from = fromPower(system30, analysis; label = key)
            to = toPower(system30, analysis; label = key)

            @test from ≈ analysis.power.from.active[value]
            @test to ≈ analysis.power.to.active[value]
        end
    end

    @testset "IEEE 30: Specific Generator Active Powers" begin
        for (key, value) in system30.generator.label
            generator = generatorPower(system30, analysis; label = key)
            @test generator ≈ analysis.power.generator.active[value]
        end
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
    analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer; print = false)
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
    analysis = dcOptimalPowerFlow(system14, Ipopt.Optimizer; print = false)
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
    analysis = acOptimalPowerFlow(system14, Ipopt.Optimizer; print = false)
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
    analysis = dcOptimalPowerFlow(system14, Ipopt.Optimizer; print = false)
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