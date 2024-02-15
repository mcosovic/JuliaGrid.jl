system14 = powerSystem(string(pathData, "case14test.m"))
system30 = powerSystem(string(pathData, "case30test.m"))

@testset "Optimal PMU Placement" begin
    @default(template)
    @default(unit)

    ################ Modified IEEE 14-bus Test Case ################
    placement = pmuPlacment(system14, GLPK.Optimizer)
    @test collect(keys(placement.bus)) == ["1"; "4"; "16"; "7"; "9"]
    @test collect(keys(placement.from)) == ["1"; "2"; "7"; "8"; "9"; "11"; "12"; "13"; "14"; "15"; "16"; "17"]
    @test collect(keys(placement.to)) == ["4"; "6"; "10"; "8"; "9"; "15"]

    ############### Modified IEEE 14-bus Test Case ################
    updateBus!(system14; label = 1, type = 2)
    updateBus!(system14; label = 3, type = 3, angle = -0.17)
    updateBranch!(system14; label = 3, conductance = 0.01)
    updateBranch!(system14; label = 6, conductance = 0.05)
    updateBranch!(system14; label = 17, status = 0)

    acModel!(system14)
    analysis = newtonRaphson(system14)
    for i = 1:1000
        stopping = mismatch!(system14, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system14, analysis)
    end
    current!(system14, analysis)

    placement = pmuPlacment(system14, GLPK.Optimizer)
    device = measurement()
    for (key, value) in placement.bus
        addPmu!(system14, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], noise = false)
    end
    for (key, value) in placement.from
        addPmu!(system14, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], noise = false)
    end
    for (key, value) in placement.to
        addPmu!(system14, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], noise = false) 
    end

    ####### LU Factorization #######
    analysisLU = pmuStateEstimation(system14, device, LU)
    solve!(system14, analysisLU)
    @test analysisLU.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisLU.voltage.angle ≈ analysis.voltage.angle

    ################ Modified IEEE 30-bus Test Case ################
    acModel!(system30)
    analysis = newtonRaphson(system30)
    for i = 1:1000
        stopping = mismatch!(system30, analysis)
        if all(stopping .< 1e-8)
            break
        end
        solve!(system30, analysis)
    end
    current!(system30, analysis)

    placement = pmuPlacment(system30, GLPK.Optimizer)
    device = measurement()
    for (key, value) in placement.bus
        addPmu!(system30, device; bus = key, magnitude = analysis.voltage.magnitude[value], angle = analysis.voltage.angle[value], noise = false)
    end
    for (key, value) in placement.from
        addPmu!(system30, device; from = key, magnitude = analysis.current.from.magnitude[value], angle = analysis.current.from.angle[value], noise = false)
    end
    for (key, value) in placement.to
        addPmu!(system30, device; to = key, magnitude = analysis.current.to.magnitude[value], angle = analysis.current.to.angle[value], noise = false) 
    end

    ####### LU Factorization #######
    analysisLU = pmuStateEstimation(system30, device, LU)
    solve!(system30, analysisLU)
    @test analysisLU.voltage.magnitude ≈ analysis.voltage.magnitude
    @test analysisLU.voltage.angle ≈ analysis.voltage.angle
end