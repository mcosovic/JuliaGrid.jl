@testset "Load and Save Matpower Case with String Labels" begin
    ########## Load and Save Using Bus Names ##########
    matpower = powerSystem(path * "case14test.m")
    @base(matpower, MVA, kV)

    savePowerSystem(matpower; path = path * "case14str.h5", reference = "IEEE 14", note = "Test")
    hdf5 = powerSystem(path * "case14str.h5")
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

    @testset "Labels" begin
        @test haskey(matpower.bus.label, "Bus 7 ZV") == haskey(hdf5.bus.label, "Bus 7 ZV")
        @test haskey(matpower.bus.label, "Bus 12 LV") == haskey(hdf5.bus.label, "Bus 12 LV")
    end

    ########## Load and Save Without Bus Names ##########
    matpower = powerSystem(path * "case30test.m")

    savePowerSystem(matpower; path = path * "case30str.h5")
    hdf5 = powerSystem(path * "case30str.h5")

    @testset "Power System Data" begin
        teststruct(matpower.bus, hdf5.bus)
        teststruct(matpower.branch, hdf5.branch)
        teststruct(matpower.generator, hdf5.generator)
        teststruct(matpower.base, hdf5.base)
    end

    @testset "Labels" begin
        @test haskey(matpower.bus.label, "15") == haskey(hdf5.bus.label, "15")
        @test haskey(matpower.bus.label, "30") == haskey(hdf5.bus.label, "30")
    end

    ########## Load and Save Using Template for Labels ##########
    @bus(label = "Bus ?")
    @branch(label = "Branch ?")
    @generator(label = "Gen ?")
    matpower = powerSystem(path * "case30test.m")

    savePowerSystem(matpower; path = path * "case30tmpstr.h5")
    hdf5 = powerSystem(path * "case30tmpstr.h5")

    @testset "Power System Data" begin
        teststruct(matpower.bus, hdf5.bus)
        teststruct(matpower.branch, hdf5.branch)
        teststruct(matpower.generator, hdf5.generator)
        teststruct(matpower.base, hdf5.base)
    end

    @testset "Labels" begin
        @test haskey(matpower.bus.label, "Bus 15") == haskey(hdf5.bus.label, "Bus 15")
        @test haskey(matpower.bus.label, "Bus 30") == haskey(hdf5.bus.label, "Bus 30")
        @test haskey(matpower.branch.label, "Branch 10") == haskey(hdf5.branch.label, "Branch 10")
        @test haskey(matpower.branch.label, "Branch 20") == haskey(hdf5.branch.label, "Branch 20")
        @test haskey(matpower.generator.label, "Gen 1") == haskey(hdf5.generator.label, "Gen 1")
        @test haskey(matpower.generator.label, "Gen 5") == haskey(hdf5.generator.label, "Gen 5")
    end
end

@testset "Load and Save Matpower Case with Integer Labels" begin
    @default(template)
    @config(label = Integer)

    ########## Load and Save ##########
    matpower = powerSystem(path * "case14test.m")
    @base(matpower, MVA, kV)

    savePowerSystem(matpower; path = path * "case14integer.h5")
    hdf5 = powerSystem(path * "case14integer.h5")
    @base(hdf5, MVA, kV)

    @testset "Power System Data" begin
        teststruct(matpower.bus, hdf5.bus)
        teststruct(matpower.branch, hdf5.branch)
        teststruct(matpower.generator, hdf5.generator)
        teststruct(matpower.base, hdf5.base)
    end

    @testset "Labels" begin
        @test haskey(matpower.bus.label, 16) == haskey(hdf5.bus.label, 16)
        @test haskey(matpower.bus.label, 13) == haskey(hdf5.bus.label, 13)
    end
end

@testset "Load and Save PSSE Case with String Labels" begin
    @default(template)

    ########## Load and Save Using Bus Names and Templates ##########
    @bus(label = "Bus ?")
    @branch(label = "Branch ?")
    @generator(label = "Gen ?")

    psse = powerSystem(path * "psse.raw")
    matpower = powerSystem(path * "psse.m")

    @testset "Power System Data" begin
        teststruct(matpower.bus, psse.bus)
        teststruct(matpower.branch, psse.branch; atol = 1e-6)
        teststruct(matpower.generator, psse.generator)
        teststruct(matpower.base, psse.base)
    end

    @testset "Labels" begin
        @test haskey(psse.bus.label, "Bus 3 ZV") == haskey(matpower.bus.label, "Bus 3 ZV")
        @test haskey(psse.bus.label, "Bus 2") == haskey(matpower.bus.label, "Bus 2")
        @test haskey(psse.bus.label, "Bus 10") == haskey(matpower.bus.label, "Bus 10")
        @test haskey(psse.branch.label, "Branch 10") == haskey(matpower.branch.label, "Branch 10")
        @test haskey(psse.branch.label, "Branch 20") == haskey(matpower.branch.label, "Branch 20")
        @test haskey(psse.generator.label, "Gen 1") == haskey(matpower.generator.label, "Gen 1")
        @test haskey(psse.generator.label, "Gen 5") == haskey(matpower.generator.label, "Gen 5")
    end
end

@testset "Load and Save PSSE Case with Integer Labels" begin
    @default(template)
    @config(label = Integer)

    ########## Load and Save  ##########
    psse = powerSystem(path * "psse.raw")
    matpower = powerSystem(path * "psse.m")

    @testset "Power System Data" begin
        teststruct(matpower.bus, psse.bus)
        teststruct(matpower.branch, psse.branch; atol = 1e-6)
        teststruct(matpower.generator, psse.generator)
        teststruct(matpower.base, psse.base)
    end

    @testset "Labels" begin
        @test haskey(psse.bus.label, 3) == haskey(matpower.bus.label, 3)
        @test haskey(psse.bus.label, 2) == haskey(matpower.bus.label, 2)
        @test haskey(psse.bus.label, 10) == haskey(matpower.bus.label, 10)
        @test haskey(psse.branch.label, 10) == haskey(matpower.branch.label, 10)
        @test haskey(psse.branch.label, 20) == haskey(matpower.branch.label, 20)
        @test haskey(psse.generator.label, 1) == haskey(matpower.generator.label, 1)
        @test haskey(psse.generator.label, 5) == haskey(matpower.generator.label, 5)
    end
end