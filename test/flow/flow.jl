### Power flow tests
path = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/flow/")
nobasepower = string(path, "noBasePower.xlsx")
flow_case30 = string(path, "flow_case30.h5")
flow_case14test = string(path, "flow_case14test.h5")
case14test = string(path, "case14test.h5")
nobranch = string(path, "noBranch.xlsx")
nobus = string(path, "noBus.xlsx")
reducedbranch = string(path, "reducedBranch.xlsx")


@testset "DC Power Flow" begin
    runpf("case14.h5", "dc"; solve = "lu", save = string(path, "save.h5"))
    runpf("case14.h5", "dc", "main", "flow", "generation"; save = string(path, "save.xlsx"))
        rm(string(path, "save.h5"))
        rm(string(path, "save.xlsx"))
        @test !("save.h5" in cd(readdir, path))
        @test !("save.xlsx" in cd(readdir, path))

    runpf("case84.h5", "dc"; save = string(path, "save.h5"))
        rm(string(path, "save.h5"))
        @test !("save.h5" in cd(readdir, path))

    runpf(nobasepower, "dc")
        fieldsres = (:main, :flow, :generation)
        fieldssys = (:bus, :branch, :generator, :basePower)
        @test all(fieldsres == fieldnames(JuliaGrid.PowerFlowDC))
        @test all(fieldssys == fieldnames(JuliaGrid.PowerSystem))

    matpower = h5read(flow_case30, "/dc")
        accuracy = 1e-12
        results, = runpf("dc", "case30.h5")
        @test maximum(abs.(results.main[:, 2] - matpower["Ti"])) < accuracy
        @test maximum(abs.(results.main[:, 3] - matpower["Pinj"])) < accuracy
        @test maximum(abs.(results.flow[:, 4] - matpower["Pij"])) < accuracy
        @test maximum(abs.(results.generation[:, 2] - matpower["Pgen"])) < accuracy

    matpower = h5read(flow_case14test, "/dc")
        accuracy = 1e-12
        results, = runpf("dc", case14test)
        @test maximum(abs.(results.main[:, 2] - matpower["Ti"])) < accuracy
        @test maximum(abs.(results.main[:, 3] - matpower["Pinj"])) < accuracy
        @test maximum(abs.(results.flow[:, 4] - matpower["Pij"])) < accuracy
        @test maximum(abs.(results.generation[:, 2] - matpower["Pgen"])) < accuracy
end

@testset "Newton-Raphson AC Power Flow" begin
    runpf("case14.h5", "nr"; solve = "lu", save = string(path, "save.h5"))
    runpf("case14.h5", "nr", "main", "flow", "generation"; save = string(path, "save.xlsx"))
        rm(string(path, "save.h5"))
        rm(string(path, "save.xlsx"))
        @test !("save.h5" in cd(readdir, path))
        @test !("save.xlsx" in cd(readdir, path))

    runpf("case84.h5", "nr"; save = string(path, "save.h5"))
        rm(string(path, "save.h5"))
        @test !("save.h5" in cd(readdir, path))

    runpf(nobasepower, "nr")
        fieldsres = (:main, :flow, :generation, :iterations)
        fieldssys = (:bus, :branch, :generator, :basePower)
        @test all(fieldsres == fieldnames(JuliaGrid.PowerFlowAC))
        @test all(fieldssys == fieldnames(JuliaGrid.PowerSystem))

    matpower = h5read(flow_case30, "/nr")
        accuracy = 1e-11
        results, = runpf("nr", "case30.h5")
        @test maximum(abs.(results.main[:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(results.main[:, 3] - matpower["Ti"])) < accuracy
        @test maximum(abs.(results.main[:, 4] - matpower["Pinj"])) < accuracy
        @test maximum(abs.(results.main[:, 5] - matpower["Qinj"])) < accuracy
        @test maximum(abs.(results.flow[:, 4] - matpower["Pij"])) < accuracy
        @test maximum(abs.(results.flow[:, 5] - matpower["Qij"])) < accuracy
        @test maximum(abs.(results.flow[:, 6] - matpower["Pji"])) < accuracy
        @test maximum(abs.(results.flow[:, 7] - matpower["Qji"])) < accuracy
        @test maximum(abs.(results.flow[:, 8] - matpower["Qbranch"])) < accuracy
        @test maximum(abs.(results.flow[:, 9] - matpower["Ploss"])) < accuracy
        @test maximum(abs.(results.flow[:, 10] - matpower["Qloss"])) < accuracy
        @test maximum(abs.(results.generation[:, 2] - matpower["Pgen"])) < accuracy
        @test maximum(abs.(results.generation[:, 3] - matpower["Qgen"])) < accuracy
        @test results.iterations - matpower["iterations"][1] == 0

    matpower = h5read(flow_case30, "/nr")
        results, = runpf("nr", "case30.h5"; solve = "lu")
        @test maximum(abs.(results.main[:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(results.main[:, 3] - matpower["Ti"])) < accuracy
        @test results.iterations - matpower["iterations"][1] == 0


    matpower = h5read(flow_case30, "/nrLimit")
        results, = runpf("nr", "case30.h5"; reactive = 1)
        @test maximum(abs.(results.main[:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(results.main[:, 3] - matpower["Ti"])) < accuracy
        @test results.iterations - matpower["iterations"][1] == 0

    matpower = h5read(flow_case14test, "/nr")
        results, = runpf("nr", case14test)
        @test maximum(abs.(results.main[:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(results.main[:, 3] - matpower["Ti"])) < accuracy
        @test results.iterations - matpower["iterations"][1] == 0
end

@testset "Gauss-Seidel AC Power Flow" begin
    matpower = h5read(flow_case30, "/gs")
        accuracy = 1e-11
        results, = runpf("gs", "case30.h5"; max = 1000)
        @test maximum(abs.(results.main[:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(results.main[:, 3] - matpower["Ti"])) < accuracy
        @test results.iterations - matpower["iterations"][1] == 0

    matpower = h5read(flow_case30, "/gsLimit")
        results, = runpf("gs", "case30.h5"; max = 1000, reactive = 1)
        @test maximum(abs.(results.main[:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(results.main[:, 3] - matpower["Ti"])) < accuracy
        @test results.iterations - matpower["iterations"][1] == 0

    matpower = h5read(flow_case14test, "/gs")
        results, = runpf("gs", case14test; max = 1000)
        @test maximum(abs.(results.main[:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(results.main[:, 3] - matpower["Ti"])) < accuracy
        @test results.iterations - matpower["iterations"][1] == 0
end

@testset "Fast Newton-Raphson (XB) AC Power Flow" begin
    matpower = h5read(flow_case30, "/fdxb")
        accuracy = 1e-7
        results, = runpf("fnrxb", "case30.h5"; max = 1000)
        @test maximum(abs.(results.main[:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(results.main[:, 3] - matpower["Ti"])) < accuracy
        @test results.iterations - matpower["iterations"][1] == 0

    matpower = h5read(flow_case30, "/fdxbLimit")
        results, = runpf("fnrxb", "case30.h5"; max = 1000, reactive = 1)
        @test maximum(abs.(results.main[:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(results.main[:, 3] - matpower["Ti"])) < accuracy
        @test results.iterations - matpower["iterations"][1] == 0

    matpower = h5read(flow_case14test, "/fdxb")
        results, = runpf("fnrxb", case14test; max = 1000)
        @test maximum(abs.(results.main[:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(results.main[:, 3] - matpower["Ti"])) < accuracy
        @test results.iterations - matpower["iterations"][1] == 0
end

@testset "Fast Newton-Raphson (BX) AC Power Flow" begin
    matpower = h5read(flow_case30, "/fdbx")
        accuracy = 1e-7
        results, = runpf("fnrbx", "case30.h5"; max = 1000)
        @test maximum(abs.(results.main[:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(results.main[:, 3] - matpower["Ti"])) < accuracy
        @test results.iterations - matpower["iterations"][1] == 0

    matpower = h5read(flow_case30, "/fdbxLimit")
        results, = runpf("fnrbx", "case30.h5"; max = 1000, reactive = 1)
        @test maximum(abs.(results.main[:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(results.main[:, 3] - matpower["Ti"])) < accuracy
        @test results.iterations - matpower["iterations"][1] == 0

    matpower = h5read(flow_case14test, "/fdbx")
        results, = runpf("fnrbx", case14test; max = 1000)
        @test maximum(abs.(results.main[:, 2] - matpower["Vi"])) < accuracy
        @test maximum(abs.(results.main[:, 3] - matpower["Ti"])) < accuracy
        @test results.iterations - matpower["iterations"][1] == 0
end

@testset "Throws" begin
    @test_throws DomainError runpf("case144.jl")
    @test_throws ErrorException runpf("case14")
    @test_throws DomainError runpf("case144.h5")
    @test_throws ErrorException runpf(nobranch)
    @test_throws ErrorException runpf(nobus)
    @test_throws DomainError runpf(reducedbranch)
end
