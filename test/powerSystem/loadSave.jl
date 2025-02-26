@testset "Load and Save Power System with String Labels" begin
    ########## Load Power System ##########
    matlab = powerSystem(path * "case14test.m")
    @base(matlab, MVA, kV)

    ########## Save Power System ##########
    savePowerSystem(
        matlab; path = path * "case14test.h5", reference = "IEEE 14", note = "Test Data"
    )

    ########## Load Power System ##########
    hdf5 = powerSystem(path * "case14test.h5")
    @base(hdf5, MVA, kV)

    @testset "Power System Data" begin
        compstruct(matlab.bus, hdf5.bus)
        compstruct(matlab.branch, hdf5.branch)
        compstruct(matlab.generator, hdf5.generator)
        compstruct(matlab.base, hdf5.base)
    end

    @testset "Base Data" begin
        @test matlab.base.power.value == 100.0
        @test matlab.base.power.unit == "MVA"
        @test matlab.base.power.prefix == 1e6
        @test all(matlab.base.voltage.value .== 138.0)
        @test matlab.base.voltage.unit == "kV"
        @test matlab.base.voltage.prefix == 1e3
    end
end

@testset "Load and Save Power System with Integer Labels" begin
    @labels(Integer)

    ########## Load Power System ##########
    matlab = powerSystem(path * "case14test.m")
    @base(matlab, MVA, kV)

    ########## Save Power System ##########
    savePowerSystem(
        matlab; path = path * "case14Int.h5", reference = "IEEE 14", note = "Test Data"
    )

    ########## Load Power System ##########
    hdf5 = powerSystem(string(path, "case14Int.h5"))
    @base(hdf5, MVA, kV)

    @testset "Power System Data" begin
        compstruct(matlab.bus, hdf5.bus)
        compstruct(matlab.branch, hdf5.branch)
        compstruct(matlab.generator, hdf5.generator)
        compstruct(matlab.base, hdf5.base)
    end
end