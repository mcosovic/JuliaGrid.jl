@testset "Reusing AC Optimal Power Flow" begin
    @default(unit)
    @default(template)
    @config(label = Integer)

    system = powerSystem(path * "case14optimal.m")
    opf = acOptimalPowerFlow(system, Ipopt.Optimizer)

    @testset "Buses" begin
        updateBus!(opf; label = 1, active = 0.15, reactive = 0.2, conductance = 0.16)
        testReusing(opf)

        updateBus!(opf; label = 1, type = 1, angle = -0.1)
        updateBus!(opf; label = 2, type = 3, angle = -0.01, magnitude = 0.99, minMagnitude = 0.98)
        testReusing(opf)

        updateBus!(opf; label = 14, minMagnitude = 0.95)
        testReusing(opf)

        updateBus!(opf; label = 1, conductance = 0.06, susceptance = 0.8, angle = -0.01)
        testReusing(opf)

        updateBus!(opf; label = 1, type = 1)
        updateBus!(opf; label = 2, type = 3)
        testReusing(opf)
    end

    @testset "Branches" begin
        addBranch!(opf; label = 21, from = 5, to = 7, reactance = 0.25, turnsRatio = 0.98)
        testReusing(opf)

        addBranch!(opf; label = 22, from = 4, to = 5, reactance = 0.25, type = 2)
        testReusing(opf)

        addBranch!(opf; label = 23, from = 2, to = 3, reactance = 0.25, status = 0)
        testReusing(opf)

        addBranch!(opf; label = 24, from = 10, to = 11, reactance = 0.25, maxDiffAngle = 0.2)
        testReusing(opf)

        updateBranch!(opf; label = 21, shiftAngle = -0.1, status = 0)
        testReusing(opf)

        updateBranch!(opf; label = 21, status = 1, reactance = 0.35, maxDiffAngle = 0.22)
        testReusing(opf)

        updateBranch!(opf; label = 22, minToBus = -0.18, maxToBus = 0.18, maxDiffAngle = 0.15)
        testReusing(opf)

        updateBranch!(opf; label = 22, minToBus = -0.18, maxToBus = 0.18, maxDiffAngle = 0.15)
        testReusing(opf)

        updateBranch!(opf; label = 21, status = 0)
        testReusing(opf)

        updateBranch!(opf; label = 22, reactance = 0.35, minFromBus = -0.22, maxFromBus = 0.22)
        testReusing(opf)

        updateBranch!(opf; label = 22, minToBus = -0.22, maxToBus = 0.22)
        testReusing(opf)

        updateBranch!(opf; label = 24, reactance = 0.21, minDiffAngle = -0.2)
        testReusing(opf)

        addBranch!(system; label = 25, from = 1, to = 2, reactance = 0.45, minFromBus = 0.0)
        updateBranch!(opf; label = 25, maxFromBus = 0.1, type = 1)
        testReusing(opf)

        updateBranch!(system; label = 25, maxFromBus = 0.4, type = 3)
        updateBranch!(opf; label = 25)
        testReusing(opf)
    end

    @testset "Generators" begin
        addGenerator!(opf; label = 9, bus = 3, active = 0.3, minActive = 0.0, maxActive = 0.5)
        cost!(opf; generator = 9, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
        testReusing(opf)

        updateGenerator!(opf; label = 9, status = 1)
        testReusing(opf)

        cost!(opf; generator = 9, active = 2, polynomial = [800.0; 200.0; 80.0])
        testReusing(opf)

        cost!(opf; generator = 9, active = 2, polynomial = [800.0; 200.0; 80.0; 30.0])
        testReusing(opf)

        updateGenerator!(opf; label = 9, status = 0)
        testReusing(opf)

        updateGenerator!(opf; label = 9, status = 1)
        testReusing(opf)

        addGenerator!(opf; label = 10, bus = 7, active = 0.3, maxActive = 1.0, maxReactive = Inf)
        cost!(opf; generator = 10, active = 2, polynomial = [452.2; 31; 18])
        testReusing(opf)

        updateGenerator!(opf; label = 10, maxActive = 0.5, status = 1)
        cost!(opf; generator = 10, active = 1, piecewise = [10 12.3; 14.7 16.8; 18.1 19.2])
        testReusing(opf)

        updateGenerator!(opf; label = 10, status = 0)
        cost!(opf; generator = 10, active = 2, polynomial = [400.0; 300.0; 10.0; 5.0])
        testReusing(opf)

        updateGenerator!(opf; label = 10, status = 1)
        testReusing(opf)

        addGenerator!(opf; label = 11, bus = 6, active = 0.3, maxReactive = Inf, status = 0)
        cost!(opf; generator = 11, active = 2, polynomial = [452.2; 31; 18; 5])
        testReusing(opf)

        cost!(opf; generator = 11, active = 1, piecewise = [10 12.3; 14.7 16.8])
        testReusing(opf)

        updateGenerator!(opf; label = 11, status = 0)
        testReusing(opf)

        updateGenerator!(opf; label = 11, status = 1)
        testReusing(opf)

        addGenerator!(opf; label = 12, bus = 5, active = 0.2, maxReactive = Inf, status = 0)
        cost!(opf; generator = 12, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
        testReusing(opf)

        updateGenerator!(opf; label = 12, maxReactive = Inf, status = 1)
        testReusing(opf)

        updateGenerator!(opf; label = 12, status = 0, maxActive = 0.8, maxReactive = 0.8)
        testReusing(opf)

        updateGenerator!(opf; label = 12, status = 1, maxActive = 0.8)
        testReusing(opf)

        addGenerator!(system; label = 13, bus = 6, active = 0.3, minActive = 0.0, maxActive = 0.5)
        cost!(system; generator = 13, active = 1, piecewise = [10 12.3; 14.7 16.8])
        updateGenerator!(opf; label = 13)
        testReusing(opf)

        updateGenerator!(system; label = 13, status = 0)
        cost!(system; generator = 13, active = 1, polynomial = [452.2; 31; 18; 5])
        updateGenerator!(opf; label = 13)
        testReusing(opf)

        updateGenerator!(system; label = 13, status = 1)
        cost!(system; generator = 13, active = 1, polynomial = [452.2; 31; 18])
        updateGenerator!(opf; label = 13)
        testReusing(opf)
    end

    @testset "Costs" begin
        cost!(opf; generator = 4, active = 2, polynomial = [452.2; 31; 18; 5])
        testReusing(opf)

        cost!(opf; generator = 4, active = 2, polynomial = [452.2; 31; 18])
        testReusing(opf)

        cost!(opf; generator = 4, active = 2, polynomial = [18.0])
        testReusing(opf)

        cost!(opf; generator = 4, active = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
        testReusing(opf)

        cost!(opf; generator = 4, active = 1, piecewise = [10.2 14.3; 11.5 16.1])
        testReusing(opf)

        cost!(opf; generator = 3, reactive = 2, polynomial = [452.2; 31; 18; 5])
        testReusing(opf)

        cost!(opf; generator = 3, reactive = 2, polynomial = [452.2; 31; 18])
        testReusing(opf)

        cost!(opf; generator = 3, reactive = 2, polynomial = [165.0])
        testReusing(opf)

        cost!(opf; generator = 3, reactive = 1, piecewise = [10.2 14.3; 11.5 16.1; 12.8 18.6])
        testReusing(opf)

        cost!(opf; generator = 3, reactive = 1, piecewise = [10.2 14.3; 11.5 16.1])
        testReusing(opf)
    end
end

@testset "Reusing DC Optimal Power Flow" begin
    @default(unit)
    @default(template)

    system = powerSystem(path * "case14optimal.m")
    cost!(system; generator = 3, active = 2, polynomial = [854.0, 116.0, 53.0])
    opf = dcOptimalPowerFlow(system, Ipopt.Optimizer)

    @testset "Buses" begin
        updateBus!(opf; label = 1, type = 1, active = 0.15, angle = -0.1, conductance = 0.16)
        updateBus!(opf; label = 2, type = 3, angle = -0.01)
        testReusing(opf)

        updateBus!(opf; label = 3, conductance = 0.2)
        testReusing(opf)

        updateBus!(opf; label = 2, type = 1)
        updateBus!(opf; label = 1, type = 3)
        testReusing(opf)
    end

    @testset "Branches" begin
        addBranch!(opf; label = 21, from = 5, to = 7, reactance = 0.25, turnsRatio = 0.98)
        testReusing(opf)

        addBranch!(opf; label = 22, from = 4, to = 5, reactance = 0.25, minFromBus = -0.18)
        testReusing(opf)

        addBranch!(opf; label = 23, from = 8, to = 9, reactance = 0.22, shiftAngle = -0.1)
        testReusing(opf)

        addBranch!(opf; label = 24, from = 8, to = 9, reactance = 0.22, status = 0)
        testReusing(opf)

        updateBranch!(opf; label = 21, shiftAngle = -0.1, status = 0)
        testReusing(opf)

        updateBranch!(opf; label = 21, status = 1)
        testReusing(opf)

        updateBranch!(opf; label = 22, status = 0)
        testReusing(opf)

        updateBranch!(opf; label = 21, maxFromBus = 0.18, minToBus = -0.18, maxDiffAngle = 0.22)
        testReusing(opf)

        updateBranch!(opf; label = 13, maxFromBus = 0.22, minToBus = -0.22, maxToBus = 0.22)
        testReusing(opf)

        addBranch!(system; label = 25, from = 1, to = 2, reactance = 0.45, minFromBus = 0.0)
        updateBranch!(opf; label = 25, maxFromBus = 0.1, type = 1)
        testReusing(opf)

        updateBranch!(system; label = 25, maxFromBus = 0.4, type = 3)
        updateBranch!(opf; label = 25)
        testReusing(opf)
    end

    @testset "Generators" begin
        addGenerator!(opf; label = 9, bus = 3, active = 0.3, minActive = 0.0, maxActive = 0.5)
        cost!(opf; generator = 9, active = 2, polynomial = [800.0; 200.0; 80.0])
        testReusing(opf)

        updateGenerator!(opf; label = 9, status = 1)
        testReusing(opf)

        cost!(opf; generator = 9, active = 1, piecewise = [10 12.3; 14.7 16.8; 18.1 19.2])
        testReusing(opf)

        updateGenerator!(opf; label = 9, status = 0)
        cost!(opf; generator = 9, active = 2, polynomial = [40.0; 20.0; 5.0])
        testReusing(opf)

        updateGenerator!(opf; label = 9, status = 1)
        testReusing(opf)

        addGenerator!(opf; label = 10, bus = 3, status = 0)
        cost!(opf; generator = 10, active = 2, polynomial = [800.0; 200.0; 80.0])
        testReusing(opf)

        updateGenerator!(opf; label = 10, maxActive = 0.5, status = 1)
        cost!(opf; generator = 10, active = 1, piecewise = [10 12.3; 14.7 16.8; 18.1 19.2])
        testReusing(opf)

        updateGenerator!(opf; label = 10, status = 0)
        cost!(opf; generator = 10, active = 2, polynomial = [400.0; 300.0; 10.0])
        testReusing(opf)

        updateGenerator!(opf; label = 10, status = 1)
        testReusing(opf)

        addGenerator!(opf; label = 11, bus = 4, active = 0.3, minActive = 0.0, status = 0)
        cost!(opf; generator = 11, active = 1, piecewise = [10 12.3; 14.7 16.8; 18.1 19.2])
        testReusing(opf)

        updateGenerator!(opf; label = 11, status = 1)
        cost!(opf; generator = 11, active = 2, polynomial = [400.0; 300.0])
        testReusing(opf)

        updateGenerator!(opf; label = 11, status = 0)
        testReusing(opf)

        updateGenerator!(opf; label = 11, status = 1)
        cost!(opf; generator = 11, active = 1, piecewise = [8 12.3; 16.7 17.8])
        testReusing(opf)

        cost!(opf; generator = 11, active = 2, polynomial = [200.0; 100.0; 50.0])
        testReusing(opf)

        addGenerator!(opf; label = 12, bus = 5)
        cost!(opf; generator = 12, active = 1, piecewise = [10 12.3; 14.7 16.8])
        testReusing(opf)

        cost!(opf; generator = 12, active = 1, piecewise = [10 12.3; 14.7 16.8; 18.1 19.2])
        testReusing(opf)

        cost!(opf; generator = 12, active = 2, polynomial = [400.0; 300.0])
        testReusing(opf)

        updateGenerator!(opf; label = 12, status = 0)
        testReusing(opf)

        addGenerator!(system; label = 13, bus = 6, active = 0.3, minActive = 0.0, maxActive = 0.5)
        cost!(system; generator = 13, active = 1, piecewise = [10 12.3; 14.7 16.8])
        updateGenerator!(opf; label = 13)
        testReusing(opf)

        updateGenerator!(system; label = 13, status = 0)
        cost!(system; generator = 13, active = 1, polynomial = [452.2; 31; 18; 5])
        updateGenerator!(opf; label = 13)
        testReusing(opf)

        updateGenerator!(system; label = 13, status = 1)
        cost!(system; generator = 13, active = 1, polynomial = [452.2; 31; 18])
        updateGenerator!(opf; label = 13)
        testReusing(opf)
    end
end