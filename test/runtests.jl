using JuliaGrid
using HDF5
using Test

testData = "PowerFlowTest_case30.h5"
data = "case30.h5"
accuracy = 1e-7
path = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/", testData)
