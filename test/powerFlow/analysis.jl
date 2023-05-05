system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))
topu = 1 / 100

@testset "newtonRaphson, newtonRaphson!" begin
    matpower14 = h5read(string(pathData, "case14testResult.h5"), "/nr")
    matpower30 = h5read(string(pathData, "case30testResult.h5"), "/nr")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    model = newtonRaphson(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, model)
        iteration += 1
    end

    busPower, busCurrent = analysisBus(system14, model)
    branchPower, branchCurrent = analysisBranch(system14, model)
    generatorPower = analysisGenerator(system14, model)

    @test model.voltage.magnitude ≈ matpower14["Vi"]
    @test model.voltage.angle ≈ matpower14["Ti"] * torad
    @test iteration == matpower14["iterations"][1]

    @test busPower.injection.active ≈ matpower14["Pinj"] * topu
    @test busPower.injection.reactive ≈ matpower14["Qinj"] * topu

    @test branchPower.from.active ≈ matpower14["Pij"] * topu
    @test branchPower.from.reactive ≈ matpower14["Qij"] * topu
    @test branchPower.to.active ≈ matpower14["Pji"] * topu
    @test branchPower.to.reactive ≈ matpower14["Qji"] * topu
    @test branchPower.shunt.reactive ≈ matpower14["Qbranch"] * topu
    @test branchPower.loss.active ≈ matpower14["Ploss"] * topu
    @test branchPower.loss.reactive ≈ matpower14["Qloss"] * topu

    @test generatorPower.active ≈ matpower14["Pgen"] * topu
    @test generatorPower.reactive ≈ matpower14["Qgen"] * topu

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    model = newtonRaphson(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, model)
        iteration += 1
    end

    busPower, busCurrent = analysisBus(system30, model)
    branchPower, branchCurrent = analysisBranch(system30, model)
    generatorPower = analysisGenerator(system30, model)

    @test model.voltage.magnitude ≈ matpower30["Vi"]
    @test model.voltage.angle ≈ matpower30["Ti"] * torad
    @test iteration == matpower30["iterations"][1]

    @test busPower.injection.active ≈ matpower30["Pinj"] * topu
    @test busPower.injection.reactive ≈ matpower30["Qinj"] * topu

    @test branchPower.from.active ≈ matpower30["Pij"] * topu
    @test branchPower.from.reactive ≈ matpower30["Qij"] * topu
    @test branchPower.to.active ≈ matpower30["Pji"] * topu
    @test branchPower.to.reactive ≈ matpower30["Qji"] * topu
    @test branchPower.shunt.reactive ≈ matpower30["Qbranch"] * topu
    @test branchPower.loss.active ≈ matpower30["Ploss"] * topu
    @test branchPower.loss.reactive ≈ matpower30["Qloss"] * topu

    @test generatorPower.active ≈ matpower30["Pgen"] * topu
    @test generatorPower.reactive ≈ matpower30["Qgen"] * topu
end

@testset "fastNewtonRaphsonBX, fastNewtonRaphson!" begin
    matpower14 = h5read(string(pathData, "case14testResult.h5"), "/fdbx")
    matpower30 = h5read(string(pathData, "case30testResult.h5"), "/fdbx")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    model = fastNewtonRaphsonBX(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, model)
        iteration += 1
    end

    @test model.voltage.magnitude ≈ matpower14["Vi"]
    @test model.voltage.angle ≈ matpower14["Ti"] * torad
    @test iteration == matpower14["iterations"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    model = fastNewtonRaphsonBX(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, model)
        iteration += 1
    end

    @test model.voltage.magnitude ≈ matpower30["Vi"]
    @test model.voltage.angle ≈ matpower30["Ti"] * torad
    @test iteration == matpower30["iterations"][1]
end

@testset "fastNewtonRaphsonXB, fastNewtonRaphson!" begin
    matpower14 = h5read(string(pathData, "case14testResult.h5"), "/fdxb")
    matpower30 = h5read(string(pathData, "case30testResult.h5"), "/fdxb")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    model = fastNewtonRaphsonXB(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, model)
        iteration += 1
    end

    @test model.voltage.magnitude ≈ matpower14["Vi"]
    @test model.voltage.angle ≈ matpower14["Ti"] * torad
    @test iteration == matpower14["iterations"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    model = fastNewtonRaphsonXB(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, model)
        iteration += 1
    end

    @test model.voltage.magnitude ≈ matpower30["Vi"]
    @test model.voltage.angle ≈ matpower30["Ti"] * torad
    @test iteration == matpower30["iterations"][1]
end

@testset "gaussSeidel, gaussSeidel!" begin
    matpower14 = h5read(string(pathData, "case14testResult.h5"), "/gs")
    matpower30 = h5read(string(pathData, "case30testResult.h5"), "/gs")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    model = gaussSeidel(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, model)
        iteration += 1
    end

    @test model.voltage.magnitude ≈ matpower14["Vi"]
    @test model.voltage.angle ≈ matpower14["Ti"] * torad
    @test iteration == matpower14["iterations"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    model = gaussSeidel(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, model)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, model)
        iteration += 1
    end

    @test model.voltage.magnitude ≈ matpower30["Vi"]
    @test model.voltage.angle ≈ matpower30["Ti"] * torad
    @test iteration == matpower30["iterations"][1]
end

@testset "dcPowerFlow" begin
    matpower14 = h5read(string(pathData, "case14testResult.h5"), "/dc")
    matpower30 = h5read(string(pathData, "case30testResult.h5"), "/dc")

    ######## Modified IEEE 14-bus Test Case ##########
    dcModel!(system14)
    model = dcPowerFlow(system14)
    solve!(system14, model)

    busPower = analysisBus(system14, model)
    branchPower = analysisBranch(system14, model)
    generatorPower = analysisGenerator(system14, model)

    @test model.voltage.angle ≈ matpower14["Ti"] * torad
    @test busPower.injection.active ≈ matpower14["Pinj"] * topu
    @test branchPower.from.active ≈ matpower14["Pij"] * topu
    @test generatorPower.active ≈ matpower14["Pgen"] * topu

    ######## Modified IEEE 30-bus Test Case ##########
    dcModel!(system30)
    model = dcPowerFlow(system30)
    solve!(system30, model)

    busPower = analysisBus(system30, model)
    branchPower = analysisBranch(system30, model)
    generatorPower = analysisGenerator(system30, model)

    @test model.voltage.angle ≈ matpower30["Ti"] * torad
    @test busPower.injection.active ≈ matpower30["Pinj"] * topu
    @test branchPower.from.active ≈ matpower30["Pij"] * topu
    @test generatorPower.active ≈ matpower30["Pgen"] * topu
end