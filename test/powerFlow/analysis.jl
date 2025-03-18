@testset "Newton-Raphson Method" begin
    @default(unit)
    @default(template)

    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")
    matpwr14 = h5read(path * "results.h5", "case14test/newtonRaphson")

    acModel!(system14)
    analysis = newtonRaphson(system14, QR)
    powerFlow!(system14, analysis; power = true, current = true)

    @testset "IEEE 14: Matpower" begin
        testVoltageMatpower(matpwr14, analysis)
        testPowerMatpower(matpwr14, analysis)
    end

    @testset "IEEE 14: Powers and Currents" begin
        testCurrent(system14, analysis)
        testBus(system14, analysis)
        testBranch(system14, analysis)
        testGenerator(system14, analysis)
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")
    matpwr30 = h5read(path * "results.h5", "case30test/newtonRaphson")

    analysis = newtonRaphson(system30)
    startMagnitude = copy(analysis.voltage.magnitude)
    startAngle = copy(analysis.voltage.angle)

    powerFlow!(system30, analysis; power = true, current = true)

    @testset "IEEE 30: Matpower" begin
        testVoltageMatpower(matpwr30, analysis)
        testPowerMatpower(matpwr30, analysis)
    end

    @testset "IEEE 30: Powers and Currents" begin
        testCurrent(system30, analysis)
        testBus(system30, analysis)
        testBranch(system30, analysis)
        testGenerator(system30, analysis)
    end

    @testset "IEEE 30: Starting Voltages" begin
        setInitialPoint!(system30, analysis)
        @test analysis.voltage.magnitude == startMagnitude
        @test analysis.voltage.angle == startAngle
    end

    @testset "IEEE 30: Change of the Slack Bus" begin
        updateBus!(system30; label = 1, type = 2)
        updateBus!(system30; label = 3, type = 3)

        @suppress analysis = newtonRaphson(system30)
        powerFlow!(system30, analysis)

        testVoltageMatpower(matpwr30, analysis)
    end
end

@testset "Fast Newton-Raphson BX Method" begin
    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")
    matpwr14 = h5read(path * "results.h5", "case14test/fastNewtonRaphsonBX")

    acModel!(system14)
    analysis = fastNewtonRaphsonBX(system14)
    powerFlow!(system14, analysis; iteration = 30)

    @testset "IEEE 14: Matpower" begin
        testVoltageMatpower(matpwr14, analysis)
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")
    matpwr30 = h5read(path * "results.h5", "case30test/fastNewtonRaphsonBX")

    analysis = fastNewtonRaphsonBX(system30, QR)
    powerFlow!(system30, analysis; iteration = 30)

    @testset "IEEE 30: Matpower" begin
        testVoltageMatpower(matpwr30, analysis)
    end

    @testset "IEEE 30: Change of the Jacobian Pattern" begin
        updateBranch!(system30, analysis; label = 5, status = 0)
        dropZeros!(system30.model.ac)
        updateBranch!(system30, analysis; label = 5, status = 1)

        setInitialPoint!(system30, analysis)
        powerFlow!(system30, analysis; iteration = 30)

        testVoltageMatpower(matpwr30, analysis)
    end
end

@testset "Fast Newton-Raphson XB Method" begin
    @config(label = Integer)

    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")
    matpwr14 = h5read(path * "results.h5", "case14test/fastNewtonRaphsonXB")

    acModel!(system14)
    analysis = fastNewtonRaphsonXB(system14)
    powerFlow!(system14, analysis; iteration = 30)

    @testset "IEEE 14: Matpower" begin
        testVoltageMatpower(matpwr14, analysis)
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")
    matpwr30 = h5read(path * "results.h5", "case30test/fastNewtonRaphsonXB")

    analysis = fastNewtonRaphsonXB(system30, QR)
    powerFlow!(system30, analysis; iteration = 30)

    @testset "IEEE 30: Matpower" begin
        testVoltageMatpower(matpwr30, analysis)
    end
end

@testset "Gauss-Seidel Method" begin
    @default(template)

    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")
    matpwr14 = h5read(path * "results.h5", "case14test/gaussSeidel")

    acModel!(system14)
    analysis = gaussSeidel(system14)
    powerFlow!(system14, analysis; iteration = 300)

    @testset "IEEE 14: Matpower" begin
        testVoltageMatpower(matpwr14, analysis)
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")
    matpwr30 = h5read(path * "results.h5", "case30test/gaussSeidel")

    analysis = gaussSeidel(system30)
    iteration = 0
    powerFlow!(system30, analysis; iteration = 900)

    @testset "IEEE 30: Matpower" begin
        testVoltageMatpower(matpwr30, analysis)
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
    powerFlow!(system14, nr)

    fnrBX = fastNewtonRaphsonBX(system14)
    powerFlow!(system14, fnrBX; iteration = 300)

    fnrXB = fastNewtonRaphsonXB(system14)
    powerFlow!(system14, fnrXB; iteration = 300)

    gs = gaussSeidel(system14)
    powerFlow!(system14, gs; iteration = 1000, tolerance = 1e-9)

    @testset "IEEE 14: Voltages" begin
        @test nr.voltage.magnitude ≈ fnrBX.voltage.magnitude
        @test nr.voltage.angle ≈ fnrBX.voltage.angle
        @test nr.voltage.magnitude ≈ fnrXB.voltage.magnitude
        @test nr.voltage.angle ≈ fnrXB.voltage.angle
        @test nr.voltage.magnitude ≈ gs.voltage.magnitude
        @test nr.voltage.angle ≈ gs.voltage.angle
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")

    updateBranch!(system30; label = 2, conductance = 0.01)
    updateBranch!(system30; label = 5, conductance = 1e-4)
    updateBranch!(system30; label = 18, conductance = 0.5)

    acModel!(system30)
    nr = newtonRaphson(system30)
    powerFlow!(system30, nr)

    fnrBX = fastNewtonRaphsonBX(system30)
    powerFlow!(system30, fnrBX)

    fnrXB = fastNewtonRaphsonXB(system30)
    powerFlow!(system30, fnrXB)

    gs = gaussSeidel(system30)
    powerFlow!(system30, gs; iteration = 1500, tolerance = 1e-9)

    @testset "IEEE 30: Voltages" begin
        @test nr.voltage.magnitude ≈ fnrBX.voltage.magnitude
        @test nr.voltage.angle ≈ fnrBX.voltage.angle
        @test nr.voltage.magnitude ≈ fnrXB.voltage.magnitude
        @test nr.voltage.angle ≈ fnrXB.voltage.angle
        @test nr.voltage.magnitude ≈ gs.voltage.magnitude
        @test nr.voltage.angle ≈ gs.voltage.angle
    end
end

@testset "DC Power Flow" begin
    ########## IEEE 14-bus Test Case ##########
    system14 = powerSystem(path * "case14test.m")
    matpwr14 = h5read(path * "results.h5", "case14test/dcPowerFlow")

    dcModel!(system14)
    analysis = dcPowerFlow(system14)
    powerFlow!(system14, analysis; power = true)

    @testset "IEEE 14: Matpower" begin
        @test analysis.voltage.angle ≈ matpwr14["voltage"]
        testPowerMatpower(matpwr14, analysis)
    end

    @testset "IEEE 14: Powers" begin
        testBus(system14, analysis)
        testBranch(system14, analysis)
        testGenerator(system14, analysis)
    end

    ########## IEEE 30-bus Test Case ##########
    system30 = powerSystem(path * "case30test.m")
    matpwr30 = h5read(path * "results.h5", "case30test/dcPowerFlow")

    analysis = dcPowerFlow(system30, LDLt)
    powerFlow!(system30, analysis; power = true)

    @testset "IEEE 30: Matpower" begin
        @test analysis.voltage.angle ≈ matpwr30["voltage"]
        testPowerMatpower(matpwr30, analysis)
    end

    @testset "IEEE 30: Powers" begin
        testBus(system30, analysis)
        testBranch(system30, analysis)
        testGenerator(system30, analysis)
    end
end

@testset "Print Data in Per-Units" begin
    system14 = powerSystem(path * "case14test.m")

    ########## Print AC Data ##########
    analysis = newtonRaphson(system14)
    powerFlow!(system14, analysis; power = true, current = true)

    @capture_out @testset "Print AC Bus Data" begin
        width = Dict("Voltage" => 10, "Power Demand Active" => 9)
        show = Dict("Current Injection" => false, "Power Demand Reactive" => false)
        fmt = Dict("Shunt Power" => "%.6f", "Voltage" => "%.2f")

        printBusData(system14, analysis; width, show, fmt, repeat = 10)
        printBusData(system14, analysis; width, show, fmt, repeat = 10, style = false)

        width = Dict("Voltage Angle" => 10, "Power Injection Active" => 9)
        delimiter = ""

        printBusData(system14, analysis; label = 1, width, delimiter, header = true)
        printBusData(system14, analysis; label = 2, width, delimiter)
        printBusData(system14, analysis; label = 4, width, delimiter, footer = true)
        printBusData(system14, analysis; label = 1, width, delimiter, style = false)

        width = Dict("In-Use" => 10)
        show = Dict("Minimum" => false)
        fmt = Dict("Maximum Value" => "%.6f")

        printBusSummary(system14, analysis; width, show, fmt)
        printBusSummary(system14, analysis; width, show, fmt, style = false)
    end

    @capture_out @testset "Print AC Branch Data" begin
        width = Dict("To-Bus Power" => 10)
        show = Dict("Label" => false, "Series Current Angle" => false)
        fmt = Dict("From-Bus Power" => "%.2f", "To-Bus Power Reactive" => "%.2e")

        printBranchData(system14, analysis; width, show, fmt, repeat = 10)
        printBranchData(system14, analysis; width, show, fmt, style = false)

        width = Dict("To-Bus Power" => 10)
        delimiter = ""

        printBranchData(system14, analysis; label = 1, width, delimiter, header = true)
        printBranchData(system14, analysis; label = 2, width, delimiter)
        printBranchData(system14, analysis; label = 4, width, delimiter, footer = true)
        printBranchData(system14, analysis; label = 4, width, style = false)

        width = Dict("In-Use" => 10)
        show = Dict("Minimum" => false)
        fmt = Dict("Maximum Value" => "%.2f")

        printBranchSummary(system14, analysis; width, show, fmt, title = false)
        printBranchSummary(system14, analysis; width, show, fmt, style = false)
    end

    @capture_out @testset "Print AC Generator Data" begin
        width = Dict("Power Output" => 10)
        show = Dict("Label Bus" => false, "Status" => true)

        printGeneratorData(system14, analysis; width, show)
        printGeneratorData(system14, analysis; width, show, style = false)

        printGeneratorData(system14, analysis; label = 1, header = true, footer = true)
        printGeneratorData(system14, analysis; label = 1, style = false)

        printGeneratorSummary(system14, analysis; title = false)
        printGeneratorSummary(system14, analysis; style = false)
    end

    ########## Print DC Data ##########
    analysis = dcPowerFlow(system14)
    powerFlow!(system14, analysis; power = true)

    @capture_out @testset "Print DC Bus Data" begin
        printBusData(system14, analysis, repeat = 10)
        printBusData(system14, analysis, repeat = 10; label = 1)
        printBusSummary(system14, analysis)
    end

    @capture_out @testset "Print DC Branch Data" begin
        printBranchData(system14, analysis)
        printBranchData(system14, analysis; label = 1)
        printBranchSummary(system14, analysis)
    end

    @capture_out @testset "Print DC Generator Data" begin
        printGeneratorData(system14, analysis)
        printGeneratorData(system14, analysis; label = 1)
        printGeneratorSummary(system14, analysis)
    end
end

@testset "Print Data in SI Units" begin
    system14 = powerSystem(path * "case14test.m")

    @power(GW, MVAr)
    @voltage(kV, deg)
    @current(MA, deg)

    ########## Print AC Data ##########
    analysis = newtonRaphson(system14)
    powerFlow!(system14, analysis; power = true, current = true)

    @capture_out @testset "Print AC Bus Data" begin
        printBusData(system14, analysis)
        printBusData(system14, analysis; label = 1, header = true)
        printBusSummary(system14, analysis)
    end

    @capture_out @testset "Print AC Branch Data" begin
        printBranchData(system14, analysis)
        printBranchData(system14, analysis; label = 1, header = true)
        printBranchSummary(system14, analysis)
    end

    @capture_out @testset "Print AC Generator Data" begin
        printGeneratorData(system14, analysis)
        printGeneratorData(system14, analysis; label = 1, header = true)
        printGeneratorSummary(system14, analysis)
    end

    ########## Print DC Data ##########
    analysis = dcPowerFlow(system14)
    powerFlow!(system14, analysis; power = true)

    @capture_out @testset "Print DC Bus Data" begin
        printBusData(system14, analysis, repeat = 10)
        printBusData(system14, analysis, repeat = 10; label = 1)
        printBusSummary(system14, analysis)
    end

    @capture_out @testset "Print DC Branch Data" begin
        printBranchData(system14, analysis)
        printBranchData(system14, analysis; label = 1)
        printBranchSummary(system14, analysis)
    end

    @capture_out @testset "Print DC Generator Data" begin
        printGeneratorData(system14, analysis)
        printGeneratorData(system14, analysis; label = 1)
        printGeneratorSummary(system14, analysis)
    end
end