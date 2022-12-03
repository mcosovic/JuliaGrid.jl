@testset "shuntBus!" begin
    function systemCompletion(system)
        addGenerator!(system; label = 1, bus = 1, active = 0.4)
        addGenerator!(system; label = 2, bus = 1, active = 1.7, reactive = 0.14)
        addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.00281, reactance = 0.0281, susceptance = 0.00712)
        addBranch!(system; label = 3, from = 1, to = 2, resistance = 0.00064, reactance = 0.0064, susceptance = 0.03126, turnsRatio = 0.96, shiftAngle = -3*(pi/180))
        addBranch!(system; label = 4, from = 2, to = 3, resistance = 0.00108, reactance = 0.0108, susceptance = 0.01852, turnsRatio = 0.98, shiftAngle = 2*(pi/180))
        acModel!(system)

        return system
    end

    function testSet(system, system1)
        @test system.bus.shunt.conductance == system1.bus.shunt.conductance
        @test system.bus.shunt.susceptance == system1.bus.shunt.susceptance
        @test system.acModel.nodalMatrix == system1.acModel.nodalMatrix
    end

    ######## Susceptance Change ##########
    system = powerSystem()
    addBus!(system; label = 1)
    addBus!(system; label = 2, active = 3.0, reactive = 0.9861)
    addBus!(system; label = 3, slackLabel = 3, active = 3.0, reactive = 0.9861, conductance = 0.15, susceptance = -0.04)
    system = systemCompletion(system)
    shuntBus!(system; label = 3, susceptance = 0.08)

    system1 = powerSystem()
    addBus!(system1; label = 1)
    addBus!(system1; label = 2, active = 3.0, reactive = 0.9861)
    addBus!(system1; label = 3, slackLabel = 3, active = 3.0, reactive = 0.9861, conductance = 0.15, susceptance = 0.08)
    system1 = systemCompletion(system1)

    testSet(system, system1)

    ######## Adding New Conductance and Susceptance ##########
    system = powerSystem()
    addBus!(system; label = 1)
    addBus!(system; label = 2, active = 3.0, reactive = 0.9861)
    addBus!(system; label = 3, slackLabel = 3, active = 3.0, reactive = 0.9861, conductance = 0.15, susceptance = -0.04)
    system = systemCompletion(system)
    shuntBus!(system; label = 2, conductance = 0.2, susceptance = 0.08)

    system1 = powerSystem()
    addBus!(system1; label = 1)
    addBus!(system1; label = 2, active = 3.0, reactive = 0.9861, conductance = 0.2, susceptance = 0.08)
    addBus!(system1; label = 3, slackLabel = 3, active = 3.0, reactive = 0.9861, conductance = 0.15, susceptance = -0.04)
    system1 = systemCompletion(system1)

    testSet(system, system1)

    ######## Removal of New Conductance and Susceptance ##########
    shuntBus!(system; label = 2, conductance = 0.0, susceptance = 0.0)

    system1 = powerSystem()
    addBus!(system1; label = 1)
    addBus!(system1; label = 2, active = 3.0, reactive = 0.9861)
    addBus!(system1; label = 3, slackLabel = 3, active = 3.0, reactive = 0.9861, conductance = 0.15, susceptance = -0.04)
    system1 = systemCompletion(system1)

    testSet(system, system1)

    ######## Empty Test ##########
    shuntBus!(system; label = 3)

    testSet(system, system1)
end

@testset "statusBranch!, parameterBranch!" begin
    function systemCreate()
        systemC = powerSystem()
        addBus!(systemC; label = 1)
        addBus!(systemC; label = 2, active = 3.0, reactive = 0.9861)
        addBus!(systemC; label = 3, slackLabel = 3, active = 3.0, reactive = 0.9861, conductance = 0.15, susceptance = -0.04)
        addGenerator!(systemC; label = 1, bus = 1, active = 0.4)
        addGenerator!(systemC; label = 2, bus = 1, active = 1.7, reactive = 0.14)
        addBranch!(systemC; label = 1, from = 1, to = 2, resistance = 0.00281, reactance = 0.0281, susceptance = 0.00712)
        addBranch!(systemC; label = 3, from = 1, to = 2, resistance = 0.00064, reactance = 0.0064, turnsRatio = 0.96, shiftAngle = -0.11)

        return systemC
    end

    function testSet(system, system1)
        @test system.branch.layout.status == system1.branch.layout.status
        @test system.branch.parameter.resistance == system1.branch.parameter.resistance
        @test system.branch.parameter.reactance == system1.branch.parameter.reactance
        @test system.branch.parameter.susceptance == system1.branch.parameter.susceptance
        @test system.branch.parameter.turnsRatio == system1.branch.parameter.turnsRatio
        @test system.branch.parameter.shiftAngle == system1.branch.parameter.shiftAngle
        @test system.dcModel.nodalMatrix == system1.dcModel.nodalMatrix
        @test system.dcModel.admittance == system1.dcModel.admittance
        @test system.dcModel.shiftActivePower == system1.dcModel.shiftActivePower
        @test system.acModel.nodalMatrix ≈ system1.acModel.nodalMatrix
        @test system.acModel.nodalFromFrom == system1.acModel.nodalFromFrom
        @test system.acModel.nodalFromTo == system1.acModel.nodalFromTo
        @test system.acModel.nodalToTo == system1.acModel.nodalToTo
        @test system.acModel.nodalToFrom == system1.acModel.nodalToFrom
        @test system.acModel.admittance == system1.acModel.admittance
        @test system.acModel.transformerRatio == system1.acModel.transformerRatio
    end

    ######## From In-service to Out-of-service ##########
    system = systemCreate()
    addBranch!(system; label = 4, from = 2, to = 3, resistance = 0.00281, reactance = 0.0108, susceptance = 0.01852, turnsRatio = 0.98, shiftAngle = 0.12)
    acModel!(system)
    dcModel!(system)
    statusBranch!(system; label = 4, status = 0)

    system1 = systemCreate()
    addBranch!(system1; label = 4, from = 2, to = 3, status = 0, resistance = 0.00281, reactance = 0.0108, susceptance = 0.01852, turnsRatio = 0.98, shiftAngle = 0.12)
    acModel!(system1)
    dcModel!(system1)

    testSet(system, system1)

    ######## From Out-of-service to In-service ##########
    statusBranch!(system; label = 4, status = 1)

    system1 = systemCreate()
    addBranch!(system1; label = 4, from = 2, to = 3, resistance = 0.00281, reactance = 0.0108, susceptance = 0.01852, turnsRatio = 0.98, shiftAngle = 0.12)
    acModel!(system1)
    dcModel!(system1)

    testSet(system, system1)

    ######## Change Parameters ##########
    system = systemCreate()
    addBranch!(system; label = 4, from = 2, to = 3, resistance = 0.00281, reactance = 0.0108, susceptance = 0.01852, turnsRatio = 0.98, shiftAngle = 0.12)
    acModel!(system)
    dcModel!(system)
    parameterBranch!(system; label = 4, resistance = 0.02, reactance = 0.03, susceptance = 0.014, turnsRatio = 0.096, shiftAngle = -0.14)

    system1 = systemCreate()
    addBranch!(system1; label = 4, from = 2, to = 3, resistance = 0.02, reactance = 0.03, susceptance = 0.014, turnsRatio = 0.096, shiftAngle = -0.14)
    acModel!(system1)
    dcModel!(system1)

    testSet(system, system1)

    ######## Change Subset Parameters ##########
    parameterBranch!(system; label = 4, susceptance = 0.025, turnsRatio = 0.094)

    system1 = systemCreate()
    addBranch!(system1; label = 4, from = 2, to = 3, resistance = 0.02, reactance = 0.03, susceptance = 0.025, turnsRatio = 0.094, shiftAngle = -0.14)
    acModel!(system1)
    dcModel!(system1)

    testSet(system, system1)

    ######## Empty Test ##########
    parameterBranch!(system; label = 4)

    testSet(system, system1)
end

@testset "statusGenerator!, outputGenerator!" begin
    function systemCreate()
        systemC = powerSystem()

        addBus!(systemC; label = 1)
        addBus!(systemC; label = 2, active = 3.0, reactive = 0.9861)
        addBus!(systemC; label = 3, slackLabel = 3, active = 3.0, reactive = 0.9861, conductance = 0.15, susceptance = -0.04)
        addBranch!(systemC; label = 1, from = 1, to = 2, resistance = 0.00281, reactance = 0.0281, susceptance = 0.00712)
        addBranch!(systemC; label = 3, from = 1, to = 2, resistance = 0.00064, reactance = 0.0064, susceptance = 0.03126, turnsRatio = 0.96, shiftAngle = -3*(pi/180))
        addBranch!(systemC; label = 4, from = 2, to = 3, resistance = 0.00108, reactance = 0.0108, susceptance = 0.01852, turnsRatio = 0.98, shiftAngle = 2*(pi/180))
        addGenerator!(systemC; label = 1, bus = 1, active = 0.4)

        return systemC
    end

    function testSet(system, system1)
        @test system.generator.layout.status == system1.generator.layout.status
        @test system.generator.output.active ≈ system1.generator.output.active
        @test system.generator.output.reactive ≈ system1.generator.output.reactive
        @test system.bus.supply.active ≈ system1.bus.supply.active
        @test system.bus.supply.reactive ≈ system1.bus.supply.reactive
        @test system.bus.supply.inService == system1.bus.supply.inService
        @test system.bus.layout.type == system1.bus.layout.type
        @test system.bus.layout.slackIndex == system1.bus.layout.slackIndex
        @test system.bus.layout.slackImmutable == system1.bus.layout.slackImmutable
    end

    ######## From In-service to Out-of-service ##########
    system = systemCreate()
    addGenerator!(system; label = 2, bus = 1, active = 1.7, reactive = 0.14)
    statusGenerator!(system; label = 2, status = 0)

    system1 = systemCreate()
    addGenerator!(system1; label = 2, bus = 1, status = 0, active = 1.7, reactive = 0.14)

    testSet(system, system1)

    ######## From Out-of-service to In-service ##########
    statusGenerator!(system; label = 2, status = 1)

    system1 = systemCreate()
    addGenerator!(system1; label = 2, bus = 1, active = 1.7, reactive = 0.14)

    testSet(system, system1)

    ######## In-service on the Slack Bus ##########
    system = systemCreate()
    addGenerator!(system; label = 2, bus = 3, status = 0, active = 1.7, reactive = 0.14)
    statusGenerator!(system; label = 2, status = 1)

    system1 = systemCreate()
    addGenerator!(system1; label = 2, bus = 3, active = 1.7, reactive = 0.14)

    testSet(system, system1)

    ######## Out-of-service on the Slack Bus ##########
    statusGenerator!(system; label = 2, status = 0)

    system1 = systemCreate()
    addGenerator!(system1; label = 2, status = 0, bus = 3, active = 1.7, reactive = 0.14)

    testSet(system, system1)

    ######## Change Output ##########
    system = systemCreate()
    addGenerator!(system; label = 2, bus = 1, active = 1.7, reactive = 0.14)
    outputGenerator!(system; label = 2, active = 0.7, reactive = 0.15)

    system1 = systemCreate()
    addGenerator!(system1; label = 2, bus = 1, active = 0.7, reactive = 0.15)

    testSet(system, system1)

    ######## Empty Test ##########
    system = systemCreate()
    addGenerator!(system; label = 2, bus = 1, active = 1.7, reactive = 0.14)
    outputGenerator!(system; label = 2)

    system1 = systemCreate()
    addGenerator!(system1; label = 2, bus = 1, active = 1.7, reactive = 0.14)

    testSet(system, system1)
end