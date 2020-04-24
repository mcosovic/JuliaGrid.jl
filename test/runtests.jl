using JuliaGrid
using HDF5
using Test
using Suppressor

path = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/")

@testset "DC Power Flow" begin
    @suppress begin
        results = runpf("case14.h5", "dc"; solve = "lu", save = string(path, "save.h5"))
        results = runpf("case14.h5", "dc"; save = string(path, "save.xlsx"))

        rm(string(path, "save.h5"))
        rm(string(path, "save.xlsx"))
        @test all(in(keys(results)).(["branch", "generator", "bus"]))
        @test !any(cd(readdir, path) .== "save.h5")
        @test !any(cd(readdir, path) .== "save.xlsx")

        results = runpf("case84.h5", "dc")
        @test all(in(keys(results)).(["branch", "bus"]))

        accuracy = 1e-12
        matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/dc")
        results = runpf("dc", "case30.h5")
        @test maximum(abs.(results["bus"][:, 2] - matpower["Ti"])) < accuracy
        @test maximum(abs.(results["bus"][:, 3] - matpower["Pinj"])) < accuracy
        @test maximum(abs.(results["branch"][:, 4] - matpower["Pij"])) < accuracy
        @test maximum(abs.(results["generator"][:, 2] - matpower["Pgen"])) < accuracy
    end
end

@testset "Newton-Raphson AC Power Flow" begin
    @suppress begin
        results = runpf("case14.h5", "nr"; solve = "lu", save = string(path, "save.h5"))
        results = runpf("case14.h5", "nr"; save = string(path, "save.xlsx"))
        rm(string(path, "save.h5"))
        rm(string(path, "save.xlsx"))
        @test all(in(keys(results)).(["branch", "generator", "bus", "iterations"]))
        @test !any(cd(readdir, path) .== "save.h5")
        @test !any(cd(readdir, path) .== "save.xlsx")

        results = runpf("case84.h5", "nr")
        @test all(in(keys(results)).(["branch", "bus", "iterations"]))

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
end

@testset "Gauss-Seidel AC Power Flow" begin
    @suppress begin
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
end

@testset "Fast Newton-Raphson (XB) AC Power Flow" begin
    @suppress begin
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
end

@testset "Fast Newton-Raphson (BX) AC Power Flow" begin
    @suppress begin
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
end


@testset "Generates PMU set" begin
    @suppress begin
        
    end
end
