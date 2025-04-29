@testset "Load and Save Power System with String Labels" begin
    ########## Load Matpower Power System ##########
    matpower = powerSystem(path * "case14test.m")
    @base(matpower, MVA, kV)

    ########## Save Power System ##########
    savePowerSystem(matpower; path = path * "case14.h5", reference = "IEEE 14", note = "Test")

    ########## Load Power System ##########
    hdf5 = powerSystem(path * "case14.h5")
    @base(hdf5, MVA, kV)

    @testset "Power System Data" begin
        teststruct(matpower.bus, hdf5.bus)
        teststruct(matpower.branch, hdf5.branch)
        teststruct(matpower.generator, hdf5.generator)
        teststruct(matpower.base, hdf5.base)
    end

    @testset "Base Data" begin
        @test matpower.base.power.value == 100.0
        @test matpower.base.power.unit == "MVA"
        @test matpower.base.power.prefix == 1e6
        @test all(matpower.base.voltage.value .== 138.0)
        @test matpower.base.voltage.unit == "kV"
        @test matpower.base.voltage.prefix == 1e3
    end

    ########## Load PSSE Power System ##########
    psse = powerSystem(path * "psse.raw")
    matpower = powerSystem(path * "psse.m")

    @testset "Power System Data" begin
        teststruct(matpower.bus, psse.bus)
        teststruct(matpower.branch, psse.branch; atol = 1e-6)
        teststruct(matpower.generator, psse.generator)
        teststruct(matpower.base, psse.base)
    end
end

@testset "Load and Save Power System with Integer Labels" begin
    @config(label = Integer)

    ########## Load Matpower Power System ##########
    matpower = powerSystem(path * "case14test.m")
    @base(matpower, MVA, kV)

    ########## Save Power System ##########
    savePowerSystem(matpower; path = path * "case14.h5", reference = "IEEE 14", note = "Test")

    ########## Load Power System ##########
    hdf5 = powerSystem(string(path, "case14.h5"))
    @base(hdf5, MVA, kV)

    @testset "Power System Data" begin
        teststruct(matpower.bus, hdf5.bus)
        teststruct(matpower.branch, hdf5.branch)
        teststruct(matpower.generator, hdf5.generator)
        teststruct(matpower.base, hdf5.base)
    end

    ######### Load PSSE Power System ##########
    psse = powerSystem(path * "psse.raw")
    matpower = powerSystem(path * "psse.m")

    @testset "Power System Data" begin
        teststruct(matpower.bus, psse.bus)
        teststruct(matpower.branch, psse.branch; atol = 1e-6)
        teststruct(matpower.generator, psse.generator)
        teststruct(matpower.base, psse.base)
    end
end