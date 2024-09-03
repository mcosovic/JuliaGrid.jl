import PrecompileTools

PrecompileTools.@setup_workload begin
    system = powerSystem()

    addBus!(system; label = 1, type = 3, active = 0.1)
    addBus!(system; label = 2, type = 1, reactive = 0.05)
    addBranch!(system; from = 1, to = 2, reactance = 0.05)
    addGenerator!(system; bus = 1, active = 0.5, reactive = 0.1)

    PrecompileTools.@compile_workload begin
        analysis = dcPowerFlow(system)
        solve!(system, analysis)

        analysis = newtonRaphson(system, QR)
        solve!(system, analysis)
    end
end