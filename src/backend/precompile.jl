import PrecompileTools

PrecompileTools.@setup_workload begin
    @config(label = Integer)
    ps = powerSystem()

    @config(label = String)
    ps = powerSystem()
    mt = measurement(ps)

    addBus!(ps; label = 1, type = 3, active = 0.1)
    addBus!(ps; label = 2, type = 1, reactive = 0.05)
    addBranch!(ps; label = 1, from = 1, to = 2, reactance = 0.05)
    addGenerator!(ps; bus = 1, active = 0.5, reactive = 0.1)

    addPmu!(mt; bus = 1, magnitude = 1.0, angle = 1.0)
    addPmu!(mt; bus = 2, magnitude = 1.0, angle = 1.0)

    PrecompileTools.@compile_workload begin
        ########## Power System ###########
        powersys = powerSystem("case14.h5")
        powersys = powerSystem("case14.raw")

        ########## Power Flow ###########
        analysis = newtonRaphson(ps)
        powerFlow!(analysis)

        analysis = newtonRaphson(ps, QR)
        powerFlow!(analysis)

        analysis = fastNewtonRaphsonBX(ps)

        analysis = dcPowerFlow(ps, LDLt)
        powerFlow!(analysis)

        ########## Optimal Power Flow ###########
        analysis = acOptimalPowerFlow(ps, @nospecialize)
        addBranch!(analysis; label = 2, from = 1, to = 2, reactance = 0.05)
        addGenerator!(analysis; label = 2, bus = 1, active = 0.5, reactive = 0.1)
        updateBus!(analysis; label = 1, susceptance = 0.01)

        analysis = dcOptimalPowerFlow(ps, @nospecialize)
        addBranch!(analysis; label = 3, from = 1, to = 2, reactance = 0.05)

        ########## Measurement ###########
        powersys, devicesys = ems("case14.h5", "monitoring.h5")

        ########## State Estimation ###########
        analysis = gaussNewton(mt)
        stateEstimation!(analysis)

        analysis = gaussNewton(mt, Orthogonal)
        stateEstimation!(analysis)

        analysis = pmuStateEstimation(mt)
        stateEstimation!(analysis)

        ########## Observability Analysis ###########
        islands = islandTopologicalFlow(mt)
        restorationGram!(mt, mt, islands)

        ########## Default ###########
        @default(template)
    end
end