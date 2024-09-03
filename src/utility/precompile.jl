import PrecompileTools

PrecompileTools.@setup_workload begin
    system = powerSystem()
    device = measurement()

    addBus!(system; label = 1, type = 3, active = 0.1)
    addBus!(system; label = 2, type = 1, reactive = 0.05)
    addBranch!(system; from = 1, to = 2, reactance = 0.05)
    addGenerator!(system; bus = 1, active = 0.5, reactive = 0.1)

    addPmu!(system, device; bus = 1, magnitude = 1.0, angle = 0.0)
    addPmu!(system, device; bus = 2, magnitude = 1.0, angle = 0.0)

    PrecompileTools.@compile_workload begin
        ########## DC Power Flow ###########
        analysis = dcPowerFlow(system)
        solve!(system, analysis)

        analysis = dcPowerFlow(system, QR)
        solve!(system, analysis)

        analysis = dcPowerFlow(system, LDLt)
        solve!(system, analysis)

        ########## AC Power Flow ###########
        analysis = newtonRaphson(system)
        solve!(system, analysis)

        analysis = newtonRaphson(system, QR)
        solve!(system, analysis)

        analysis = fastNewtonRaphsonBX(system)
        solve!(system, analysis)

        analysis = gaussSeidel(system)
        solve!(system, analysis)

        ########## DC State Estimation ###########
        analysis = dcWlsStateEstimation(system, device)
        solve!(system, analysis)

        analysis = dcWlsStateEstimation(system, device, QR)
        solve!(system, analysis)

        analysis = dcWlsStateEstimation(system, device, LDLt)
        solve!(system, analysis)

        analysis = dcWlsStateEstimation(system, device, Orthogonal)
        solve!(system, analysis)

        ########### PMU State Estimation ###########
        analysis = pmuWlsStateEstimation(system, device)
        solve!(system, analysis)

        analysis = pmuWlsStateEstimation(system, device, QR)
        solve!(system, analysis)

        analysis = pmuWlsStateEstimation(system, device, LDLt)
        solve!(system, analysis)

        analysis = pmuWlsStateEstimation(system, device, Orthogonal)
        solve!(system, analysis)

        ########### AC State Estimation ###########
        analysis = gaussNewton(system, device)
        solve!(system, analysis)

        analysis = gaussNewton(system, device, QR)
        solve!(system, analysis)

        analysis = gaussNewton(system, device, LDLt)
        solve!(system, analysis)

        analysis = gaussNewton(system, device, Orthogonal)
        solve!(system, analysis)
    end
end