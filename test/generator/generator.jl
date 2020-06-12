### Measurement generator tests
path = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."), "test/generator/")
case14gen = string(path, "gen_case14.xlsx")
case14con = string(path, "gen_case14con.xlsx")
case14com = string(path, "gen_case14com.xlsx")
noexactred = string(path, "noExactRed.xlsx")


@testset "Measurement Generator Write Read" begin
    runmg(case14gen; runflow = 0, pmuset = "complete", save = string(path, "save.h5"))
    runmg(case14gen; runflow = 0, legacyset = "complete", save = string(path, "save.xlsx"))
        rm(string(path, "save.h5"))
        rm(string(path, "save.xlsx"))
        @test !("save.h5" in cd(readdir, path))
        @test !("save.xlsx" in cd(readdir, path))
        fields = (:pmuVoltage, :pmuCurrent, :legacyFlow, :legacyCurrent, :legacyInjection, :legacyVoltage)
        @test all(fields == fieldnames(JuliaGrid.Measurements))

    measure, = runmg(case14com; runflow = 0, pmuset = "complete", legacyset = "complete")
        @test all(measure.pmuVoltage .== 0) && all(measure.pmuCurrent .== 0)
        @test all(measure.legacyFlow .== 0) && all(measure.legacyInjection .== 0)

    measure, = runmg(case14con; runflow = 0, pmuset = "complete", legacyset = "complete")
        @test all(measure.legacyCurrent .== 0)
end

@testset "Measurement Generator PMU set" begin
    measure, = runmg("case14.h5"; runflow = 1, pmuset = "complete")
        @test all(measure.pmuVoltage[:, 4] .== 1) && all(measure.pmuVoltage[:, 7] .== 1)
        @test all(measure.pmuCurrent[:, 6] .== 1) && all(measure.pmuCurrent[:, 9] .== 1)

    measure, = runmg(case14con; runflow = 0, pmuset = "complete")
        @test all(measure.pmuVoltage[:, 4] .== 1) && all(measure.pmuVoltage[:, 7] .== 1)
        @test all(measure.pmuCurrent[:, 6] .== 1) && all(measure.pmuCurrent[:, 9] .== 1)

    measure, = runmg("case14.h5"; runflow = 1, pmuset = ["Vi" 0 "Iij" "all" "Dij" 4])
        @test all(measure.pmuVoltage[:, 2:7] .== 0) && all(measure.pmuCurrent[:, [4, 5, 7, 8]] .== 0)
        @test all(measure.pmuCurrent[:, 6] .== 1) && sum(measure.pmuCurrent[:, 9]) == 4

    measure, = runmg(case14con; runflow = 0, pmuset = ["Vi" 0 "Iij" "all" "Dij" 4])
        @test all(measure.pmuVoltage[:, 4] .== 0)
        @test all(measure.pmuCurrent[:, 6] .== 1) && sum(measure.pmuCurrent[:, 9]) == 4

    measure, = runmg("case14.h5"; runflow = 1, pmuset = ["Ti" 0 "complete"])
        @test sum(measure.pmuVoltage[:, 4]) == 14 && sum(measure.pmuVoltage[:, 7]) == 0
        @test sum(measure.pmuCurrent[:, 6]) == 40 && sum(measure.pmuCurrent[:, 9]) == 40

    measure, = runmg(case14con; runflow = 0, pmuset = ["Ti" 0 "complete"])
        @test sum(measure.pmuVoltage[:, 4]) == 8 && sum(measure.pmuVoltage[:, 7]) == 0
        @test sum(measure.pmuCurrent[:, 6]) == 11 && sum(measure.pmuCurrent[:, 9]) == 11

    measure, = runmg("case14.h5"; runflow = 1, pmuset = ["redundancy" 6])
        @test all(measure.pmuVoltage[:, 4] .== 1) && all(measure.pmuVoltage[:, 7] .== 1)
        @test all(measure.pmuCurrent[:, 6] .== 1) && all(measure.pmuCurrent[:, 9] .== 1)

    measure, = runmg("case14.h5"; runflow = 1, pmuset = ["redundancy" 2.5])
        N = sum(measure.pmuVoltage[:, 4]) + sum(measure.pmuVoltage[:, 7]) + sum(measure.pmuCurrent[:, 6]) + sum(measure.pmuCurrent[:, 9])
        @test round(N / (2 * 14 - 1), digits = 1) == 2.5

    measure, = runmg(case14con; runflow = 0, pmuset = ["redundancy" 0.5])
        N = sum(measure.pmuVoltage[:, 4]) + sum(measure.pmuVoltage[:, 7]) + sum(measure.pmuCurrent[:, 6]) + sum(measure.pmuCurrent[:, 9])
        @test round(N / (2 * 14 - 1), digits = 1) == 0.5

    measure, = runmg("case14.h5"; runflow = 1, pmuset = ["device" 3])
        @test sum(measure.pmuVoltage[:, 4]) == 3 && sum(measure.pmuVoltage[:, 7]) == 3
        @test measure.pmuVoltage[:, 4] == measure.pmuVoltage[:, 7]
        @test measure.pmuCurrent[:, 6] == measure.pmuCurrent[:, 9]
        bus = findall(x->x==1, measure.pmuVoltage[:, 4])
        branch = findall(x->x==1, measure.pmuCurrent[:, 6])
        from = measure.pmuCurrent[branch, 2]
        device = true
        for i in from if !(i in bus) device = false end end
        @test device

    measure, = runmg(case14con; runflow = 0, pmuset = ["device" 5])
        volon = findall(x->x==1, measure.pmuVoltage[:, 4])
        curron = findall(x->x==1, measure.pmuCurrent[:, 6])
        labelvol = measure.pmuVoltage[volon, 10]
        labelcurr = measure.pmuCurrent[curron, 12]
        device = true
        for i in labelcurr if !(i in labelvol) device = false end end
        @test device

    measure, = runmg("case14.h5"; runflow = 1, pmuset = "optimal")
        @test measure.pmuVoltage[:, 4] == measure.pmuVoltage[:, 7]
        @test measure.pmuCurrent[:, 6] == measure.pmuCurrent[:, 9]
        bus = findall(x->x==1, measure.pmuVoltage[:, 4])
        branch = findall(x->x==1, measure.pmuCurrent[:, 6])
        from = measure.pmuCurrent[branch, 2]
        optimal = true
        for i in from if !(i in bus) optimal = false end end
        @test optimal
end

@testset "Measurement Generator Legacy set" begin
    measure, = runmg("case30.h5"; runflow = 1, legacyset = "complete")
        @test all(measure.legacyFlow[:, 6] .== 1) && all(measure.legacyFlow[:, 9] .== 1)
        @test all(measure.legacyCurrent[:, 6] .== 1) && all(measure.legacyVoltage[:, 4] .== 1)
        @test all(measure.legacyInjection[:, 4] .== 1) && all(measure.legacyInjection[:, 7] .== 1)

    measure, = runmg(case14con; runflow = 0, legacyset = "complete")
        @test all(measure.legacyFlow[:, 6] .== 1) && all(measure.legacyFlow[:, 9] .== 1)
        @test all(measure.legacyVoltage[:, 4] .== 1)
        @test all(measure.legacyInjection[:, 4] .== 1) && all(measure.legacyInjection[:, 7] .== 1)

    measure, = runmg("case14.h5"; runflow = 1, legacyset = ["Pij" 0 "Qij" 4 "Iij" "all" "Pi" 2 "Qi" 4 "Vi" 8])
        @test all(measure.legacyFlow[:, 4:6] .== 0) && all(measure.legacyFlow[:, 7:8] .== 0)
        @test all(measure.legacyCurrent[:, 4:5] .== 0) && all(measure.legacyVoltage[:, 2:3] .== 0)
        @test all(measure.legacyInjection[:, 2:3] .== 0) && all(measure.legacyInjection[:, 5:6] .== 0)
        @test sum(measure.legacyFlow[:, 9]) == 4
        @test sum(measure.legacyCurrent[:, 6]) == 40 && sum(measure.legacyVoltage[:, 4]) == 8
        @test sum(measure.legacyInjection[:, 4]) == 2 && sum(measure.legacyInjection[:, 7]) == 4

    measure, = runmg(case14con; runflow = 0, legacyset = ["Pij" 0 "Qij" 4 "complete"])
        @test all(measure.legacyFlow[:, 6] .== 0) && sum(measure.legacyFlow[:, 9]) == 4
        @test all(measure.legacyVoltage[:, 4] .== 1)
        @test all(measure.legacyInjection[:, 4] .== 1) && all(measure.legacyInjection[:, 7] .== 1)

    measure, = runmg("case14.h5"; runflow = 1, legacyset = ["redundancy" 6])
        @test all(measure.legacyFlow[:, 6] .== 1) && all(measure.legacyFlow[:, 9] .== 1)
        @test all(measure.legacyCurrent[:, 6] .== 1) && all(measure.legacyVoltage[:, 4] .== 1)
        @test all(measure.legacyInjection[:, 4] .== 1) && all(measure.legacyInjection[:, 7] .== 1)

    measure, = runmg("case14.h5"; runflow = 1, legacyset = ["redundancy" 2.5])
        N = sum(measure.legacyFlow[:, 6]) + sum(measure.legacyFlow[:, 9]) + sum(measure.legacyCurrent[:, 6]) + sum(measure.legacyVoltage[:, 4]) +
        sum(measure.legacyInjection[:, 4]) + sum(measure.legacyInjection[:, 7])
        @test round(N / (2 * 14 - 1), digits = 1) == 2.5

    measure, = runmg(case14con; runflow = 0, legacyset = ["redundancy" 0.5])
        N = sum(measure.legacyFlow[:, 6]) + sum(measure.legacyFlow[:, 9]) + sum(measure.legacyVoltage[:, 4]) +
        sum(measure.legacyInjection[:, 4]) + sum(measure.legacyInjection[:, 7])
        @test round(N / (2 * 14 - 1), digits = 1) == 0.5
end

@testset "Measurement Generator PMU variance" begin
    measure, = runmg("case14.h5"; runflow = 1, pmuvariance = ["complete" 1e-5])
        @test all(measure.pmuVoltage[:, 3] .== 1e-5) && all(measure.pmuVoltage[:, 6] .== 1e-5)
        @test all(measure.pmuCurrent[:, 5] .== 1e-5) && all(measure.pmuCurrent[:, 8] .== 1e-5)
        Nv = sum((measure.pmuVoltage[:, 2] - measure.pmuVoltage[:, 8]).^2) + sum((measure.pmuVoltage[:, 5] - measure.pmuVoltage[:, 9]).^2)
        Nc = sum((measure.pmuCurrent[:, 4] - measure.pmuCurrent[:, 10]).^2) + sum((measure.pmuCurrent[:, 7] - measure.pmuCurrent[:, 11]).^2)
        @test 0.4 <= (((Nv + Nc) / 107) / 1e-5) <= 1.6

    measure, = runmg(case14con; runflow = 0, pmuvariance = ["complete" 1e-3])
        @test all(measure.pmuVoltage[:, 3] .== 1e-3) && all(measure.pmuVoltage[:, 6] .== 1e-3)
        @test all(measure.pmuCurrent[:, 5] .== 1e-3) && all(measure.pmuCurrent[:, 8] .== 1e-3)

    measure, = runmg("case14.h5"; runflow = 1, pmuvariance = ["complete" 1e-60])
        @test all(measure.pmuVoltage[:, 2] .≈ measure.pmuVoltage[:, 8])
        @test all(measure.pmuVoltage[2:end, 5] .≈ measure.pmuVoltage[2:end, 9])
        @test all(measure.pmuCurrent[:, 4] .≈ measure.pmuCurrent[:, 10])
        @test all(measure.pmuCurrent[:, 7] .≈ measure.pmuCurrent[:, 11])

    measure, = runmg("case14.h5"; runflow = 1, pmuvariance = ["random" 5 20])
        @test maximum(measure.pmuVoltage[:, 3]) < 20 && minimum(measure.pmuVoltage[:, 3]) > 5
        @test maximum(measure.pmuVoltage[:, 6]) < 20 && minimum(measure.pmuVoltage[:, 6]) > 5
        @test maximum(measure.pmuCurrent[:, 5]) < 20 && minimum(measure.pmuCurrent[:, 8]) > 5
        @test maximum(measure.pmuCurrent[:, 5]) < 20 && minimum(measure.pmuCurrent[:, 8]) > 5

    measure, = runmg(case14con; runflow = 0, pmuvariance = ["random" 5 5])
        @test all(measure.pmuVoltage[:, 3] .== 5) && all(measure.pmuVoltage[:, 6] .== 5)
        @test all(measure.pmuCurrent[:, 5] .== 5) && all(measure.pmuCurrent[:, 8] .== 5)

    measure, = runmg("case14.h5"; runflow = 1, pmuvariance = ["Vi" 2.5 "Iij" 4 "Dij" 6])
        @test all(measure.pmuVoltage[:, 3] .== 2.5) && all(measure.pmuVoltage[:, 6] .== 0)
        @test all(measure.pmuCurrent[:, 5] .== 4) && all(measure.pmuCurrent[:, 8] .== 6)

    measure, = runmg(case14con; runflow = 0, pmuvariance = ["Ti" 5 "complete" 1e-5])
        @test all(measure.pmuVoltage[:, 3] .== 1e-5) && all(measure.pmuVoltage[:, 6] .== 5)
        @test all(measure.pmuCurrent[:, 5] .== 1e-5) && all(measure.pmuCurrent[:, 8] .== 1e-5)
end

@testset "Measurement Generator Legacy variance" begin
    measure, = runmg("case14.h5"; runflow = 1, legacyvariance = ["complete" 1e-2])
        @test all(measure.legacyFlow[:, 5] .== 1e-2) && all(measure.legacyFlow[:, 8] .== 1e-2)
        @test all(measure.legacyCurrent[:, 5] .== 1e-2) && all(measure.legacyVoltage[:, 3] .== 1e-2)
        @test all(measure.legacyInjection[:, 3] .== 1e-2) && all(measure.legacyInjection[:, 6] .== 1e-2)
        Nf = sum((measure.legacyFlow[:, 4] - measure.legacyFlow[:, 10]).^2) + sum((measure.legacyFlow[:, 7] - measure.legacyFlow[:,11]).^2)
        Nn = sum((measure.legacyInjection[:, 2] - measure.legacyInjection[:, 8]).^2) + sum((measure.legacyInjection[:, 5] - measure.legacyInjection[:,9]).^2)
        Ni = sum((measure.legacyCurrent[:, 4] - measure.legacyCurrent[:, 7]).^2)
        Nv = sum((measure.legacyVoltage[:, 2] - measure.legacyVoltage[:, 5]).^2)
        @test 0.4 <= (((Nf + Nn + Ni + Nv) / 162) / 1e-2) <= 1.6

    measure, = runmg(case14con; runflow = 0, legacyvariance = ["complete" 1e-2])
        @test all(measure.legacyFlow[:, 5] .== 1e-2) && all(measure.legacyFlow[:, 8] .== 1e-2)
        @test all(measure.legacyVoltage[:, 3] .== 1e-2)
        @test all(measure.legacyInjection[:, 3] .== 1e-2) && all(measure.legacyInjection[:, 6] .== 1e-2)

    measure, = runmg("case_ACTIVSg70k.h5"; runflow = 1, legacyvariance = ["complete" 1e-2])
        @test all(measure.legacyFlow[:, 5] .== 1e-2) && all(measure.legacyFlow[:, 8] .== 1e-2)
        @test all(measure.legacyCurrent[:, 5] .== 1e-2) && all(measure.legacyVoltage[:, 3] .== 1e-2)
        @test all(measure.legacyInjection[:, 3] .== 1e-2) && all(measure.legacyInjection[:, 6] .== 1e-2)

    measure, = runmg("case14.h5"; runflow = 1, legacyvariance = ["complete" 1e-60])
        @test all(measure.legacyFlow[:, 4] .≈ measure.legacyFlow[:, 10])
        @test all(measure.legacyFlow[:, 7] .≈ measure.legacyFlow[:, 11])
        @test all(measure.legacyInjection[:, 2] .≈ measure.legacyInjection[:, 8])
        @test all(measure.legacyInjection[:, 5] .≈ measure.legacyInjection[:, 9])
        @test all(measure.legacyCurrent[:, 4] .≈ measure.legacyCurrent[:, 7])
        @test all(measure.legacyVoltage[:, 2] .≈ measure.legacyVoltage[:, 5])

    measure, = runmg("case14.h5"; runflow = 1, legacyvariance = ["random" 55 20])
        @test maximum(measure.legacyFlow[:, 5]) < 55 && minimum(measure.legacyFlow[:, 5]) > 20
        @test maximum(measure.legacyFlow[:, 8]) < 55 && minimum(measure.legacyFlow[:, 8]) > 20
        @test maximum(measure.legacyInjection[:, 3]) < 55 && minimum(measure.legacyInjection[:, 3]) > 20
        @test maximum(measure.legacyInjection[:, 6]) < 55 && minimum(measure.legacyInjection[:, 6]) > 20
        @test maximum(measure.legacyCurrent[:, 5]) < 55 && minimum(measure.legacyCurrent[:, 5]) > 20
        @test maximum(measure.legacyVoltage[:, 3]) < 55 && minimum(measure.legacyVoltage[:, 3]) > 20

    measure, = runmg("case14.h5"; runflow = 1, legacyvariance = ["Pij" 5 "Qij" 1 "Iij" 4 "Pi" 2 "Qi" 3 "Vi" 8])
        @test all(measure.legacyFlow[:, 5] .== 5) && all(measure.legacyFlow[:, 8] .== 1)
        @test all(measure.legacyCurrent[:, 5] .== 4) && all(measure.legacyVoltage[:, 3] .== 8)
        @test all(measure.legacyInjection[:, 3] .== 2) && all(measure.legacyInjection[:, 6] .== 3)

    measure, = runmg("case14.h5"; runflow = 1, legacyvariance = ["Pij" 5])
        @test all(measure.legacyFlow[:, 5] .== 5) && all(measure.legacyFlow[:, 8] .== 0)
        @test all(measure.legacyCurrent[:, 5] .== 0) && all(measure.legacyVoltage[:, 3] .== 0)
        @test all(measure.legacyInjection[:, 3] .== 0) && all(measure.legacyInjection[:, 6] .== 0)

    measure, = runmg("case14.h5"; runflow = 1, legacyvariance = ["Vi" 5 "complete" 1])
        @test all(measure.legacyFlow[:, 5] .== 1) && all(measure.legacyFlow[:, 8] .== 1)
        @test all(measure.legacyCurrent[:, 5] .== 1) && all(measure.legacyVoltage[:, 3] .== 5)
        @test all(measure.legacyInjection[:, 3] .== 1) && all(measure.legacyInjection[:, 6] .== 1)
end

@testset "Measurement Generator Comprehensive" begin
    measure, = runmg("case14.h5"; runflow = 1, pmuset = "complete", legacyset = ["Pij" 4], pmuvariance = ["random" 5 20], legacyvariance = ["complete" 1e-2])
        @test all(measure.pmuVoltage[:, 4] .== 1) && all(measure.pmuVoltage[:, 7] .== 1)
        @test all(measure.pmuCurrent[:, 6] .== 1) && all(measure.pmuCurrent[:, 9] .== 1)
        @test sum(measure.legacyFlow[:, 6]) == 4 && all(measure.legacyFlow[:, 9] .== 0)
        @test all(measure.legacyCurrent[:, 6] .== 0) && all(measure.legacyVoltage[:, 4] .== 0)
        @test all(measure.legacyInjection[:, 4] .== 0) && all(measure.legacyInjection[:, 7] .== 0)
        @test maximum(measure.pmuVoltage[:, 3]) < 20 && minimum(measure.pmuVoltage[:, 3]) > 5
        @test maximum(measure.pmuVoltage[:, 6]) < 20 && minimum(measure.pmuVoltage[:, 6]) > 5
        @test maximum(measure.pmuCurrent[:, 5]) < 20 && minimum(measure.pmuCurrent[:, 8]) > 5
        @test maximum(measure.pmuCurrent[:, 5]) < 20 && minimum(measure.pmuCurrent[:, 8]) > 5
        @test all(measure.legacyFlow[:, 5] .== 1e-2) && all(measure.legacyFlow[:, 8] .== 1e-2)
        @test all(measure.legacyCurrent[:, 5] .== 1e-2) && all(measure.legacyVoltage[:, 3] .== 1e-2)
        @test all(measure.legacyInjection[:, 3] .== 1e-2) && all(measure.legacyInjection[:, 6] .== 1e-2)

    measure, = runmg("case14.h5"; runflow = 1)
        @test all(measure.pmuVoltage[:, 2:7] .== 0)
        @test all(measure.pmuCurrent[:, 4:9] .== 0)
        @test all(measure.legacyFlow[:, 4:9] .== 0)
        @test all(measure.legacyCurrent[:, 4:6] .== 0)
        @test all(measure.legacyVoltage[:, 2:4] .== 0)
        @test all(measure.legacyInjection[:, 2:7] .== 0)

    measure, = runmg("case14.h5"; runflow = 1, pmuset = ["Vi" "all"])
        @test all(measure.pmuVoltage[:, [2, 3, 5, 6, 7]] .== 0)
        @test all(measure.pmuVoltage[:, 4] .== 1)
        @test all(measure.pmuCurrent[:, 4:9] .== 0)
        @test all(measure.legacyFlow[:, 4:9] .== 0)
        @test all(measure.legacyCurrent[:, 4:6] .== 0)
        @test all(measure.legacyVoltage[:, 2:4] .== 0)
        @test all(measure.legacyInjection[:, 2:7] .== 0)
end

@testset "Throws" begin
    @test_throws ErrorException runmg(case14con; runflow = 0, pmuset = ["Vi" "Ti" 4])
    @test_throws ErrorException runmg(case14con; runflow = 0, pmuset = ["Ti" -4])
    @test_throws ErrorException runmg(case14con; runflow = 0, pmuset = ["device"])
    @test_throws ErrorException runmg(case14con; runflow = 0, pmuset = ["redundancy"])
    @test_throws ErrorException runmg(case14con; runflow = 0, pmuset = ["redundancy" -2])

    @test_throws ErrorException runmg(case14con; runflow = 0, legacyset = ["Vi" "Pi" 4])
    @test_throws ErrorException runmg(case14con; runflow = 0, legacyset = ["Pi" -4])
    @test_throws ErrorException runmg(case14con; runflow = 0, legacyset = ["redundancy"])
    @test_throws ErrorException runmg(case14con; runflow = 0, legacyset = ["redundancy" -2])

    @test_throws ErrorException runmg(case14con; runflow = 0, pmuvariance = ["Vi" "Ti" 4])
    @test_throws ErrorException runmg(case14con; runflow = 0, pmuvariance = ["Vi" -4 "Ti" 4])
    @test_throws ErrorException runmg(case14con; runflow = 0, pmuvariance = ["random"])
    @test_throws ErrorException runmg(case14con; runflow = 0, pmuvariance = ["complete"])

    @test_throws ErrorException runmg(case14con; runflow = 0, legacyvariance = ["Vi" "Pij" 4])
    @test_throws ErrorException runmg(case14con; runflow = 0, pmuvariance = ["Vi" -4 "Pij" 4])
    @test_throws ErrorException runmg(case14con; runflow = 0, pmuvariance = ["random"])
    @test_throws ErrorException runmg(case14con; runflow = 0, pmuvariance = ["complete"])

    @test_throws ErrorException runmg(noexactred; runflow = 0, pmuset = "optimal")
    @test_throws ErrorException runmg(noexactred; runflow = 0, pmuset = ["device" 3])
    @test_throws BoundsError runmg(noexactred; runflow = 0, legacyvariance = ["Pij" 4])
end
