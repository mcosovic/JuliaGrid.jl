@testset "Newton-Raphson Method" begin
    @default(unit)
    @default(template)

    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")
    matpwr14 = h5read(path * "results.h5", "case14test/newtonRaphson")

    acModel!(system14)
    analysis = newtonRaphson(system14, QR)
    powerFlow!(analysis; power = true, current = true)

    @testset "IEEE 14: Matpower" begin
        testVoltage(matpwr14, analysis)
        testPower(matpwr14, analysis)
    end

    @testset "IEEE 14: Powers and Currents" begin
        testBus(analysis)
        testBranch(analysis)
        testGenerator(analysis)
        testCurrent(analysis)
    end

    @testset "IEEE 14: KLU Factorization" begin
        analysis = newtonRaphson(system14, KLU)
        powerFlow!(analysis)
        testVoltage(matpwr14, analysis)
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")
    matpwr30 = h5read(path * "results.h5", "case30test/newtonRaphson")

    analysis = newtonRaphson(system30)
    startMagnitude = copy(analysis.voltage.magnitude)
    startAngle = copy(analysis.voltage.angle)

    powerFlow!(analysis; power = true, current = true)

    @testset "IEEE 30: Matpower" begin
        testVoltage(matpwr30, analysis)
        testPower(matpwr30, analysis)
    end

    @testset "IEEE 30: Powers and Currents" begin
        testBus(analysis)
        testBranch(analysis)
        testGenerator(analysis)
        testCurrent(analysis)
    end

    @testset "IEEE 30: Starting Voltages" begin
        setInitialPoint!(analysis)
        @test analysis.voltage.magnitude == startMagnitude
        @test analysis.voltage.angle == startAngle
    end

    @testset "IEEE 30: Change of the Slack Bus" begin
        updateBus!(system30; label = 1, type = 2)
        updateBus!(system30; label = 3, type = 3)

        @suppress analysis = newtonRaphson(system30)
        powerFlow!(analysis)

        testVoltage(matpwr30, analysis)
    end
end

@testset "Fast Newton-Raphson BX Method" begin
    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")
    matpwr14 = h5read(path * "results.h5", "case14test/fastNewtonRaphsonBX")

    acModel!(system14)
    analysis = fastNewtonRaphsonBX(system14)
    powerFlow!(analysis; iteration = 30)

    @testset "IEEE 14: Matpower" begin
        testVoltage(matpwr14, analysis)
    end

    @testset "IEEE 14: KLU Factorization" begin
        analysis = fastNewtonRaphsonBX(system14, KLU)
        powerFlow!(analysis; iteration = 30)
        testVoltage(matpwr14, analysis)
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")
    matpwr30 = h5read(path * "results.h5", "case30test/fastNewtonRaphsonBX")

    analysis = fastNewtonRaphsonBX(system30, QR)
    powerFlow!(analysis; iteration = 30)

    @testset "IEEE 30: Matpower" begin
        testVoltage(matpwr30, analysis)
    end

    @testset "IEEE 30: Change of the Jacobian Pattern" begin
        updateBranch!(analysis; label = 5, status = 0)
        dropZeros!(system30.model.ac)
        updateBranch!(analysis; label = 5, status = 1)

        setInitialPoint!(analysis)
        powerFlow!(analysis; iteration = 30)

        testVoltage(matpwr30, analysis)
    end
end

@testset "Fast Newton-Raphson XB Method" begin
    @config(label = Integer)

    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")
    matpwr14 = h5read(path * "results.h5", "case14test/fastNewtonRaphsonXB")

    acModel!(system14)
    analysis = fastNewtonRaphsonXB(system14)
    powerFlow!(analysis; iteration = 30)

    @testset "IEEE 14: Matpower" begin
        testVoltage(matpwr14, analysis)
    end

    @testset "IEEE 14: KLU Factorization" begin
        analysis = fastNewtonRaphsonXB(system14, KLU)
        powerFlow!(analysis; iteration = 30)
        testVoltage(matpwr14, analysis)
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")
    matpwr30 = h5read(path * "results.h5", "case30test/fastNewtonRaphsonXB")

    analysis = fastNewtonRaphsonXB(system30, QR)
    powerFlow!(analysis; iteration = 30)

    @testset "IEEE 30: Matpower" begin
        testVoltage(matpwr30, analysis)
    end
end

@testset "Gauss-Seidel Method" begin
    @default(template)

    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")
    matpwr14 = h5read(path * "results.h5", "case14test/gaussSeidel")

    acModel!(system14)
    analysis = gaussSeidel(system14)
    powerFlow!(analysis; iteration = 300)

    @testset "IEEE 14: Matpower" begin
        testVoltage(matpwr14, analysis)
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")
    matpwr30 = h5read(path * "results.h5", "case30test/gaussSeidel")

    analysis = gaussSeidel(system30)
    iteration = 0
    powerFlow!(analysis; iteration = 900)

    @testset "IEEE 30: Matpower" begin
        testVoltage(matpwr30, analysis)
    end
end

@testset "Compare AC Power Flows Methods" begin
    @default(unit)
    @default(template)

    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")

    updateBranch!(system14; label = 1, conductance = 0.58)
    updateBranch!(system14; label = 7, conductance = 0.083)
    updateBranch!(system14; label = 14, conductance = 0.052)

    acModel!(system14)
    nr = newtonRaphson(system14)
    powerFlow!( nr)

    fnrBX = fastNewtonRaphsonBX(system14)
    powerFlow!(fnrBX; iteration = 300)

    fnrXB = fastNewtonRaphsonXB(system14)
    powerFlow!(fnrXB; iteration = 300)

    gs = gaussSeidel(system14)
    powerFlow!(gs; iteration = 1000, tolerance = 1e-9)

    @testset "IEEE 14: Voltages" begin
        teststruct(nr.voltage, fnrBX.voltage; atol = 0)
        teststruct(nr.voltage, fnrXB.voltage; atol = 0)
        teststruct(nr.voltage, gs.voltage; atol = 0)
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")

    updateBranch!(system30; label = 2, conductance = 0.01)
    updateBranch!(system30; label = 5, conductance = 1e-4)
    updateBranch!(system30; label = 18, conductance = 0.5)

    acModel!(system30)
    nr = newtonRaphson(system30)
    powerFlow!(nr)

    fnrBX = fastNewtonRaphsonBX(system30)
    powerFlow!(fnrBX)

    fnrXB = fastNewtonRaphsonXB(system30)
    powerFlow!(fnrXB)

    gs = gaussSeidel(system30)
    powerFlow!(gs; iteration = 1500, tolerance = 1e-9)

    @testset "IEEE 30: Voltages" begin
        teststruct(nr.voltage, fnrBX.voltage; atol = 0)
        teststruct(nr.voltage, fnrXB.voltage; atol = 0)
        teststruct(nr.voltage, gs.voltage; atol = 0)
    end
end

@testset "DC Power Flow" begin
    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")
    matpwr14 = h5read(path * "results.h5", "case14test/dcPowerFlow")

    dcModel!(system14)
    analysis = dcPowerFlow(system14)
    powerFlow!(analysis; power = true)

    @testset "IEEE 14: Matpower" begin
        @test analysis.voltage.angle ≈ matpwr14["voltage"]
        testPower(matpwr14, analysis)
    end

    @testset "IEEE 14: Powers" begin
        testBus(analysis)
        testBranch(analysis)
        testGenerator(analysis)
    end

    @testset "IEEE 14: KLU Factorization" begin
        analysis = dcPowerFlow(system14, KLU)
        powerFlow!(analysis)
        @test analysis.voltage.angle ≈ matpwr14["voltage"]
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")
    matpwr30 = h5read(path * "results.h5", "case30test/dcPowerFlow")

    analysis = dcPowerFlow(system30, LDLt)
    powerFlow!(analysis; power = true)

    @testset "IEEE 30: Matpower" begin
        @test analysis.voltage.angle ≈ matpwr30["voltage"]
        testPower(matpwr30, analysis)
    end

    @testset "IEEE 30: Powers" begin
        testBus(analysis)
        testBranch(analysis)
        testGenerator(analysis)
    end
end

@testset "Print Data in Per-Units" begin
    @config(label = Integer)
    @bus(label = String)
    system14 = powerSystem(path * "case14test.m")

    ########## Print AC Data ##########
    analysis = newtonRaphson(system14)
    @suppress powerFlow!(analysis; power = true, current = true, verbose = 3)

    @suppress @testset "Print AC Bus Data" begin
        width = Dict("Voltage" => 10, "Power Demand Active" => 9)
        show = Dict("Current Injection" => false, "Power Demand Reactive" => false)
        fmt = Dict("Shunt Power" => "%.6f", "Voltage" => "%.2f")

        printBusData(analysis; width, show, fmt, repeat = 10)
        printBusData(analysis; width, show, fmt, repeat = 10, style = false)

        width = Dict("Voltage Angle" => 10, "Power Injection Active" => 9)
        delimiter = ""

        printBusData(analysis; label = "Bus 1 HV", width, delimiter, header = true)
        printBusData(analysis; label = "Bus 2 HV", width, delimiter)
        printBusData(analysis; label = "Bus 7 ZV", width, delimiter, footer = true)
        printBusData(analysis; label = "Bus 1 HV", width, delimiter, style = false)

        width = Dict("In-Use" => 10)
        show = Dict("Minimum" => false)
        fmt = Dict("Maximum Value" => "%.6f")

        printBusSummary(analysis; width, show, fmt)
        printBusSummary(analysis; width, show, fmt, style = false)
    end

    @suppress @testset "Print AC Branch Data" begin
        width = Dict("To-Bus Power" => 10)
        show = Dict("Label" => false, "Series Current Angle" => false)
        fmt = Dict("From-Bus Power" => "%.2f", "To-Bus Power Reactive" => "%.2e")

        printBranchData(analysis; width, show, fmt, repeat = 10)
        printBranchData(analysis; width, show, fmt, style = false)

        width = Dict("To-Bus Power" => 10)
        delimiter = ""

        printBranchData(analysis; label = 1, width, delimiter, header = true)
        printBranchData(analysis; label = 2, width, delimiter)
        printBranchData(analysis; label = 4, width, delimiter, footer = true)
        printBranchData(analysis; label = 4, width, style = false)

        width = Dict("In-Use" => 10)
        show = Dict("Minimum" => false)
        fmt = Dict("Maximum Value" => "%.2f")

        printBranchSummary(analysis; width, show, fmt, title = false)
        printBranchSummary(analysis; width, show, fmt, style = false)
    end

    @suppress @testset "Print AC Generator Data" begin
        width = Dict("Power Output" => 10)
        show = Dict("Label Bus" => false, "Status" => true)

        printGeneratorData(analysis; width, show)
        printGeneratorData(analysis; width, show, style = false)

        printGeneratorData(analysis; label = 1, header = true, footer = true)
        printGeneratorData(analysis; label = 1, style = false)

        printGeneratorSummary(analysis; title = false)
        printGeneratorSummary(analysis; style = false)
    end

    ########## Print DC Data ##########
    analysis = dcPowerFlow(system14)
    @suppress powerFlow!(analysis; power = true, verbose = 3)

    @suppress @testset "Print DC Bus Data" begin
        printBusData(analysis, repeat = 10)
        printBusData(analysis, repeat = 10; label = "Bus 1 HV")
        printBusSummary(analysis)
    end

    @suppress @testset "Print DC Branch Data" begin
        printBranchData(analysis)
        printBranchData(analysis; label = 1)
        printBranchSummary(analysis)
    end

    @suppress @testset "Print DC Generator Data" begin
        printGeneratorData(analysis)
        printGeneratorData(analysis; label = 1)
        printGeneratorSummary(analysis)
    end
end

@testset "Print Data in SI Units" begin
    @default(template)
    @bus(label = Integer)
    @branch(label = "Branch ?")
    @generator(label = Integer)
    system14 = powerSystem(path * "case14test.m")

    @power(GW, MVAr)
    @voltage(kV, deg)
    @current(MA, deg)

    ########## Print AC Data ##########
    analysis = newtonRaphson(system14)
    powerFlow!(analysis; power = true, current = true)

    @suppress @testset "Print AC Bus Data" begin
        printBusData(analysis)
        printBusData(analysis; label = 1, header = true)
        printBusSummary(analysis)
    end

    @suppress @testset "Print AC Branch Data" begin
        printBranchData(analysis)
        printBranchData(analysis; label = "Branch 1", header = true)
        printBranchSummary(analysis)
    end

    @suppress @testset "Print AC Generator Data" begin
        printGeneratorData(analysis)
        printGeneratorData(analysis; label = 1, header = true)
        printGeneratorSummary(analysis)
    end

    ########## Print DC Data ##########
    analysis = dcPowerFlow(system14)
    powerFlow!(analysis; power = true)

    @suppress @testset "Print DC Bus Data" begin
        printBusData(analysis, repeat = 10)
        printBusData(analysis, repeat = 10; label = 1)
        printBusSummary(analysis)
    end

    @suppress @testset "Print DC Branch Data" begin
        printBranchData(analysis)
        printBranchData(analysis; label = "Branch 10")
        printBranchSummary(analysis)
    end

    @suppress @testset "Print DC Generator Data" begin
        printGeneratorData(analysis)
        printGeneratorData(analysis; label = 1)
        printGeneratorSummary(analysis)
    end
end