@testset "DC Power Flow: PowerSystem" begin
    ######## DC Power Flow ##########
    system = powerSystem(string(pathData, "case14test.m"))

    changeBus!(system; label = 2, active = 0.2, conductance = 0.1)

    addBranch!(system; from = 2, to = 3, reactance = 0.03, shiftAngle = 0.17)
    changeBranch!(system; label = 1, reactance = 0.2, shiftAngle = -0.12)
    changeBranch!(system; label = 3, status = 0)
    changeBranch!(system; label = 4, status = 1, reactance = 0.2, shiftAngle = -0.12)

    addGenerator!(system; bus = 1, active = 0.8)
    changeGenerator!(system; label = 1, status = 0)
    changeGenerator!(system; label = 2, active = 2.5)
    changeGenerator!(system; label = 3, status = 1, active = 2.5)

    dcModel!(system)
    analysis = dcPowerFlow(system)
    solve!(system, analysis)
    power!(system, analysis)

    ######## DC Power Flow: Resuing ##########
    system = powerSystem(string(pathData, "case14test.m"))
    dcModel!(system)

    changeBus!(system; label = 2, active = 0.2, conductance = 0.1)

    addBranch!(system; from = 2, to = 3, reactance = 0.03, shiftAngle = 0.17)
    changeBranch!(system; label = 1, reactance = 0.2, shiftAngle = -0.12)
    changeBranch!(system; label = 3, status = 0)
    changeBranch!(system; label = 4, status = 0, reactance = 0.2, shiftAngle = -0.12)
    changeBranch!(system; label = 4, status = 1)

    addGenerator!(system; bus = 1, active = 0.8)
    changeGenerator!(system; label = 1, status = 0)
    changeGenerator!(system; label = 2, active = 2.5)
    changeGenerator!(system; label = 3, status = 0, active = 2.5)
    changeGenerator!(system; label = 3, status = 1)

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

    changeBus!(system; label = 2, type = 2, active = 0.15, reactive = 0.21, conductance = 0.18, susceptance = 0.4,
        magnitude = 1.5, angle = 0.17, minMagnitude = 0.9, maxMagnitude = 1.8, base = 100e3, area = 1, lossZone = 1)
    changeBus!(system; label = 3, susceptance = 0.1, conductance = 0.12)

    addBranch!(system; from = 2, to = 3, resistance = 0.2, reactance = 0.03, susceptance = 0.01,
        minDiffAngle = 0.1, maxDiffAngle = 0.5, longTerm = 0.12, shortTerm = 0.15, emergency = 0.14, type = 1)
    changeBranch!(system; label = 17, status = 0)
    changeBranch!(system; label = 1, reactance = 0.2, resistance = 0.2, conductance = 0.01, susceptance = 0.2, turnsRatio = 0.96, shiftAngle = 0.12)

    addGenerator!(system; bus = 2, status = 1, active = 0.1, reactive = 0.2, magnitude = 1.2, 
        minActive = 0.0, maxActive = 0.15, minReactive = 0.0, maxReactive = 0.15,
        lowActive = 0.1, minLowReactive = 0.1, maxLowReactive = 0.1, upActive = 0.1, 
        minUpReactive = 0.1, maxUpReactive = 0.1, loadFollowing = 0.1, 
        reactiveTimescale = 0.1, reserve10min = 0.1, reserve30min = 0.1, area = 0.1)
    changeGenerator!(system; label = 7, status = 0)       
    changeGenerator!(system; label = 3, status = 1, active = 0.5, reactive = 0.8)

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

    changeBus!(system; label = 2, type = 2, active = 0.15, reactive = 0.21, conductance = 0.18, susceptance = 0.4,
        magnitude = 1.5, angle = 0.17, minMagnitude = 0.9, maxMagnitude = 1.8, base = 100e3, area = 1, lossZone = 1)
    changeBus!(system; label = 3, susceptance = 0.1, conductance = 0.12)

    addBranch!(system; from = 2, to = 3, resistance = 0.2, reactance = 0.03, susceptance = 0.01,
        minDiffAngle = 0.1, maxDiffAngle = 0.5, longTerm = 0.12, shortTerm = 0.15, emergency = 0.14, type = 1)
    changeBranch!(system; label = 17, status = 0)
    changeBranch!(system; label = 1, status = 0, reactance = 0.2, resistance = 0.2, conductance = 0.01, susceptance = 0.2, turnsRatio = 0.96, shiftAngle = 0.12)
    changeBranch!(system; label = 1, status = 1)

    addGenerator!(system; bus = 2, status = 1, active = 0.1, reactive = 0.2, magnitude = 1.2, 
        minActive = 0.0, maxActive = 0.15, minReactive = 0.0, maxReactive = 0.15,
        lowActive = 0.1, minLowReactive = 0.1, maxLowReactive = 0.1, upActive = 0.1, 
        minUpReactive = 0.1, maxUpReactive = 0.1, loadFollowing = 0.1, 
        reactiveTimescale = 0.1, reserve10min = 0.1, reserve30min = 0.1, area = 0.1)
    changeGenerator!(system; label = 7, status = 0)    
    changeGenerator!(system; label = 3, status = 1, active = 0.5, reactive = 0.8)

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

    approxStruct(analysis.current.from, analysisReusing.current.from)
    approxStruct(analysis.current.to, analysisReusing.current.to)
    approxStruct(analysis.current.series, analysisReusing.current.series)
end

@testset "DC Power Flow: DCPowerFlow" begin
    ######## DC Power Flow ##########
    system = powerSystem(string(pathData, "case14test.m"))

    changeBus!(system; label = 1, active = 0.15, conductance = 0.16)
    addGenerator!(system; bus = 2, active = 0.8)
    changeGenerator!(system; label = 9, active = 1.2)
    changeGenerator!(system; label = 1, status = 0)
    
    dcModel!(system)
    analysis = dcPowerFlow(system)
    solve!(system, analysis)
    power!(system, analysis)
    
    ######## DC Power Flow: Resuing ##########
    system = powerSystem(string(pathData, "case14test.m"))
    dcModel!(system)
    analysisReusing = dcPowerFlow(system)
    
    changeBus!(system, analysisReusing; label = 1, active = 0.15, conductance = 0.16)
    addGenerator!(system, analysisReusing; bus = 2, active = 0.8)
    changeGenerator!(system, analysisReusing; label = 9, active = 1.2)
    changeGenerator!(system, analysisReusing; label = 1, status = 0)
    changeGenerator!(system, analysisReusing; label = 1, status = 1)
    changeGenerator!(system, analysisReusing; label = 1, status = 0)
    
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

    changeBus!(system; label = 14, active = 0.12, reactive = 0.13, conductance = 0.1, susceptance = 0.15, magnitude = 1.2, angle = -0.17)
    addBranch!(system; from = 2, to = 3, resistance = 0.02, reactance = 0.03, susceptance = 0.01, conductance = 0.0001, turnsRatio = 0.95, shiftAngle = -0.17)
    changeBranch!(system; label = 12, status = 0, resistance = 0.02, reactance = 0.03, susceptance = 0.01)
    changeBranch!(system; label = 12, status = 1)
    addGenerator!(system; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(system; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)
    changeGenerator!(system; label = 4, status = 0)
    changeGenerator!(system; label = 7, active = 0.15, magnitude = 0.92)

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
    systemRe = powerSystem(string(pathData, "case14test.m"))
    acModel!(system)
    analysisReusing = newtonRaphson(systemRe)

    changeBus!(systemRe, analysisReusing; label = 14, active = 0.12, reactive = 0.13, conductance = 0.1, susceptance = 0.15, magnitude = 1.2, angle = -0.17)
    addBranch!(systemRe, analysisReusing; from = 2, to = 3, resistance = 0.02, reactance = 0.03, susceptance = 0.01, conductance = 0.0001, turnsRatio = 0.95, shiftAngle = -0.17)
    changeBranch!(systemRe, analysisReusing; label = 12, status = 0, resistance = 0.02, reactance = 0.03, susceptance = 0.01)
    changeBranch!(systemRe, analysisReusing; label = 12, status = 1)
    addGenerator!(systemRe, analysisReusing; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(systemRe, analysisReusing; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)
    changeGenerator!(systemRe, analysisReusing; label = 4, status = 0)
    changeGenerator!(systemRe, analysisReusing; label = 7, active = 0.15, magnitude = 0.92)

    for iteration = 1:100
        stopping = mismatch!(systemRe, analysisReusing)
        if all(stopping .< 1e-8)
            break
        end
        solve!(systemRe, analysisReusing)
    end
    power!(systemRe, analysisReusing)
    current!(systemRe, analysisReusing)

    approxStruct(analysis.voltage, analysisReusing.voltage)
    approxStruct(analysis.power.injection, analysisReusing.power.injection)
    approxStruct(analysis.power.supply, analysisReusing.power.supply)
    approxStruct(analysis.power.shunt, analysisReusing.power.shunt)
    approxStruct(analysis.power.from, analysisReusing.power.from)
    approxStruct(analysis.power.to, analysisReusing.power.to)
    approxStruct(analysis.power.charging, analysisReusing.power.charging)
    approxStruct(analysis.power.series, analysisReusing.power.series)
    approxStruct(analysis.power.generator, analysisReusing.power.generator)

    approxStruct(analysis.current.from, analysisReusing.current.from)
    approxStruct(analysis.current.to, analysisReusing.current.to)
    approxStruct(analysis.current.series, analysisReusing.current.series)
end

@testset "AC Power Flow: GaussSeidel" begin
    ####### AC Power Flow ##########
    system = powerSystem(string(pathData, "case14test.m"))

    changeBus!(system; label = 14, active = 0.12, reactive = 0.13, conductance = 0.1, susceptance = 0.15, magnitude = 1.2, angle = -0.17)
    addBranch!(system; from = 2, to = 3, resistance = 0.02, reactance = 0.03, susceptance = 0.01, conductance = 0.0001, turnsRatio = 0.95, shiftAngle = -0.17)
    changeBranch!(system; label = 12, status = 0, resistance = 0.02, reactance = 0.03, susceptance = 0.01)
    changeBranch!(system; label = 12, status = 1)
    addGenerator!(system; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(system; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)
    changeGenerator!(system; label = 4, status = 0)
    changeGenerator!(system; label = 7, active = 0.15, magnitude = 0.92)

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
    systemRe = powerSystem(string(pathData, "case14test.m"))
    acModel!(system)
    analysisReusing = gaussSeidel(systemRe)

    changeBus!(systemRe, analysisReusing; label = 14, active = 0.12, reactive = 0.13, conductance = 0.1, susceptance = 0.15, magnitude = 1.2, angle = -0.17)
    addBranch!(systemRe, analysisReusing; from = 2, to = 3, resistance = 0.02, reactance = 0.03, susceptance = 0.01, conductance = 0.0001, turnsRatio = 0.95, shiftAngle = -0.17)
    changeBranch!(systemRe, analysisReusing; label = 12, status = 0, resistance = 0.02, reactance = 0.03, susceptance = 0.01)
    changeBranch!(systemRe, analysisReusing; label = 12, status = 1)
    addGenerator!(systemRe, analysisReusing; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    addGenerator!(systemRe, analysisReusing; bus = 4, active = 0.8, reactive = 0.2, magnitude = 0.9)
    changeGenerator!(systemRe, analysisReusing; label = 4, status = 0)
    changeGenerator!(systemRe, analysisReusing; label = 7, active = 0.15, magnitude = 0.92)

    for iteration = 1:1000
        stopping = mismatch!(systemRe, analysisReusing)
        if all(stopping .< 1e-8)
            break
        end
        solve!(systemRe, analysisReusing)
    end
    power!(systemRe, analysisReusing)
    current!(systemRe, analysisReusing)

    approxStruct(analysis.voltage, analysisReusing.voltage)
    approxStruct(analysis.power.injection, analysisReusing.power.injection)
    approxStruct(analysis.power.supply, analysisReusing.power.supply)
    approxStruct(analysis.power.shunt, analysisReusing.power.shunt)
    approxStruct(analysis.power.from, analysisReusing.power.from)
    approxStruct(analysis.power.to, analysisReusing.power.to)
    approxStruct(analysis.power.charging, analysisReusing.power.charging)
    approxStruct(analysis.power.series, analysisReusing.power.series)
    approxStruct(analysis.power.generator, analysisReusing.power.generator)

    approxStruct(analysis.current.from, analysisReusing.current.from)
    approxStruct(analysis.current.to, analysisReusing.current.to)
    approxStruct(analysis.current.series, analysisReusing.current.series)
end

@testset "AC Power Flow: FastNewtonRaphson" begin
    ####### AC Power Flow ##########
    system = powerSystem(string(pathData, "case14test.m"))

    changeBus!(system; label = 2, active = 0.2, reactive = 0.2)
    addGenerator!(system; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    changeGenerator!(system; label = 6, status = 0)
    changeGenerator!(system; label = 2, active = 2.5, reactive = 1.2)

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

    changeBus!(system, analysisReusing; label = 2, active = 0.2, reactive = 0.2)
    addGenerator!(system, analysisReusing; bus = 16, active = 0.8, reactive = 0.2, magnitude = 0.95)
    changeGenerator!(system, analysisReusing; label = 6, status = 0)
    changeGenerator!(system, analysisReusing; label = 2, active = 2.5, reactive = 1.2)

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