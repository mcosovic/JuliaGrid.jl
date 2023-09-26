@testset "AC Optimal Power Flow" begin
    @default(unit)
    @default(template)

    ################ Resuing First Pass ################
    system = powerSystem(string(pathData, "case14optimal.m"))

    updateBus!(system; label = 1, type = 1, active = 0.15, reactive = 0.2, conductance = 0.16, angle = -0.1)
    updateBus!(system; label = 2, type = 3, angle = -0.01, magnitude = 0.99, minMagnitude = 0.98)
    addBranch!(system; label = 21, from = 5, to = 7, reactance = 0.25, turnsRatio = 0.98, shiftAngle = -0.1, status = 0)
    addBranch!(system; label = 22, from = 4, to = 5, reactance = 0.25, longTerm = 0.18, maxDiffAngle = 0.15, type = 2)
    updateBranch!(system; label = 21, status = 1)
    updateBranch!(system; label = 5, status = 0)
    updateBranch!(system; label = 21, reactance = 0.35, maxDiffAngle = 0.22)
    addGenerator!(system; label = 9, bus = 3, active = 0.3, minActive = 0.0, maxActive = 0.5, maxReactive = Inf, status = 0)
    cost!(system; label = 9, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    addGenerator!(system; label = 10, bus = 3, active = 0.3, maxActive = 1.0, maxReactive = Inf)
    cost!(system; label = 10, active = 2, polynomial = [452.2; 31; 18; 5])
    updateGenerator!(system; label = 9, status = 1, maxActive = 0.8, maxReactive = 0.8)
    updateGenerator!(system; label = 10, status = 0, maxActive = 0.8)
    updateGenerator!(system; label = 9, status = 0)
    cost!(system; label = 5, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system; label = 5, active = 2, polynomial = [452.2; 31; 18; 5])
    cost!(system; label = 5, active = 2, polynomial = [452.2; 31; 18])
    cost!(system; label = 5, active = 2, polynomial = [452.2; 31; 18; 6])
    cost!(system; label = 4, reactive = 2, polynomial = [452.2; 31; 18; 5])
    cost!(system; label = 4, reactive = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])

    acModel!(system)
    analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
    solve!(system, analysis)
    power!(system, analysis)

    ####### Reuse Model #######
    resystem = powerSystem(string(pathData, "case14optimal.m"))
    acModel!(resystem)
    reusing = acOptimalPowerFlow(resystem, Ipopt.Optimizer)

    updateBus!(resystem, reusing; label = 1, type = 1, active = 0.15, reactive = 0.2, conductance = 0.16, angle = -0.1)
    updateBus!(resystem, reusing; label = 2, type = 3, angle = -0.01, magnitude = 0.99, minMagnitude = 0.98)
    addBranch!(resystem, reusing; label = 21, from = 5, to = 7, reactance = 0.25, turnsRatio = 0.98, shiftAngle = -0.1, status = 0)
    addBranch!(resystem, reusing; label = 22, from = 4, to = 5, reactance = 0.25, longTerm = 0.18, maxDiffAngle = 0.15, type = 2)
    updateBranch!(resystem, reusing; label = 21, status = 1)
    updateBranch!(resystem, reusing; label = 5, status = 0)
    updateBranch!(resystem, reusing; label = 21, reactance = 0.35, maxDiffAngle = 0.22)
    addGenerator!(resystem, reusing; label = 9, bus = 3, active = 0.3, minActive = 0.0, maxActive = 0.5, maxReactive = Inf, status = 0)
    cost!(resystem, reusing; label = 9, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    addGenerator!(resystem, reusing; label = 10, bus = 3, active = 0.3, maxActive = 1.0, maxReactive = Inf)
    cost!(resystem, reusing; label = 10, active = 2, polynomial = [452.2; 31; 18; 5])
    updateGenerator!(resystem, reusing; label = 9, status = 1, maxActive = 0.8, maxReactive = 0.8)
    updateGenerator!(resystem, reusing; label = 10, status = 0, maxActive = 0.8)
    updateGenerator!(resystem, reusing; label = 9, status = 0)
    cost!(resystem, reusing; label = 5, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(resystem, reusing; label = 5, active = 2, polynomial = [452.2; 31; 18; 5])
    cost!(resystem, reusing; label = 5, active = 2, polynomial = [452.2; 31; 18])
    cost!(resystem, reusing; label = 5, active = 2, polynomial = [452.2; 31; 18])
    cost!(resystem, reusing; label = 5, active = 2, polynomial = [452.2; 31; 18; 6])
    cost!(resystem, reusing; label = 4, reactive = 2, polynomial = [452.2; 31; 18; 5])
    cost!(resystem, reusing; label = 4, reactive = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])

    solve!(resystem, reusing)
    power!(resystem, reusing)

    ###### Compare Objective, Voltages and Powers #######
    @test JuMP.objective_value(analysis.jump) ≈ JuMP.objective_value(reusing.jump)
    approxStruct(analysis.voltage, reusing.voltage)
    approxStruct(analysis.power.generator, reusing.power.generator)
    approxStruct(analysis.power.injection, reusing.power.injection)
    approxStruct(analysis.power.supply, reusing.power.supply)
    approxStruct(analysis.power.shunt, reusing.power.shunt)
    approxStruct(analysis.power.from, reusing.power.from)
    approxStruct(analysis.power.to, reusing.power.to)
    approxStruct(analysis.power.charging, reusing.power.charging)
    approxStruct(analysis.power.series, reusing.power.series)

    ################ Resuing Second Pass ################
    updateBus!(system; label = 1, type = 1, conductance = 0.06, susceptance = 0.8, angle = -0.01)
    updateBranch!(system; label = 21, status = 0)
    updateBranch!(system; label = 22, reactance = 0.35, longTerm = 0.22)
    addGenerator!(system; label = 11, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5, status = 1)
    addGenerator!(system; label = 12, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5)
    cost!(system; label = 11, active = 2, polynomial = [165.0])
    cost!(system; label = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system; label = 9, active = 2, polynomial = [856.2; 135.3; 80])

    acModel!(system)
    analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)

    solve!(system, analysis)
    power!(system, analysis)

    ####### Reuse Model #######
    updateBus!(resystem, reusing; label = 1, type = 1, conductance = 0.06, susceptance = 0.8, angle = -0.01)
    updateBranch!(resystem, reusing; label = 21, status = 0)
    updateBranch!(resystem, reusing; label = 22, reactance = 0.35, longTerm = 0.22)
    addGenerator!(resystem, reusing; label = 11, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5, status = 1)
    addGenerator!(resystem, reusing; label = 12, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5)
    cost!(resystem, reusing; label = 11, active = 2, polynomial = [165.0])
    cost!(resystem, reusing; label = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(resystem, reusing; label = 9, active = 2, polynomial = [856.2; 135.3; 80])

    startingVoltage!(resystem, reusing)
    solve!(resystem, reusing)
    power!(resystem, reusing)

    ###### Compare Objective, Voltages and Powers #######
    @test JuMP.objective_value(analysis.jump) ≈ JuMP.objective_value(reusing.jump)
    approxStruct(analysis.voltage, reusing.voltage)
    approxStruct(analysis.power.generator, reusing.power.generator)
    approxStruct(analysis.power.injection, reusing.power.injection)
    approxStruct(analysis.power.supply, reusing.power.supply)
    approxStruct(analysis.power.shunt, reusing.power.shunt)
    approxStruct(analysis.power.from, reusing.power.from)
    approxStruct(analysis.power.to, reusing.power.to)
    approxStruct(analysis.power.charging, reusing.power.charging)
    approxStruct(analysis.power.series, reusing.power.series)
end

@testset "DC Optimal Power Flow" begin
    @default(unit)
    @default(template)
    
    ################ Resuing First Pass ################
    system = powerSystem(string(pathData, "case14test.m"))

    updateBus!(system; label = 1, type = 1, active = 0.15, conductance = 0.16, angle = -0.1)
    updateBus!(system; label = 2, type = 3, angle = -0.01)
    addBranch!(system; label = 21, from = 5, to = 7, reactance = 0.25, turnsRatio = 0.98, shiftAngle = -0.1, status = 0)
    addBranch!(system; label = 22, from = 4, to = 5, reactance = 0.25, longTerm = 0.18, maxDiffAngle = 0.15)
    updateBranch!(system; label = 21, status = 1)
    updateBranch!(system; label = 22, status = 0)
    updateBranch!(system; label = 21, reactance = 0.35, maxDiffAngle = 0.22)
    addGenerator!(system; label = 9, bus = 3, active = 0.3, minActive = 0.0, maxActive = 0.5, status = 0)
    cost!(system; label = 9, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    addGenerator!(system; label = 10, bus = 3, active = 0.3)
    cost!(system; label = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1])
    updateGenerator!(system; label = 9, status = 1, maxActive = 0.8)
    updateGenerator!(system; label = 10, status = 0, maxActive = 0.8)
    updateGenerator!(system; label = 9, status = 0)
    cost!(system; label = 5, active = 2, polynomial = [854.0, 116.0])

    dcModel!(system)
    analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)
    solve!(system, analysis)
    power!(system, analysis)
   
    ####### Reuse Model #######
    resystem = powerSystem(string(pathData, "case14test.m"))
    dcModel!(resystem)
    reusing = dcOptimalPowerFlow(resystem, Ipopt.Optimizer)

    updateBus!(resystem, reusing; label = 1, type = 1, active = 0.15, conductance = 0.16, angle = -0.1)
    updateBus!(resystem, reusing; label = 2, type = 3, angle = -0.01)
    addBranch!(resystem, reusing; label = 21, from = 5, to = 7, reactance = 0.25, turnsRatio = 0.98, shiftAngle = -0.1, status = 0)
    addBranch!(resystem, reusing; label = 22, from = 4, to = 5, reactance = 0.25, longTerm = 0.18, maxDiffAngle = 0.15)
    updateBranch!(resystem, reusing; label = 21, status = 1)
    updateBranch!(resystem, reusing; label = 22, status = 0)
    updateBranch!(resystem, reusing; label = 21, reactance = 0.35, maxDiffAngle = 0.22)
    addGenerator!(resystem, reusing; label = 9, bus = 3, active = 0.3, minActive = 0.0, maxActive = 0.5, status = 0)
    cost!(resystem, reusing; label = 9, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    addGenerator!(resystem, reusing; label = 10, bus = 3, active = 0.3)
    cost!(resystem, reusing; label = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1])
    updateGenerator!(resystem, reusing; label = 9, status = 1, maxActive = 0.8)
    updateGenerator!(resystem, reusing; label = 10, status = 0, maxActive = 0.8)
    updateGenerator!(resystem, reusing; label = 9, status = 0)
    cost!(resystem, reusing; label = 5, active = 2, polynomial = [854.0, 116.0])

    solve!(resystem, reusing)
    power!(resystem, reusing)

    ###### Compare Objective, Voltages and Powers #######
    @test JuMP.objective_value(analysis.jump) ≈ JuMP.objective_value(reusing.jump)
    @test analysis.voltage.angle ≈ reusing.voltage.angle
    @test analysis.power.injection.active ≈ reusing.power.injection.active
    @test analysis.power.supply.active ≈ reusing.power.supply.active
    @test analysis.power.from.active ≈ reusing.power.from.active
    @test analysis.power.to.active ≈ reusing.power.to.active
    @test analysis.power.generator.active ≈ reusing.power.generator.active

    ################ Resuing Second Pass ################
    updateBus!(system; label = 1, type = 1, conductance = 0.06, angle = -0.01)
    updateBranch!(system; label = 21, status = 0)
    updateBranch!(system; label = 22, reactance = 0.35, longTerm = 0.22)
    addGenerator!(system; label = 11, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5, status = 0)
    cost!(system; label = 11, active = 2, polynomial = [165.0])
    cost!(system; label = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(system; label = 9, active = 2, polynomial = [856.2; 135.3; 80])

    dcModel!(system)
    analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)
    solve!(system, analysis)
    power!(system, analysis)

    ####### Reuse Model #######
    updateBus!(resystem, reusing; label = 1, type = 1, conductance = 0.06, angle = -0.01)
    updateBranch!(resystem, reusing; label = 21, status = 0)
    updateBranch!(resystem, reusing; label = 22, reactance = 0.35, longTerm = 0.22)
    addGenerator!(resystem, reusing; label = 11, bus = 14, active = 0.3, minActive = 0.0, maxActive = 0.5, status = 0)
    cost!(resystem, reusing; label = 11, active = 2, polynomial = [165.0])
    cost!(resystem, reusing; label = 10, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
    cost!(resystem, reusing; label = 9, active = 2, polynomial = [856.2; 135.3; 80])
    
    solve!(resystem, reusing)
    power!(resystem, reusing)

    ###### Compare Objective, Voltages and Powers #######
    @test JuMP.objective_value(analysis.jump) ≈ JuMP.objective_value(reusing.jump)
    @test analysis.voltage.angle ≈ reusing.voltage.angle
    @test analysis.power.injection.active ≈ reusing.power.injection.active
    @test analysis.power.supply.active ≈ reusing.power.supply.active
    @test analysis.power.from.active ≈ reusing.power.from.active
    @test analysis.power.to.active ≈ reusing.power.to.active
    @test analysis.power.generator.active ≈ reusing.power.generator.active    
end

