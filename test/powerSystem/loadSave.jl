@testset "Load and Save Power System Data" begin
    matlab = powerSystem(string(pathData, "case14test.m"))
    @base(matlab, MVA, kV)

    savePowerSystem(matlab; path = string(pathData, "case14test.h5"), reference = "IEEE 14", note = "Test Data")
    hdf5 = powerSystem(string(pathData, "case14test.h5"))
    @base(hdf5, MVA, kV)

    #### Test Power System Data ####
    compstruct(matlab.bus, hdf5.bus)
    compstruct(matlab.branch, hdf5.branch)
    compstruct(matlab.generator, hdf5.generator)
    compstruct(matlab.base, hdf5.base)

    #### Test Base Data ####
    @test matlab.base.power.value == 100.0
    @test matlab.base.power.unit == "MVA"
    @test matlab.base.power.prefix == 1e6
    @test all(matlab.base.voltage.value .== 138.0)
    @test matlab.base.voltage.unit == "kV"
    @test matlab.base.voltage.prefix == 1e3
end