module PowerFlowTest

using JuliaGrid
using HDF5
using Test

path = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/pfcase14.h5")

@testset "DC Power Flow" begin
    accuracy = 1e-10

    results = h5read(path, "/DC")
    bus, branch, generator, iterations = runpf("dc", "case14.h5")
display(results)
    Ti = @view(bus[:, 2])
    Pinj = @view(bus[:, 3])
    Pij = @view(branch[:, 4])
    Pgen = @view(generator[:, 2])

    @test maximum(abs.(Ti  - results["Ti"])) < accuracy
    @test maximum(abs.(Pinj  - results["Pi"])) < accuracy
    @test maximum(abs.(Pij  - results["Pij"])) < accuracy
    @test maximum(abs.(Pgen  - results["Pgen"])) < accuracy
end
#
# @testset "Newton-Raphson Power Flow" begin
#     accuracy = 1e-10
#
#     results = h5read(path, "/AC")
#     bus, branch, generator, iterations = runpf("nr", "case14.h5")
#
#     Vi = @view(bus[:, 2])
#     Ti = @view(bus[:, 3])
# # display(results)
#     @test maximum(abs.(Vi  - results["Vi"])) < accuracy
#     @test maximum(abs.(Ti  - results["Ti"])) < accuracy
#     # @test No - results["iterNR"] = 0
# end

end # PowerFlowTest
