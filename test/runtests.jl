using JuliaGrid
using HDF5
using Test

path = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/")

@testset "DC Power Flow" begin
    results = runpf("case14.h5", "dc"; solve = "lu", save = string(path, "save.h5"))
    results = runpf("case14.h5", "dc", "main", "flow", "generator"; save = string(path, "save.xlsx"))

    rm(string(path, "save.h5"))
    rm(string(path, "save.xlsx"))
    @test issubset(["branch", "generator", "bus"], keys(results))
    @test !("save.h5" in cd(readdir, path))
    @test !("save.xlsx" in cd(readdir, path))

    results = runpf("case84.h5", "dc")
    @test issubset(keys(results), ["branch", "bus"])

    accuracy = 1e-12
    matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/dc")
    results = runpf("dc", "case30.h5")
    @test maximum(abs.(results["bus"][:, 2] - matpower["Ti"])) < accuracy
    @test maximum(abs.(results["bus"][:, 3] - matpower["Pinj"])) < accuracy
    @test maximum(abs.(results["branch"][:, 4] - matpower["Pij"])) < accuracy
    @test maximum(abs.(results["generator"][:, 2] - matpower["Pgen"])) < accuracy
end

@testset "Newton-Raphson AC Power Flow" begin
    results = runpf("case14.h5", "nr"; solve = "lu", save = string(path, "save.h5"))
    results = runpf("case14.h5", "nr", "main", "flow", "generator"; save = string(path, "save.xlsx"))
    rm(string(path, "save.h5"))
    rm(string(path, "save.xlsx"))
    @test issubset(["branch", "generator", "bus", "iterations"], keys(results))
    @test !("save.h5" in cd(readdir, path))
    @test !("save.xlsx" in cd(readdir, path))

    results = runpf("case84.h5", "nr")
    @test issubset(keys(results), ["branch", "bus", "iterations"])

    accuracy = 1e-11
    matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/nr")
    results = runpf("nr", "case30.h5")
    @test maximum(abs.(results["bus"][:, 2] - matpower["Vi"])) < accuracy
    @test maximum(abs.(results["bus"][:, 3] - matpower["Ti"])) < accuracy
    @test maximum(abs.(results["bus"][:, 4] - matpower["Pinj"])) < accuracy
    @test maximum(abs.(results["bus"][:, 5] - matpower["Qinj"])) < accuracy
    @test maximum(abs.(results["branch"][:, 4] - matpower["Pij"])) < accuracy
    @test maximum(abs.(results["branch"][:, 5] - matpower["Qij"])) < accuracy
    @test maximum(abs.(results["branch"][:, 6] - matpower["Pji"])) < accuracy
    @test maximum(abs.(results["branch"][:, 7] - matpower["Qji"])) < accuracy
    @test maximum(abs.(results["branch"][:, 8] - matpower["Qbranch"])) < accuracy
    @test maximum(abs.(results["branch"][:, 9] - matpower["Ploss"])) < accuracy
    @test maximum(abs.(results["branch"][:, 10] - matpower["Qloss"])) < accuracy
    @test maximum(abs.(results["generator"][:, 2] - matpower["Pgen"])) < accuracy
    @test maximum(abs.(results["generator"][:, 3] - matpower["Qgen"])) < accuracy
    @test results["iterations"] - matpower["iterations"][1] == 0

    matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/nrLimit")
    results = runpf("nr", "case30.h5"; reactive = 1)
    @test maximum(abs.(results["bus"][:, 2] - matpower["Vi"])) < accuracy
    @test maximum(abs.(results["bus"][:, 3] - matpower["Ti"])) < accuracy
    @test results["iterations"] - matpower["iterations"][1] == 0
end

@testset "Gauss-Seidel AC Power Flow" begin
    accuracy = 1e-11
    matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/gs")
    results = runpf("gs", "case30.h5"; max = 1000)
    @test maximum(abs.(results["bus"][:, 2] - matpower["Vi"])) < accuracy
    @test maximum(abs.(results["bus"][:, 3] - matpower["Ti"])) < accuracy
    @test results["iterations"] - matpower["iterations"][1] == 0

    matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/gsLimit")
    results = runpf("gs", "case30.h5"; max = 1000, reactive = 1)
    @test maximum(abs.(results["bus"][:, 2] - matpower["Vi"])) < accuracy
    @test maximum(abs.(results["bus"][:, 3] - matpower["Ti"])) < accuracy
    @test results["iterations"] - matpower["iterations"][1] == 0
end

@testset "Fast Newton-Raphson (XB) AC Power Flow" begin
    accuracy = 1e-7
    matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/fdxb")
    results = runpf("fnrxb", "case30.h5"; max = 1000)
    @test maximum(abs.(results["bus"][:, 2] - matpower["Vi"])) < accuracy
    @test maximum(abs.(results["bus"][:, 3] - matpower["Ti"])) < accuracy
    @test results["iterations"] - matpower["iterations"][1] == 0

    matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/fdxbLimit")
    results = runpf("fnrxb", "case30.h5"; max = 1000, reactive = 1)
    @test maximum(abs.(results["bus"][:, 2] - matpower["Vi"])) < accuracy
    @test maximum(abs.(results["bus"][:, 3] - matpower["Ti"])) < accuracy
    @test results["iterations"] - matpower["iterations"][1] == 0
end

@testset "Fast Newton-Raphson (BX) AC Power Flow" begin
    accuracy = 1e-7
    matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/fdbx")
    results = runpf("fnrbx", "case30.h5"; max = 1000)
    @test maximum(abs.(results["bus"][:, 2] - matpower["Vi"])) < accuracy
    @test maximum(abs.(results["bus"][:, 3] - matpower["Ti"])) < accuracy
    @test results["iterations"] - matpower["iterations"][1] == 0

    matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/fdbxLimit")
    results = runpf("fnrbx", "case30.h5"; max = 1000, reactive = 1)
    @test maximum(abs.(results["bus"][:, 2] - matpower["Vi"])) < accuracy
    @test maximum(abs.(results["bus"][:, 3] - matpower["Ti"])) < accuracy
    @test results["iterations"] - matpower["iterations"][1] == 0
end

@testset "Measurement Generator Write Read" begin
    results = runmg(string(path, "GeneratorTest_case14.xlsx"); runflow = 0, pmuset = "all", legacyset = "all", save = string(path, "save.h5"))
    results = runmg(string(path, "GeneratorTest_case14.xlsx"); runflow = 0, pmuset = "all", legacyset = "all", save = string(path, "save.xlsx"))
    testkey = ["pmuVoltage", "pmuCurrent", "legacyFlow", "legacyCurrent", "legacyInjection", "legacyVoltage", "bus", "generator", "branch", "basePower", "info"]
    rm(string(path, "save.h5"))
    rm(string(path, "save.xlsx"))
    @test issubset(testkey, keys(results))
    @test !("save.h5" in cd(readdir, path))
    @test !("save.xlsx" in cd(readdir, path))

    results = runmg(string(path, "GeneratorTest_case14incomplete.xlsx"); runflow = 0, pmuset = "all", legacyset = "all")
    testkey = ["legacyCurrent"; "legacyVoltage"; "bus"; "generator"; "branch"; "basePower"; "info"]
    @test issubset(keys(results), testkey)

    results = runmg(string(path, "GeneratorTest_case14inconsistente.xlsx"); runflow = 0, pmuset = "all", legacyset = "all")
    testkey = ["pmuVoltage"; "pmuCurrent"; "legacyFlow"; "legacyInjection"; "legacyVoltage"; "bus"; "generator"; "branch"; "basePower"; "info"]
    @test issubset(keys(results), testkey)
end

@testset "Measurement Generator PMU data" begin
    results = runmg("case14.h5"; runflow = 1, pmuset = "all")
    @test all(results["pmuVoltage"][:, 4] .== 1) &&  all(results["pmuVoltage"][:, 7] .== 1)
    @test all(results["pmuCurrent"][:, 6] .== 1) && all(results["pmuCurrent"][:, 9] .== 1)

    results = runmg("case14.h5"; runflow = 1, pmuset = "optimal")
    @test all(sum(results["pmuVoltage"][:, 4]) .== 5) &&  all(results["pmuVoltage"][:, 4] .== results["pmuVoltage"][:, 7])

    results = runmg("case14.h5"; runflow = 1, pmuset = ["device" 3])
    @test all(sum(results["pmuVoltage"][:, 4]) .== 3) &&  all(results["pmuVoltage"][:, 4] .== results["pmuVoltage"][:, 7])
    results = runmg(string(path, "GeneratorTest_case14inconsistente.xlsx"); runflow = 0, pmuset = ["device" 3])
    @test all(sum(results["pmuVoltage"][:, 4]) .== 3) &&  all(results["pmuVoltage"][:, 4] .== results["pmuVoltage"][:, 7])
    idx = findall(x->x==1, results["pmuVoltage"][:, 4])
    labels = results["pmuVoltage"][idx, 10]
    mustone = true; mustzero = true
    for (k, i) in enumerate(results["pmuCurrent"][:, 6])
        if !any(results["pmuCurrent"][k, 12] .== labels) && i == 1
            mustzero = false
        end
        if any(results["pmuCurrent"][k, 12] .== labels) && i == 0
            mustone = false
        end
    end
    @test mustone && mustzero

    results = runmg("case14.h5"; runflow = 1, pmuset = ["redundancy" 8])
    @test all(results["pmuVoltage"][:, 4] .== 1) &&  all(results["pmuVoltage"][:, 7] .== 1) && all(results["pmuCurrent"][:, 6] .== 1) && all(results["pmuCurrent"][:, 9] .== 1)

    results = runmg("case14.h5"; runflow = 1, pmuset = ["Vi" 0 "Iij" "all" "Dij" 4])
    @test all(results["pmuVoltage"][:, 4] .== 0) &&  all(results["pmuVoltage"][:, 7] .== 0)
    @test all(results["pmuCurrent"][:, 6] .== 1) && sum(results["pmuCurrent"][:, 9]) == 4
    @test all(results["pmuVoltage"][:, 2] .== results["pmuVoltage"][:, 8]) && all(results["pmuVoltage"][:, 5] .== results["pmuVoltage"][:, 9])

    results = runmg("case14.h5"; runflow = 1, pmuvariance = ["all" 1])
    @test all(results["pmuVoltage"][:, 3] .== 1) &&  all(results["pmuVoltage"][:, 6] .== 1) && all(results["pmuCurrent"][:, 5] .== 1) && all(results["pmuCurrent"][:, 8] .== 1)

    results = runmg("case14.h5"; runflow = 1, pmuvariance = ["random" 5 20])
    @test maximum(results["pmuVoltage"][:, 3]) < 20 && minimum(results["pmuVoltage"][:, 3]) > 5 && maximum(results["pmuVoltage"][:, 6]) < 20 && minimum(results["pmuVoltage"][:, 6]) > 5
    @test maximum(results["pmuCurrent"][:, 5]) < 20 && minimum(results["pmuCurrent"][:, 8]) > 5 && maximum(results["pmuCurrent"][:, 5]) < 20 && minimum(results["pmuCurrent"][:, 8]) > 5

    results = runmg("case14.h5"; runflow = 1, pmuvariance = ["Iij" 1 "Vi" 8 "all" 4])
    @test all(results["pmuVoltage"][:, 3] .== 8) && all(results["pmuVoltage"][:, 6] .== 4)
    @test all(results["pmuCurrent"][:, 5] .== 1) && all(results["pmuCurrent"][:, 8] .== 4)

    results = runmg("case14.h5"; runflow = 1, pmuvariance = ["all" 1e-60])
    @test all(results["pmuVoltage"][:, 2] .≈ results["pmuVoltage"][:, 8]) && all(results["pmuVoltage"][2:end, 5] .≈ results["pmuVoltage"][2:end, 9])
    @test all(results["pmuCurrent"][:, 4] .≈ results["pmuCurrent"][:, 10]) && all(results["pmuCurrent"][:, 7] .≈ results["pmuCurrent"][:, 11])
end

@testset "Measurement Generator Legacy data" begin
    results = runmg(string(path, "GeneratorTest_case14inconsistente.xlsx"); runflow = 0, legacyset = ["all"])
    @test all(results["legacyFlow"][:, 6] .== 1) &&  all(results["legacyFlow"][:, 9] .== 1)
    @test all(results["legacyInjection"][:, 4] .== 1) && all(results["legacyInjection"][:, 7] .== 1)
    @test all(results["legacyVoltage"][:, 4] .== 1)

    results = runmg(string(path, "GeneratorTest_case14inconsistente.xlsx"); runflow = 0, legacyset = ["redundancy" 10])
    @test all(results["legacyFlow"][:, 6] .== 1) &&  all(results["legacyFlow"][:, 9] .== 1)
    @test all(results["legacyInjection"][:, 4] .== 1) && all(results["legacyInjection"][:, 7] .== 1)
    @test all(results["legacyVoltage"][:, 4] .== 1)

    results = runmg("case14.h5"; runflow = 1, legacyset = ["Pi" "all" "Vi" 3 "Iij" 8])
    @test all(results["legacyFlow"][:, 6] .== 0) &&  all(results["legacyFlow"][:, 9] .== 0)
    @test all(results["legacyInjection"][:, 4] .== 1) && all(results["legacyInjection"][:, 7] .== 0)
    @test sum(results["legacyVoltage"][:, 4]) == 3

    results = runmg("case14.h5"; runflow = 1, legacyvariance = ["all" 5])
    @test all(results["legacyFlow"][:, 5] .== 5) &&  all(results["legacyFlow"][:, 8] .== 5)
    @test all(results["legacyInjection"][:, 3] .== 5) && all(results["legacyInjection"][:, 6] .== 5)
    @test all(results["legacyVoltage"][:, 3] .== 5)
    @test all(results["legacyCurrent"][:, 5] .== 5)

    results = runmg("case14.h5"; runflow = 1, legacyvariance = ["random" 5 10])
    @test maximum(results["legacyFlow"][:, 5]) < 10 && minimum(results["legacyFlow"][:, 5]) > 5
    @test maximum(results["legacyFlow"][:, 8]) < 10 && minimum(results["legacyFlow"][:, 8]) > 5
    @test maximum(results["legacyVoltage"][:, 3]) < 10 && minimum(results["legacyVoltage"][:, 3]) > 5

    results = runmg("case14.h5"; runflow = 1, legacyvariance = ["Pi" 2 "Vi" 4 "Iij" 6 "all" 10 "Qi" 8])
    @test all(results["legacyFlow"][:, 5] .== 10) &&  all(results["legacyFlow"][:, 8] .== 10)
    @test all(results["legacyInjection"][:, 3] .== 2) && all(results["legacyInjection"][:, 6] .== 8)
    @test all(results["legacyVoltage"][:, 3] .== 4)
    @test all(results["legacyCurrent"][:, 5] .== 6)

    results = runmg("case14.h5"; runflow = 1, legacyvariance = ["all" 1e-60])
    @test all(results["legacyFlow"][:, 4] .≈ results["legacyFlow"][:, 10]) && all(results["legacyFlow"][:, 7] .≈ results["legacyFlow"][:, 11])
    @test all(results["legacyInjection"][:, 2] .≈ results["legacyInjection"][:, 8]) && all(results["legacyInjection"][:, 5] .≈ results["legacyInjection"][:, 9])
    @test all(results["legacyCurrent"][:, 4] .≈ results["legacyCurrent"][:, 7])
    @test all(results["legacyVoltage"][:, 2] .≈ results["legacyVoltage"][:, 5])
end
