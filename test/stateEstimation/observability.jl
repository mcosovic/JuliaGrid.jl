@testset "DC State Estimation: Observability" begin
    @default(template)
    @default(unit)

    ########## IEEE 14-bus Test Case ##########
    system = powerSystem()

    @bus(active = 0.05)
    addBus!(system; label = "Bus 1", type = 3)
    addBus!(system; label = "Bus 2", type = 1)
    addBus!(system; label = "Bus 3", type = 1)
    addBus!(system; label = "Bus 4", type = 1)
    addBus!(system; label = "Bus 5", type = 1)
    addBus!(system; label = "Bus 6", type = 1)
    addBus!(system; label = "Bus 7", type = 1)
    addBus!(system; label = "Bus 8", type = 1)
    addBus!(system; label = "Bus 9", type = 1)
    addBus!(system; label = "Bus 10", type = 1)
    addBus!(system; label = "Bus 11", type = 1)
    addBus!(system; label = "Bus 12", type = 1)
    addBus!(system; label = "Bus 13", type = 1)
    addBus!(system; label = "Bus 14", type = 1)

    @branch(reactance = 0.05)
    addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2")
    addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 5")
    addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3")
    addBranch!(system; label = "Branch 4", from = "Bus 2", to = "Bus 4")
    addBranch!(system; label = "Branch 5", from = "Bus 2", to = "Bus 5")
    addBranch!(system; label = "Branch 6", from = "Bus 3", to = "Bus 4")
    addBranch!(system; label = "Branch 7", from = "Bus 4", to = "Bus 5")
    addBranch!(system; label = "Branch 8", from = "Bus 4", to = "Bus 7")
    addBranch!(system; label = "Branch 9", from = "Bus 4", to = "Bus 9")
    addBranch!(system; label = "Branch 10", from = "Bus 5", to = "Bus 6")
    addBranch!(system; label = "Branch 11", from = "Bus 6", to = "Bus 11")
    addBranch!(system; label = "Branch 12", from = "Bus 6", to = "Bus 12")
    addBranch!(system; label = "Branch 13", from = "Bus 6", to = "Bus 13")
    addBranch!(system; label = "Branch 14", from = "Bus 12", to = "Bus 13")
    addBranch!(system; label = "Branch 15", from = "Bus 14", to = "Bus 13")
    addBranch!(system; label = "Branch 16", from = "Bus 14", to = "Bus 9")
    addBranch!(system; label = "Branch 17", from = "Bus 9", to = "Bus 10")
    addBranch!(system; label = "Branch 18", from = "Bus 10", to = "Bus 11")
    addBranch!(system; label = "Branch 19", from = "Bus 9", to = "Bus 7")
    addBranch!(system; label = "Branch 20", from = "Bus 7", to = "Bus 8")

    addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)

    dcModel!(system)

    @testset "Case 1" begin
        device = measurement()

        @wattmeter(varianceFrom = 1e-4, varianceBus = 1e-4)
        addWattmeter!(system, device; from = "Branch 3", active = 0.04)
        addWattmeter!(system, device; from = "Branch 20", active = 0.04)
        addWattmeter!(system, device; from = "Branch 9", active = 0.04)
        addWattmeter!(system, device; from = "Branch 19", active = 0.04)
        addWattmeter!(system, device; from = "Branch 14", active = 0.04)

        addWattmeter!(system, device; from = "Branch 10", active = 0.04)
        addWattmeter!(system, device; from = "Branch 11", active = 0.04)
        addWattmeter!(system, device; from = "Branch 12", active = 0.04)
        addWattmeter!(system, device; from = "Branch 13", active = 0.04)
        addWattmeter!(system, device; from = "Branch 8", active = 0.04)
        addWattmeter!(system, device; from = "Branch 19", active = 0.04)
        addWattmeter!(system, device; from = "Branch 20", active = 0.04)

        islands = islandTopologicalFlow(system, device)

        islandsTest = [[1], [2; 3], [4; 7; 8; 9], [5; 6; 11; 12; 13], [10], [14]]
        for i = 1:lastindex(islandsTest)
            @test all(islands.island[i] .== islandsTest[i])
        end

        pseudo = measurement()
        addWattmeter!(system, pseudo; label = "P1", bus = "Bus 1", active = 0.04)
        addWattmeter!(system, pseudo; label = "P2", bus = "Bus 2", active = 0.04)
        addWattmeter!(system, pseudo; label = "P5", bus = "Bus 5", active = 0.04)
        addWattmeter!(system, pseudo; label = "P3", bus = "Bus 3", active = 0.04)
        addWattmeter!(system, pseudo; label = "P4", bus = "Bus 4", active = 0.04)
        addWattmeter!(system, pseudo; label = "P9", bus = "Bus 9", active = 0.04)
        addWattmeter!(system, pseudo; label = "P10", bus = "Bus 10", active = 0.04)
        addWattmeter!(system, pseudo; label = "P11", bus = "Bus 11", active = 0.04)
        addWattmeter!(system, pseudo; label = "P13", bus = "Bus 13", active = 0.04)
        addWattmeter!(system, pseudo; label = "P14", bus = "Bus 14", active = 0.04)

        addVarmeter!(system, pseudo; label = "P1", bus = "Bus 1", reactive = 0.04)
        addVarmeter!(system, pseudo; label = "P2", bus = "Bus 2", reactive = 0.04)
        addVarmeter!(system, pseudo; label = "P5", bus = "Bus 5", reactive = 0.04)
        addVarmeter!(system, pseudo; label = "P3", bus = "Bus 3", reactive = 0.04)
        addVarmeter!(system, pseudo; label = "P4", bus = "Bus 4", reactive = 0.04)
        addVarmeter!(system, pseudo; label = "P9", bus = "Bus 9", reactive = 0.04)
        addVarmeter!(system, pseudo; label = "P10", bus = "Bus 10", reactive = 0.04)
        addVarmeter!(system, pseudo; label = "P11", bus = "Bus 11", reactive = 0.04)
        addVarmeter!(system, pseudo; label = "P13", bus = "Bus 13", reactive = 0.04)
        addVarmeter!(system, pseudo; label = "P14", bus = "Bus 14", reactive = 0.04)

        addPmu!(
            system, pseudo; label = "T6",
            bus = "Bus 6", magnitude = 1.1, angle = 0.1, varianceMagnitude = 1e-3
        )
        addPmu!(
            system, pseudo; label = "T7",
            bus = "Bus 7", magnitude = 1.1, angle = 0.1, varianceMagnitude = 1e-3
        )

        restorationGram!(system, device, pseudo, islands)

        pseudoSet = ["P1"; "P2"; "P5"; "P9"; "P10"]
        for key in keys(device.wattmeter.label)
            for (k, label) in enumerate(pseudoSet)
                if key == label
                    deleteat!(pseudoSet, k)
                end
            end
        end
        for key in keys(device.pmu.label)
            for (k, label) in enumerate(pseudoSet)
                if key == label
                deleteat!(pseudoSet, k)
                end
            end
        end
        @test isempty(pseudoSet)
    end

    @testset "Case 2" begin
        device = measurement()

        addWattmeter!(system, device; from = "Branch 3", active = 0.04)
        addWattmeter!(system, device; from = "Branch 20", active = 0.04)
        addWattmeter!(system, device; from = "Branch 9", active = 0.04)
        addWattmeter!(system, device; from = "Branch 19", active = 0.04)
        addWattmeter!(system, device; from = "Branch 14", active = 0.04)

        addWattmeter!(system, device; from = "Branch 10", active = 0.04)
        addWattmeter!(system, device; from = "Branch 11", active = 0.04)
        addWattmeter!(system, device; from = "Branch 12", active = 0.04)
        addWattmeter!(system, device; from = "Branch 13", active = 0.04)
        addWattmeter!(system, device; from = "Branch 8", active = 0.04)
        addWattmeter!(system, device; from = "Branch 19", active = 0.04)
        addWattmeter!(system, device; from = "Branch 20", active = 0.04)

        addWattmeter!(system, device; bus = "Bus 2", active = 0.04)
        addWattmeter!(system, device; bus = "Bus 10", active = 0.04)
        addWattmeter!(system, device; bus = "Bus 14", active = 0.04)
        addWattmeter!(system, device; bus = "Bus 9", active = 0.04)

        islands = islandTopological(system, device)

        islandsTest = [[1], [2; 3], [4; 7; 8; 9; 5; 6; 11; 12; 13; 10; 14]]
        for i = 1:lastindex(islandsTest)
            @test all(islands.island[i] .== islandsTest[i])
        end

        pseudo = measurement()
        addWattmeter!(system, pseudo; label = "P3", bus = "Bus 3", active = 0.04)
        addVarmeter!(system, pseudo; label = "P3", bus = "Bus 3", reactive = 0.04)

        restorationGram!(system, device, pseudo, islands)
        @test device.wattmeter.label["P3"] == 17
    end

    system14 = powerSystem(path * "case14test.m")

    updateBranch!(system14, label = 3, status = 1)
    updateBranch!(system14, label = 18, status = 1)

    dcModel!(system14)
    pf = dcPowerFlow(system14)
    powerFlow!(system14, pf; power = true)

    @testset "Case 3" begin
        device = measurement()
        for (key, idx) in system14.bus.label
            addWattmeter!(system14, device; bus = key, active = pf.power.injection.active[idx])
        end
        for (key, idx) in system14.branch.label
            addWattmeter!(system14, device; from = key, active = pf.power.from.active[idx])
        end
        statusWattmeter!(system14, device; inservice = 10)
        islands = islandTopological(system14, device)

        pseudo = measurement()
        for (key, idx) in system14.branch.label
            addWattmeter!(system14, pseudo; label = "Pseudo $key", to = key, active = pf.power.to.active[idx])
            addVarmeter!(system14, pseudo; label = "Pseudo $key", to = key, reactive = pf.power.to.active[idx])
        end

        restorationGram!(system14, device, pseudo, islands)

        se = dcStateEstimation(system14, device)
        stateEstimation!(system14, se)
        @test se.voltage.angle ≈ pf.voltage.angle
    end

    @testset "Case 4" begin
        device = measurement()
        for (key, idx) in system14.bus.label
            addWattmeter!(system14, device; bus = key, active = pf.power.injection.active[idx])
        end
        for (key, idx) in system14.branch.label
            addWattmeter!(system14, device; from = key, active = pf.power.from.active[idx])
        end
        statusWattmeter!(system14, device; inservice = 8)
        islands = islandTopological(system14, device)

        pseudo = measurement()
        for (key, idx) in system14.bus.label
            addWattmeter!(system14, pseudo; label = "Pseudo $key", bus = key, active = pf.power.injection.active[idx])
            addVarmeter!(system14, pseudo; label = "Pseudo $key", bus = key, reactive = pf.power.injection.active[idx])
        end

        restorationGram!(system14, device, pseudo, islands)

        se = dcStateEstimation(system14, device)
        stateEstimation!(system14, se)
        @test se.voltage.angle ≈ pf.voltage.angle
    end

    @testset "Case 5" begin
        device = measurement()
        for (key, idx) in system14.bus.label
            addWattmeter!(system14, device; bus = key, active = pf.power.injection.active[idx])
        end
        for (key, idx) in system14.branch.label
            addWattmeter!(system14, device; from = key, active = pf.power.from.active[idx])
        end
        statusWattmeter!(system14, device; inservice = 11)
        islands = islandTopological(system14, device)

        pseudo = measurement()
        for (key, idx) in system14.bus.label
            addPmu!(
                system14, pseudo; label = "Pseudo $key", bus = key,
                magnitude = 1, varianceMagnitude = 1, angle = pf.voltage.angle[idx]
            )
        end

        restorationGram!(system14, device, pseudo, islands)

        se = dcStateEstimation(system14, device)
        stateEstimation!(system14, se)
        @test se.voltage.angle ≈ pf.voltage.angle
    end
end