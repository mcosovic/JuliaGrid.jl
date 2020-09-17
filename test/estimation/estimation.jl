### State estimation tests
path = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/estimation/")
case14dc = string(path, "case14dc.xlsx")
estimation_incdc = string(path, "estimation_incdc.xlsx")
manousakis2010 = string(path, "manousakis2010.xlsx")
case14seobsbad = string(path, "case14seobsbad.xlsx")

@testset "DC State Estimation" begin
    runse("case14se.xlsx", "dc"; save = string(path, "save.h5"))
    runse("case14se.xlsx", "dc"; save = string(path, "save.xlsx"))
        rm(string(path, "save.h5"))
        rm(string(path, "save.xlsx"))
        @test !("save.h5" in cd(readdir, path))
        @test !("save.xlsx" in cd(readdir, path))

    runse(estimation_incdc, "dc"; save = string(path, "save.h5"))
    runse(estimation_incdc, "dc"; save = string(path, "save.xlsx"))
            rm(string(path, "save.h5"))
            rm(string(path, "save.xlsx"))
            @test !("save.h5" in cd(readdir, path))
            @test !("save.xlsx" in cd(readdir, path))

    runse(estimation_incdc, "dc")
        fieldsres = (:main, :flow, :estimate, :error, :baddata, :observability)
        @test all(fieldsres == fieldnames(JuliaGrid.StateEstimationDC))
    #
    pf, = runpf(case14dc, "dc")
    se, = runse(case14dc, "dc", "main", "flow", "estimate", "error")
        accuracy = 1e-8
        @test maximum(abs.(pf.main[:, 2] - se.main[:, 2])) < accuracy
        @test maximum(abs.(pf.main[:, 3] - se.main[:, 3])) < accuracy
        @test maximum(abs.(pf.flow[:, 4] - se.flow[:, 4])) < accuracy
        @test maximum(abs.(pf.flow[:, 5] - se.flow[:, 5])) < accuracy
        @test se.error[1] < 1e-10
        @test se.error[2] < 1e-10
        @test se.error[3] < 1e-10

    lav, = runse(case14dc, "dc", "lav", "main")
        accuracy = 1e-8
        @test maximum(abs.(pf.main[:, 2] - lav.main[:, 2])) < accuracy

    data = runmg(estimation_incdc; runflow = 0, pmuset = "complete", pmuvariance = ["complete" 1e-30], legacyset = ["Pij" 0])
        results, measurements, = runse(data, "dc", "estimate"; bad = ["pass" 3])
        @test maximum(abs.(results.estimate[:, 8] - results.estimate[:, 10])) < 1e-8
        @test all(measurements.pmuVoltage[:, 7] .== 1)
        @test all(measurements.pmuVoltage[:, 6] .== 1e-30)
        @test all(measurements.pmuVoltage[:, 7] .== 1)
        @test all(measurements.pmuCurrent .== 0)
        @test all(measurements.legacyCurrent .== 0)
        @test all(measurements.legacyInjection .== 0)
        @test all(measurements.legacyVoltage .== 0)

    results, = runse(manousakis2010, "dc", "observe", "estimate")
        islands = [[5; 6; 11; 12; 13], [10], [14], [4; 7; 8; 9], [1], [2; 3]]
        for (k, i) in enumerate(islands)
            for j in results.observability
                if issubset(i, j)
                    islands[k] = []
                end
            end
        end
        idx = findall(x->x==3, results.estimate[:, 2])
        @test all(results.estimate[idx, 4] .== 3) && all(results.estimate[idx, 5] .== [9; 10])

    results, = runse(manousakis2010, "dc", "observe"; observe = ["pivot" 1e-8 "Pij" 1e4])
        idx = findall(x->x==3, results.estimate[:, 2])
        @test all(results.estimate[idx, 4] .== 1) && all(results.estimate[idx, 5] .== [16; 17])

    results, = runse(manousakis2010, "dc", "observe"; observe = ["pivot" 1e-8 "Ti" 1e4])
        idx = findall(x->x==3, results.estimate[:, 2])
        @test all(results.estimate[idx, 4] .== 8) && all(results.estimate[idx, 5] .== [10; 14])

    results, = runse("case14se.xlsx", "dc", "observe", "bad", "main"; observe = ["pivot" 1e-8 "Ti" 1e-4 "Pi" 1e-4], bad = ["pass" 4])
        Ti = results.main[:, 2]
        results, = runse(case14seobsbad, "dc", "observe", "bad", "main"; observe = ["pivot" 1e-8 "Ti" 1e-4 "Pi" 1e-4], bad = ["pass" 2])
        Tinew = results.main[:, 2]
        @test maximum(abs.(Ti - Tinew)) < 1.0

    data = runmg("case_ACTIVSg70k.h5"; legacyset = "complete", legacyvariance = ["Pij" 1e-2 "Pi" 1e-3])
        measure, = data
        measure.legacyInjection[105, 2] = 3000; measure.legacyInjection[105, 4] = 1
        measure.legacyInjection[5, 2] = 1000; measure.legacyInjection[5, 4] = 1
        results, = runse(data, "dc"; bad = ["pass" 2 "treshold" 2])
        @test results.baddata[1, 3] == 3 && results.baddata[1, 4] == 105
        @test results.baddata[2, 3] == 3 && results.baddata[2, 4] == 5
end

@testset "PMU State Estimation" begin
    runse("case14se.xlsx", "pmu"; save = string(path, "save.h5"))
    runse("case14se.xlsx", "pmu"; save = string(path, "save.xlsx"))
        rm(string(path, "save.h5"))
        rm(string(path, "save.xlsx"))
        @test !("save.h5" in cd(readdir, path))
        @test !("save.xlsx" in cd(readdir, path))

    runse("case14se.xlsx", "dc")
        fieldsres = (:main, :flow, :estimate, :error, :baddata, :observability)
        @test all(fieldsres == fieldnames(JuliaGrid.StateEstimationPMU))

    pf, = runpf("case30.h5", "nr")
    data = runmg("case30.h5"; runflow = 1, pmuset = "complete", pmuvariance = ["complete" 1e-120])
    se, = runse(data, "pmu", "main", "flow", "estimate", "error")
            accuracy = 1e-8
            @test maximum(abs.(pf.main[:, 2] - se.main[:, 2])) < accuracy
            @test maximum(abs.(pf.main[:, 3] - se.main[:, 3])) < accuracy
            @test se.error[1] < 1e-10
            @test se.error[2] < 1e-10

    lav, = runse(data, "pmu", "lav")
        accuracy = 1e-8
        @test maximum(abs.(pf.main[:, 2] - lav.main[:, 2])) < accuracy
        @test maximum(abs.(pf.main[:, 3] - lav.main[:, 3])) < accuracy
end
