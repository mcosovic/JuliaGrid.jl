system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))
topu = 1 / 100

@testset "newtonRaphson, newtonRaphson!" begin
    matpower14 = h5read(string(pathData, "case14testResult.h5"), "/nr")
    matpower30 = h5read(string(pathData, "case30testResult.h5"), "/nr")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    analysis = newtonRaphson(system14)

    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, analysis)
        iteration += 1
    end

    bus!(system14, analysis)
    branch!(system14, analysis)
    generator!(system14, analysis)

    @test analysis.bus.voltage.magnitude ≈ matpower14["Vi"]
    @test analysis.bus.voltage.angle ≈ matpower14["Ti"] * torad
    @test iteration == matpower14["iterations"][1]

    @test analysis.bus.power.injection.active ≈ matpower14["Pinj"] * topu
    @test analysis.bus.power.injection.reactive ≈ matpower14["Qinj"] * topu

    @test analysis.branch.power.from.active ≈ matpower14["Pij"] * topu
    @test analysis.branch.power.from.reactive ≈ matpower14["Qij"] * topu
    @test analysis.branch.power.to.active ≈ matpower14["Pji"] * topu
    @test analysis.branch.power.to.reactive ≈ matpower14["Qji"] * topu
    @test analysis.branch.power.shunt.reactive ≈ matpower14["Qbranch"] * topu
    @test analysis.branch.power.loss.active ≈ matpower14["Ploss"] * topu
    @test analysis.branch.power.loss.reactive ≈ matpower14["Qloss"] * topu

    @test analysis.generator.power.active ≈ matpower14["Pgen"] * topu
    @test analysis.generator.power.reactive ≈ matpower14["Qgen"] * topu

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    analysis = newtonRaphson(system30)

    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
        iteration += 1
    end

    bus!(system30, analysis)
    branch!(system30, analysis)
    generator!(system30, analysis)

    @test analysis.bus.voltage.magnitude ≈ matpower30["Vi"]
    @test analysis.bus.voltage.angle ≈ matpower30["Ti"] * torad
    @test iteration == matpower30["iterations"][1]

    @test analysis.bus.power.injection.active ≈ matpower30["Pinj"] * topu
    @test analysis.bus.power.injection.reactive ≈ matpower30["Qinj"] * topu

    @test analysis.branch.power.from.active ≈ matpower30["Pij"] * topu
    @test analysis.branch.power.from.reactive ≈ matpower30["Qij"] * topu
    @test analysis.branch.power.to.active ≈ matpower30["Pji"] * topu
    @test analysis.branch.power.to.reactive ≈ matpower30["Qji"] * topu
    @test analysis.branch.power.shunt.reactive ≈ matpower30["Qbranch"] * topu
    @test analysis.branch.power.loss.active ≈ matpower30["Ploss"] * topu
    @test analysis.branch.power.loss.reactive ≈ matpower30["Qloss"] * topu

    @test analysis.generator.power.active ≈ matpower30["Pgen"] * topu
    @test analysis.generator.power.reactive ≈ matpower30["Qgen"] * topu
end

@testset "fastNewtonRaphsonBX, fastNewtonRaphson!" begin
    matpower14 = h5read(string(pathData, "case14testResult.h5"), "/fdbx")
    matpower30 = h5read(string(pathData, "case30testResult.h5"), "/fdbx")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    analysis = fastNewtonRaphsonBX(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, analysis)
        iteration += 1
    end

    @test analysis.bus.voltage.magnitude ≈ matpower14["Vi"]
    @test analysis.bus.voltage.angle ≈ matpower14["Ti"] * torad
    @test iteration == matpower14["iterations"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    analysis = fastNewtonRaphsonBX(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
        iteration += 1
    end

    @test analysis.bus.voltage.magnitude ≈ matpower30["Vi"]
    @test analysis.bus.voltage.angle ≈ matpower30["Ti"] * torad
    @test iteration == matpower30["iterations"][1]
end

@testset "fastNewtonRaphsonXB, fastNewtonRaphson!" begin
    matpower14 = h5read(string(pathData, "case14testResult.h5"), "/fdxb")
    matpower30 = h5read(string(pathData, "case30testResult.h5"), "/fdxb")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    analysis = fastNewtonRaphsonXB(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, analysis)
        iteration += 1
    end

    @test analysis.bus.voltage.magnitude ≈ matpower14["Vi"]
    @test analysis.bus.voltage.angle ≈ matpower14["Ti"] * torad
    @test iteration == matpower14["iterations"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    analysis = fastNewtonRaphsonXB(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
        iteration += 1
    end

    @test analysis.bus.voltage.magnitude ≈ matpower30["Vi"]
    @test analysis.bus.voltage.angle ≈ matpower30["Ti"] * torad
    @test iteration == matpower30["iterations"][1]
end

@testset "gaussSeidel, gaussSeidel!" begin
    matpower14 = h5read(string(pathData, "case14testResult.h5"), "/gs")
    matpower30 = h5read(string(pathData, "case30testResult.h5"), "/gs")

    ######## Modified IEEE 14-bus Test Case ##########
    acModel!(system14)
    analysis = gaussSeidel(system14)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system14, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, analysis)
        iteration += 1
    end

    @test analysis.bus.voltage.magnitude ≈ matpower14["Vi"]
    @test analysis.bus.voltage.angle ≈ matpower14["Ti"] * torad
    @test iteration == matpower14["iterations"][1]

    ######## Modified IEEE 30-bus Test Case ##########
    acModel!(system30)
    analysis = gaussSeidel(system30)
    iteration = 0
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
        iteration += 1
    end

    @test analysis.bus.voltage.magnitude ≈ matpower30["Vi"]
    @test analysis.bus.voltage.angle ≈ matpower30["Ti"] * torad
    @test iteration == matpower30["iterations"][1]
end

@testset "dcPowerFlow" begin
    matpower14 = h5read(string(pathData, "case14testResult.h5"), "/dc")
    matpower30 = h5read(string(pathData, "case30testResult.h5"), "/dc")

    ######## Modified IEEE 14-bus Test Case ##########
    dcModel!(system14)
    analysis = dcPowerFlow(system14)
    solve!(system14, analysis)

    bus!(system14, analysis)
    branch!(system14, analysis)
    generator!(system14, analysis)

    @test analysis.bus.voltage.angle ≈ matpower14["Ti"] * torad
    @test analysis.bus.power.injection.active ≈ matpower14["Pinj"] * topu
    @test analysis.branch.power.from.active ≈ matpower14["Pij"] * topu
    @test analysis.generator.power.active ≈ matpower14["Pgen"] * topu


    ######## Modified IEEE 30-bus Test Case ##########
    dcModel!(system30)
    analysis = dcPowerFlow(system30)
    solve!(system30, analysis)

    bus!(system30, analysis)
    branch!(system30, analysis)
    generator!(system30, analysis)

    @test analysis.bus.voltage.angle ≈ matpower30["Ti"] * torad
    @test analysis.bus.power.injection.active ≈ matpower30["Pinj"] * topu
    @test analysis.branch.power.from.active ≈ matpower30["Pij"] * topu
    @test analysis.generator.power.active ≈ matpower30["Pgen"] * topu
end