module pfTest

using JuliaGrid
using HDF5

function dc_results_test()


    results = h5read("pfcase14.h5", "/DC")

    return results
  end

results = dc_results_test()
bus, branch, generator, = runpf("dc", "case14.h5")

end


# errT = maximum(abs.(bus[:,2]  - (bus[:,9] )))
# errPi = maximum(abs.(BUS[:,3]  - (bus[:,14] )))
# errPij = maximum(abs.(BRANCH[:,2]  - (branch[:,14] )))
# errPg = maximum(abs.(GENERATOR[:,2]  - (gen[:,2] )))
#
# @testset "SimplyBP" begin
#     @test runpf("dc", "case14.h5") ≈ wls_mldivide(jacobian, observation, noise)
#     @test bp("SimpleTest.h5", 1000, 50, 80, 0.0, 0.4, 0.0, 1e6, ALGORITHM = "sum", PATH = "test/") ≈ wls_mldivide(jacobian, observation, noise)
#     @test bp("SimpleTest.h5", 1000, 10, 1000, 0.2, 0.3, 10.0, 1e8, ALGORITHM = "sum", PATH = "test/") ≈ wls_mldivide(jacobian, observation, noise)
# end
