using JuliaGrid
using HDF5
using Test
using Suppressor

path = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/")

@testset "DC Power Flow" begin
    @suppress begin
        pf = runpf("case14.h5", "dc"; solve = "lu", save = string(path, "save.h5"))
        pf = runpf("case14.h5", "dc"; save = string(path, "save.xlsx"))

        rm(string(path, "save.h5"))
        rm(string(path, "save.xlsx"))
        @test all(in(keys(pf)).(["branch", "generator", "bus"]))
        @test !any(cd(readdir, path) .== "save.h5")
        @test !any(cd(readdir, path) .== "save.xlsx")

        pf = runpf("case84.h5", "dc")
        @test all(in(keys(pf)).(["branch", "bus"]))

        accuracy = 1e-12
        matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/dc")
        pf = runpf("dc", "case30.h5")
        @test maximum(abs.(pf["bus"][:, 2] - matpower["Ti"])) < accuracy
        @test maximum(abs.(pf["bus"][:, 3] - matpower["Pinj"])) < accuracy
        @test maximum(abs.(pf["branch"][:, 4] - matpower["Pij"])) < accuracy
        @test maximum(abs.(pf["generator"][:, 2] - matpower["Pgen"])) < accuracy
    end
end

@testset "Newton-Raphson AC Power Flow" begin
    @suppress begin
        pf = runpf("case14.h5", "nr"; solve = "lu", save = string(path, "save.h5"))
        pf = runpf("case14.h5", "nr"; save = string(path, "save.xlsx"))
        rm(string(path, "save.h5"))
        rm(string(path, "save.xlsx"))
        @test all(in(keys(pf)).(["branch", "generator", "bus", "iterations"]))
        @test !any(cd(readdir, path) .== "save.h5")
        @test !any(cd(readdir, path) .== "save.xlsx")

        pf = runpf("case84.h5", "nr")
        @test all(in(keys(pf)).(["branch", "bus", "iterations"]))

        accuracy = 1e-11
        matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/nr")
        pf = runpf("nr", "case30.h5")
        @test maximum(abs.(pf["bus"][:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(pf["bus"][:, 3] - matpower["Ti"])) < accuracy
        @test maximum(abs.(pf["bus"][:, 4] - matpower["Pinj"])) < accuracy
        @test maximum(abs.(pf["bus"][:, 5] - matpower["Qinj"])) < accuracy
        @test maximum(abs.(pf["branch"][:, 4] - matpower["Pij"])) < accuracy
        @test maximum(abs.(pf["branch"][:, 5] - matpower["Qij"])) < accuracy
        @test maximum(abs.(pf["branch"][:, 6] - matpower["Pji"])) < accuracy
        @test maximum(abs.(pf["branch"][:, 7] - matpower["Qji"])) < accuracy
        @test maximum(abs.(pf["branch"][:, 8] - matpower["Qbranch"])) < accuracy
        @test maximum(abs.(pf["branch"][:, 9] - matpower["Ploss"])) < accuracy
        @test maximum(abs.(pf["branch"][:, 10] - matpower["Qloss"])) < accuracy
        @test maximum(abs.(pf["generator"][:, 2] - matpower["Pgen"])) < accuracy
        @test maximum(abs.(pf["generator"][:, 3] - matpower["Qgen"])) < accuracy
        @test pf["iterations"] - matpower["iterations"][1] == 0

        matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/nrLimit")
        pf = runpf("nr", "case30.h5"; reactive = 1)
        @test maximum(abs.(pf["bus"][:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(pf["bus"][:, 3] - matpower["Ti"])) < accuracy
        @test pf["iterations"] - matpower["iterations"][1] == 0
    end
end

@testset "Gauss-Seidel AC Power Flow" begin
    @suppress begin
        accuracy = 1e-11
        matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/gs")
        pf = runpf("gs", "case30.h5"; max = 1000)
        @test maximum(abs.(pf["bus"][:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(pf["bus"][:, 3] - matpower["Ti"])) < accuracy
        @test pf["iterations"] - matpower["iterations"][1] == 0

        matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/gsLimit")
        pf = runpf("gs", "case30.h5"; max = 1000, reactive = 1)
        @test maximum(abs.(pf["bus"][:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(pf["bus"][:, 3] - matpower["Ti"])) < accuracy
        @test pf["iterations"] - matpower["iterations"][1] == 0
    end
end

@testset "Fast Newton-Raphson (XB) AC Power Flow" begin
    @suppress begin
        accuracy = 1e-7
        matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/fdxb")
        pf = runpf("fnrxb", "case30.h5"; max = 1000)
        @test maximum(abs.(pf["bus"][:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(pf["bus"][:, 3] - matpower["Ti"])) < accuracy
        @test pf["iterations"] - matpower["iterations"][1] == 0

        matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/fdxbLimit")
        pf = runpf("fnrxb", "case30.h5"; max = 1000, reactive = 1)
        @test maximum(abs.(pf["bus"][:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(pf["bus"][:, 3] - matpower["Ti"])) < accuracy
        @test pf["iterations"] - matpower["iterations"][1] == 0
    end
end

@testset "Fast Newton-Raphson (BX) AC Power Flow" begin
    @suppress begin
        accuracy = 1e-7
        matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/fdbx")
        pf = runpf("fnrbx", "case30.h5"; max = 1000)
        @test maximum(abs.(pf["bus"][:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(pf["bus"][:, 3] - matpower["Ti"])) < accuracy
        @test pf["iterations"] - matpower["iterations"][1] == 0

        matpower = h5read(string(path, "PowerFlowTest_case30.h5"), "/fdbxLimit")
        pf = runpf("fnrbx", "case30.h5"; max = 1000, reactive = 1)
        @test maximum(abs.(pf["bus"][:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(pf["bus"][:, 3] - matpower["Ti"])) < accuracy
        @test pf["iterations"] - matpower["iterations"][1] == 0
    end
end
