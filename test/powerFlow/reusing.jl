@testset "DC Power Flow: PowerSystem" begin
    ######## DC Power Flow ##########
    system = powerSystem(string(pathData, "case14test.m"))

    demandBus!(system; label = 2, active = 0.2)
    shuntBus!(system; label = 3, conductance = 0.1)
    addBranch!(system; from = 2, to = 3, reactance = 0.03, shiftAngle = 0.17)
    statusBranch!(system; label = 3, status = 0)
    parameterBranch!(system; label = 1, reactance = 0.2, shiftAngle = -0.12)
    addGenerator!(system; bus = 1, active = 0.8)
    statusGenerator!(system; label = 1, status = 0)
    outputGenerator!(system; label = 2, active = 2.5)

    dcModel!(system)
    analysis = dcPowerFlow(system)
    solve!(system, analysis)
    power!(system, analysis)

    ######## DC Power Flow: Resuing ##########
    system = powerSystem(string(pathData, "case14test.m"))
    dcModel!(system)

    demandBus!(system; label = 2, active = 0.2)
    shuntBus!(system; label = 3, conductance = 0.1)
    addBranch!(system; from = 2, to = 3, reactance = 0.03, shiftAngle = 0.17)
    statusBranch!(system; label = 3, status = 0)
    parameterBranch!(system; label = 1, reactance = 0.2, shiftAngle = -0.12)
    addGenerator!(system; bus = 1, active = 0.8)
    statusGenerator!(system; label = 1, status = 0)
    outputGenerator!(system; label = 2, active = 2.5)

    analysisReusing = dcPowerFlow(system)
    solve!(system, analysisReusing)
    power!(system, analysisReusing)

    @test analysis.voltage.angle ≈ analysisReusing.voltage.angle
    @test analysis.power.injection.active ≈ analysisReusing.power.injection.active
    @test analysis.power.supply.active ≈ analysisReusing.power.supply.active
    @test analysis.power.from.active ≈ analysisReusing.power.from.active
    @test analysis.power.to.active ≈ analysisReusing.power.to.active
    @test analysis.power.generator.active ≈ analysisReusing.power.generator.active
end

@testset "AC Power Flow: PowerSystem" begin
    ####### AC Power Flow ##########
    system = powerSystem(string(pathData, "case14test.m"))

    demandBus!(system; label = 2, active = 0.2, reactive = 0.2)
    shuntBus!(system; label = 3, conductance = 0.1, susceptance = 0.2)
    addBranch!(system; from = 2, to = 3, resistance = 0.2, reactance = 0.03, susceptance = 0.01)
    statusBranch!(system; label = 3, status = 0)
    parameterBranch!(system; label = 1, reactance = 0.2, turnsRatio = 0.96, shiftAngle = 0.12)
    addGenerator!(system; bus = 1, active = 0.8, reactive = 0.2)
    statusGenerator!(system; label = 1, status = 0)
    outputGenerator!(system; label = 2, active = 2.5, reactive = 1.2)

    acModel!(system)
    analysis = newtonRaphson(system)
    for iteration = 1:100
        stopping = mismatch!(system, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system, analysis)
    end
    power!(system, analysis)
    current!(system, analysis)

    ######## AC Power Flow: Resuing ##########
    system = powerSystem(string(pathData, "case14test.m"))
    acModel!(system)

    demandBus!(system; label = 2, active = 0.2, reactive = 0.2)
    shuntBus!(system; label = 3, conductance = 0.1, susceptance = 0.2)
    addBranch!(system; from = 2, to = 3, resistance = 0.2, reactance = 0.03, susceptance = 0.01)
    statusBranch!(system; label = 3, status = 0)
    parameterBranch!(system; label = 1, reactance = 0.2, turnsRatio = 0.96, shiftAngle = 0.12)
    addGenerator!(system; bus = 1, active = 0.8, reactive = 0.2)
    statusGenerator!(system; label = 1, status = 0)
    outputGenerator!(system; label = 2, active = 2.5, reactive = 1.2)

    analysisReusing = newtonRaphson(system)
    for iteration = 1:100
        stopping = mismatch!(system, analysisReusing)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system, analysisReusing)
    end
    power!(system, analysisReusing)
    current!(system, analysisReusing)

    approxStruct(analysis.voltage, analysisReusing.voltage)
    approxStruct(analysis.power.injection, analysisReusing.power.injection)
    approxStruct(analysis.power.supply, analysisReusing.power.supply)
    approxStruct(analysis.power.shunt, analysisReusing.power.shunt)
    approxStruct(analysis.power.from, analysisReusing.power.from)
    approxStruct(analysis.power.to, analysisReusing.power.to)
    approxStruct(analysis.power.charging, analysisReusing.power.charging)
    approxStruct(analysis.power.series, analysisReusing.power.series)
    approxStruct(analysis.power.generator, analysisReusing.power.generator)

    approxStruct(analysis.current.injection, analysisReusing.current.injection)
    approxStruct(analysis.current.from, analysisReusing.current.from)
    approxStruct(analysis.current.to, analysisReusing.current.to)
    approxStruct(analysis.current.series, analysisReusing.current.series)
end

@testset "DC Power Flow: DCPowerFlow" begin
    ######## DC Power Flow ##########
    system = powerSystem(string(pathData, "case14test.m"))

    demandBus!(system; label = 2, active = 0.2)
    shuntBus!(system; label = 3, conductance = 0.1)
    addGenerator!(system; bus = 1, active = 0.8)
    statusGenerator!(system; label = 1, status = 0)
    outputGenerator!(system; label = 2, active = 2.5)

    dcModel!(system)
    analysis = dcPowerFlow(system)
    solve!(system, analysis)
    power!(system, analysis)

    ######## DC Power Flow: Resuing ##########
    system = powerSystem(string(pathData, "case14test.m"))
    dcModel!(system)
    analysisReusing = dcPowerFlow(system)

    demandBus!(system, analysisReusing; label = 2, active = 0.2)
    shuntBus!(system, analysisReusing; label = 3, conductance = 0.1)
    addGenerator!(system, analysisReusing; bus = 1, active = 0.8)
    statusGenerator!(system, analysisReusing; label = 1, status = 0)
    outputGenerator!(system, analysisReusing; label = 2, active = 2.5)

    solve!(system, analysisReusing)
    power!(system, analysisReusing)

    @test analysis.voltage.angle ≈ analysisReusing.voltage.angle
    @test analysis.power.injection.active ≈ analysisReusing.power.injection.active
    @test analysis.power.supply.active ≈ analysisReusing.power.supply.active
    @test analysis.power.from.active ≈ analysisReusing.power.from.active
    @test analysis.power.to.active ≈ analysisReusing.power.to.active
    @test analysis.power.generator.active ≈ analysisReusing.power.generator.active
end

@testset "AC Power Flow: NewtonRaphson" begin
    ####### AC Power Flow ##########
    system = powerSystem(string(pathData, "case14test.m"))

    demandBus!(system; label = 2, active = 0.2, reactive = 0.2)
    shuntBus!(system; label = 3, conductance = 0.1, susceptance = 0.2)
    addBranch!(system; from = 2, to = 3, resistance = 0.2, reactance = 0.03, susceptance = 0.01)
    statusBranch!(system; label = 3, status = 0)
    parameterBranch!(system; label = 1, reactance = 0.2, turnsRatio = 0.96, shiftAngle = 0.12)
    addGenerator!(system; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    statusGenerator!(system; label = 6, status = 0)
    outputGenerator!(system; label = 2, active = 2.5, reactive = 1.2)

    acModel!(system)
    analysis = newtonRaphson(system)
    for iteration = 1:100
        stopping = mismatch!(system, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system, analysis)
    end
    power!(system, analysis)
    current!(system, analysis)

    ######## AC Power Flow: Resuing ##########
    system = powerSystem(string(pathData, "case14test.m"))
    acModel!(system)
    analysisReusing = newtonRaphson(system)

    demandBus!(system, analysisReusing; label = 2, active = 0.2, reactive = 0.2)
    shuntBus!(system, analysisReusing; label = 3, conductance = 0.1, susceptance = 0.2)
    addBranch!(system, analysisReusing; from = 2, to = 3, resistance = 0.2, reactance = 0.03, susceptance = 0.01)
    statusBranch!(system, analysisReusing; label = 3, status = 0)
    parameterBranch!(system, analysisReusing; label = 1, reactance = 0.2, turnsRatio = 0.96, shiftAngle = 0.12)
    addGenerator!(system, analysisReusing; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    statusGenerator!(system, analysisReusing; label = 6, status = 0)
    outputGenerator!(system, analysisReusing; label = 2, active = 2.5, reactive = 1.2)

    for iteration = 1:100
        stopping = mismatch!(system, analysisReusing)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system, analysisReusing)
    end
    power!(system, analysisReusing)
    current!(system, analysisReusing)

    approxStruct(analysis.voltage, analysisReusing.voltage)
    approxStruct(analysis.power.injection, analysisReusing.power.injection)
    approxStruct(analysis.power.supply, analysisReusing.power.supply)
    approxStruct(analysis.power.shunt, analysisReusing.power.shunt)
    approxStruct(analysis.power.from, analysisReusing.power.from)
    approxStruct(analysis.power.to, analysisReusing.power.to)
    approxStruct(analysis.power.charging, analysisReusing.power.charging)
    approxStruct(analysis.power.series, analysisReusing.power.series)
    approxStruct(analysis.power.generator, analysisReusing.power.generator)

    approxStruct(analysis.current.injection, analysisReusing.current.injection)
    approxStruct(analysis.current.from, analysisReusing.current.from)
    approxStruct(analysis.current.to, analysisReusing.current.to)
    approxStruct(analysis.current.series, analysisReusing.current.series)
end

@testset "AC Power Flow: GaussSeidel" begin
    ####### AC Power Flow ##########
    system = powerSystem(string(pathData, "case14test.m"))

    demandBus!(system; label = 2, active = 0.2, reactive = 0.2)
    shuntBus!(system; label = 3, conductance = 0.1, susceptance = 0.2)
    addBranch!(system; from = 2, to = 3, resistance = 0.2, reactance = 0.03, susceptance = 0.01)
    statusBranch!(system; label = 3, status = 0)
    parameterBranch!(system; label = 1, reactance = 0.2, turnsRatio = 0.96, shiftAngle = 0.12)
    addGenerator!(system; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    statusGenerator!(system; label = 6, status = 0)
    outputGenerator!(system; label = 2, active = 2.5, reactive = 1.2)

    acModel!(system)
    analysis = gaussSeidel(system)
    for iteration = 1:1000
        stopping = mismatch!(system, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system, analysis)
    end
    power!(system, analysis)
    current!(system, analysis)

    ######## AC Power Flow: Resuing ##########
    system = powerSystem(string(pathData, "case14test.m"))
    acModel!(system)
    analysisReusing = gaussSeidel(system)

    demandBus!(system, analysisReusing; label = 2, active = 0.2, reactive = 0.2)
    shuntBus!(system, analysisReusing; label = 3, conductance = 0.1, susceptance = 0.2)
    addBranch!(system, analysisReusing; from = 2, to = 3, resistance = 0.2, reactance = 0.03, susceptance = 0.01)
    statusBranch!(system, analysisReusing; label = 3, status = 0)
    parameterBranch!(system, analysisReusing; label = 1, reactance = 0.2, turnsRatio = 0.96, shiftAngle = 0.12)
    addGenerator!(system, analysisReusing; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    statusGenerator!(system, analysisReusing; label = 6, status = 0)
    outputGenerator!(system, analysisReusing; label = 2, active = 2.5, reactive = 1.2)

    for iteration = 1:1000
        stopping = mismatch!(system, analysisReusing)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system, analysisReusing)
    end
    power!(system, analysisReusing)
    current!(system, analysisReusing)

    approxStruct(analysis.voltage, analysisReusing.voltage)
    approxStruct(analysis.power.injection, analysisReusing.power.injection)
    approxStruct(analysis.power.supply, analysisReusing.power.supply)
    approxStruct(analysis.power.shunt, analysisReusing.power.shunt)
    approxStruct(analysis.power.from, analysisReusing.power.from)
    approxStruct(analysis.power.to, analysisReusing.power.to)
    approxStruct(analysis.power.charging, analysisReusing.power.charging)
    approxStruct(analysis.power.series, analysisReusing.power.series)
    approxStruct(analysis.power.generator, analysisReusing.power.generator)

    approxStruct(analysis.current.injection, analysisReusing.current.injection, 1e-6)
    approxStruct(analysis.current.from, analysisReusing.current.from)
    approxStruct(analysis.current.to, analysisReusing.current.to)
    approxStruct(analysis.current.series, analysisReusing.current.series)
end

@testset "AC Power Flow: FastNewtonRaphson" begin
    ####### AC Power Flow ##########
    system = powerSystem(string(pathData, "case14test.m"))

    demandBus!(system; label = 2, active = 0.2, reactive = 0.2)
    addGenerator!(system; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    statusGenerator!(system; label = 6, status = 0)
    outputGenerator!(system; label = 2, active = 2.5, reactive = 1.2)

    acModel!(system)
    analysis = fastNewtonRaphsonBX(system)
    for iteration = 1:1000
        stopping = mismatch!(system, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system, analysis)
    end
    power!(system, analysis)
    current!(system, analysis)

    ######## AC Power Flow: Resuing ##########
    system = powerSystem(string(pathData, "case14test.m"))
    acModel!(system)
    analysisReusing = fastNewtonRaphsonBX(system)

    demandBus!(system, analysisReusing; label = 2, active = 0.2, reactive = 0.2)
    addGenerator!(system, analysisReusing; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    statusGenerator!(system, analysisReusing; label = 6, status = 0)
    outputGenerator!(system, analysisReusing; label = 2, active = 2.5, reactive = 1.2)

    for iteration = 1:1000
        stopping = mismatch!(system, analysisReusing)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system, analysisReusing)
    end
    power!(system, analysisReusing)
    current!(system, analysisReusing)

    approxStruct(analysis.voltage, analysisReusing.voltage)
    approxStruct(analysis.power.injection, analysisReusing.power.injection)
    approxStruct(analysis.power.supply, analysisReusing.power.supply)
    approxStruct(analysis.power.shunt, analysisReusing.power.shunt)
    approxStruct(analysis.power.from, analysisReusing.power.from)
    approxStruct(analysis.power.to, analysisReusing.power.to)
    approxStruct(analysis.power.charging, analysisReusing.power.charging)
    approxStruct(analysis.power.series, analysisReusing.power.series)
    approxStruct(analysis.power.generator, analysisReusing.power.generator)

    approxStruct(analysis.current.injection, analysisReusing.current.injection)
    approxStruct(analysis.current.from, analysisReusing.current.from)
    approxStruct(analysis.current.to, analysisReusing.current.to)
    approxStruct(analysis.current.series, analysisReusing.current.series)
end