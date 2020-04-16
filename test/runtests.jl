using JuliaGrid
using HDF5
using Test

testData = "PowerFlowTest_case30.h5"
data = "case30.h5"
accuracy = 1e-7
path = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/", testData)

@testset "DC Power Flow" begin
    results = h5read(path, "/dc")
    bus, branch, generator, iterations = runpf("dc", data)

    Ti = @view(bus[:, 2])
    Pinj = @view(bus[:, 3])
    Pij = @view(branch[:, 4])
    Pgen = @view(generator[:, 2])

    @test maximum(abs.(Ti  - results["Ti"])) < accuracy
    @test maximum(abs.(Pinj  - results["Pinj"])) < accuracy
    @test maximum(abs.(Pij  - results["Pij"])) < accuracy
    @test maximum(abs.(Pgen  - results["Pgen"])) < accuracy
end

@testset "Newton-Raphson Power Flow" begin
    results = h5read(path, "/nr")
    bus, branch, generator, iterations = runpf("nr", data)
    Vi = @view(bus[:, 2])
    Ti = @view(bus[:, 3])
    Pinj = @view(bus[:, 4])
    Qinj = @view(bus[:, 5])
    Pij = @view(branch[:, 4])
    Qij = @view(branch[:, 5])
    Pji = @view(branch[:, 6])
    Qji = @view(branch[:, 7])
    Qbranch = @view(branch[:, 8])
    Ploss = @view(branch[:, 9])
    Qloss = @view(branch[:, 10])
    Pgen = @view(generator[:, 2])
    Qgen = @view(generator[:, 3])
    @test maximum(abs.(Vi  - results["Vi"])) < accuracy
    @test maximum(abs.(Ti  - results["Ti"])) < accuracy
    @test maximum(abs.(Pinj  - results["Pinj"])) < accuracy
    @test maximum(abs.(Qinj  - results["Qinj"])) < accuracy
    @test maximum(abs.(Pij  - results["Pij"])) < accuracy
    @test maximum(abs.(Qij  - results["Qij"])) < accuracy
    @test maximum(abs.(Pji  - results["Pji"])) < accuracy
    @test maximum(abs.(Qji  - results["Qji"])) < accuracy
    @test maximum(abs.(Qbranch  - results["Qbranch"])) < accuracy
    @test maximum(abs.(Ploss  - results["Ploss"])) < accuracy
    @test maximum(abs.(Qloss  - results["Qloss"])) < accuracy
    @test maximum(abs.(Pgen  - results["Pgen"])) < accuracy
    @test maximum(abs.(Qgen  - results["Qgen"])) < accuracy
    @test iterations - results["iterations"][1] == 0

    results = h5read(path, "/nrLimit")
    bus, branch, generator, iterations = runpf("nr", data; reactive = 1)
    Vi = @view(bus[:, 2])
    Ti = @view(bus[:, 3])
    @test maximum(abs.(Vi  - results["Vi"])) < accuracy
    @test maximum(abs.(Ti  - results["Ti"])) < accuracy
    @test iterations - results["iterations"][1] == 0
end

@testset "Gauss-Seidel Power Flow" begin
    results = h5read(path, "/gs")
    bus, branch, generator, iterations = runpf("gs", data; max = 1000)
    Vi = @view(bus[:, 2])
    Ti = @view(bus[:, 3])
    @test maximum(abs.(Vi  - results["Vi"])) < accuracy
    @test maximum(abs.(Ti  - results["Ti"])) < accuracy
    @test iterations - results["iterations"][1] == 0

    results = h5read(path, "/gsLimit")
    bus, branch, generator, iterations = runpf("gs", data; max = 1000, reactive = 1)
    Vi = @view(bus[:, 2])
    Ti = @view(bus[:, 3])
    @test maximum(abs.(Vi  - results["Vi"])) < accuracy
    @test maximum(abs.(Ti  - results["Ti"])) < accuracy
    @test iterations - results["iterations"][1] == 0
end

@testset "Fast Newton-Raphson Power (FDXB) Flow" begin
    results = h5read(path, "/fdxb")
    bus, branch, generator, iterations = runpf("fnrxb", data; max = 1000)
    Vi = @view(bus[:, 2])
    Ti = @view(bus[:, 3])
    @test maximum(abs.(Vi  - results["Vi"])) < accuracy
    @test maximum(abs.(Ti  - results["Ti"])) < accuracy
    @test iterations - results["iterations"][1] == 0

    results = h5read(path, "/fdxbLimit")
    bus, branch, generator, iterations = runpf("fnrxb", data; max = 1000, reactive = 1)
    Vi = @view(bus[:, 2])
    Ti = @view(bus[:, 3])
    @test maximum(abs.(Vi  - results["Vi"])) < accuracy
    @test maximum(abs.(Ti  - results["Ti"])) < accuracy
    @test iterations - results["iterations"][1] == 0
end

@testset "Fast Newton-Raphson Power (FDBX) Flow" begin
    results = h5read(path, "/fdbx")
    bus, branch, generator, iterations = runpf("fnrbx", data; max = 1000)
    Vi = @view(bus[:, 2])
    Ti = @view(bus[:, 3])
    @test maximum(abs.(Vi  - results["Vi"])) < accuracy
    @test maximum(abs.(Ti  - results["Ti"])) < accuracy
    @test iterations - results["iterations"][1] == 0

    results = h5read(path, "/fdbxLimit")
    bus, branch, generator, iterations = runpf("fnrbx", data; max = 1000, reactive = 1)
    Vi = @view(bus[:, 2])
    Ti = @view(bus[:, 3])
    @test maximum(abs.(Vi  - results["Vi"])) < accuracy
    @test maximum(abs.(Ti  - results["Ti"])) < accuracy
    @test iterations - results["iterations"][1] == 0
end
