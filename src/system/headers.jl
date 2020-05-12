### Power System
function psheader()
    basePower = [["Base Power" ""]; ["Power [MVA]" ""]]

    bus = [["Bus" "Type" "Demand" "Demand" "Shunt Conductance" "Shunt Susceptance" "Area" "Voltage" "Voltage" "Base Voltage" "Loss Zone" "Maximum Voltage" "Minimum Voltage" "Lagrange multiplier" "Lagrange multiplier" "Kuhn-Tucker multiplier" "Kuhn-Tucker multiplier"]
           ["Integer" "PQ(1), PV(2), Slack(3)" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "Integer" "Magnitude [p.u.]" "Angle [deg]" "Magnitude [kV]" "Integer" "Magnitude [p.u.]" "Magnitude [p.u.]" "Active Power Mismatch [u/MW]" "Reactive Power Mismatch [u/MVAr]" "Upper Voltage Magnitude Limit [u/p.u.]" "Lower Voltage Magnitude Limit [u/p.u.]"]]

    generator = [["Bus" "Generation" "Generation" "Maximum Generation" "Minimum Generation" "Voltage" "Base" "Status" "Maximum Generation" "Minimum Generation" "Lower of PQ Curve" "Upper of PQ Curve" "Minimum at PC1" "Maximum at PC1" "Minimum at PC2" "Maximum at PC2" "Ramp Rate ACG" "Ramp Rate 10" "Ramp Rate 30" "Ramp Rate Q" "Area Factor" "Kuhn-Tucker Multiplier" "Kuhn-Tucker Multiplier" "Kuhn-Tucker Multiplier" "Kuhn-Tucker Multiplier"]
                  ["Integer" "Active Power [MW]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Magnitude [p.u.]" "Power [MVA]" "Integer" "Active Power [MW]" "Active Power [MW]" "Active Power [MW]" "Active Power [MW]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Active Power per Minut [MW/min]" "Active Power [MW]" "Active Power [MW]" "Reactive Power per Minut [MVAr/min]" "Integer" "Upper Genration Active Power Limit [u/MW]" "Lower Genration Active Power Limit [u/MW]" "Upper Genration Reactive Power Limit [u/MVAr]" "Lower Genration Reactive Power Limit [u/MVAr]"]]

    branch = [["Branch" "From Bus" "To Bus" "Series Parameter" "Series Parameter" "Charging Parameter" "Long Term Rate" "Short Term Rate" "Emergency Rate" "Transformer" "Transformer" "Status" "Minimum Voltage Difference" "Maximum Voltage Difference" "Injected From Bus" "Injected From Bus" "Injected To Bus" "Injected To Bus" "Kuhn-Tucker Multiplier" "Kuhn-Tucker Multiplier" "Kuhn-Tucker Multiplier" "Kuhn-Tucker Multiplier"]
               ["Integer" "Integer" "Integer" "Resistance [p.u.]" "Reactance [p.u.]" "Susceptance [p.u.]" "Power [MVA]" "Power [MVA]" "Power [MVA]" "Turns Ratio" "Shift Angle [deg]" "Integer" "Angle [deg]" "Angle [deg]" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "Power From Bus Limit [u/MVA]" "Power To Bus Limit [u/MVA]" "Lower Angle Difference Limit [u/deg]" "Upper Angle Difference Limit [u/deg]"]]

    return (bus = bus, branch = branch, generator = generator, basePower = basePower)
end


### DC Power Flow
function dcpfheader()
    main = [["Bus" "Voltage" "Injection" "Generation" "Demand" "Shunt"]
            ["Integer" "Angle [deg]" "Active Power [MW]" "Active Power [MW]" "Active Power [MW]" "Active Power [MW]"]]

    flow = [["Branch" "From Bus" "To Bus" "From Bus Flow" "To Bus Flow"]
            ["Integer" "Integer" "Integer" "Active Power [MW]" "Active Power [MW]"]]

    generation = [["Bus" "Generation"]; ["Integer" "Active Power [MW]"]]

    return (main = main, flow = flow, generation = generation)
end


### AC Power Flow
function acpfheader()
    main = [["Bus" "Voltage" "Voltage" "Injection" "Injection" "Generation" "Generation" "Demand" "Demand" "Shunt" "Shunt"]
            ["Integer" "Magnitude [p.u.]" "Angle [deg]" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]"]]

    flow = [["Branch" "From Bus" "To Bus" "From Bus Flow" "From Bus Flow" "To Bus Flow" "To Bus Flow" "Branch Injection" "Loss" "Loss" "From Bus Current" "From Bus Current" "To Bus Current" "To Bus Current"]
            ["Integer" "Integer" "Integer" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "Magnitude [p.u.]" "Angle [deg]" "Magnitude [p.u.]" "Angle [deg]"]]

    generation = [["Bus" "Generation" "Generation"]; ["Integer" "Active Power [MW]" "Reactive Power [MVAr]"]]

    return (main = main, flow = flow, generation = generation)
end

### Measurements
function measureheader()
    pmuVoltage = [["Bus" "Measurement" "Noise" "Status" "Measurement" "Noise" "Status" "Exact" "Exact"]
                  ["Integer" "Magnitude [p.u.]" "Variance [p.u.]" "Integer" "Angle [rad]" "Variance [p.u.]" "Integer" "Magnitude [p.u.]" "Angle [rad]"]]

    pmuCurrent = [["Branch" "From Bus" "To Bus" "Measurement" "Noise" "Status" "Measurement" "Noise" "Status" "Exact" "Exact"]
                  ["Integer" "Integer" "Integer" "Magnitude [p.u.]" "Variance [p.u.]" "Integer" "Angle [rad]" "Variance [p.u.]" "Integer" "Magnitude [p.u.]" "Angle [rad]"]]

    legacyFlow = [["Branch" "From Bus" "To Bus" "Measurement" "Noise" "Status" "Measurement" "Noise" "Status" "Exact" "Exact"]
                  ["Integer" "Integer" "Integer" "Active Power [p.u.]" "Variance [p.u.]" "Integer" "Reactive Power [p.u.]" "Variance [p.u.]" "Integer" "Active Power [p.u.]" "Reactive Power [p.u.]"]]

    legacyCurrent = [["Branch" "From Bus" "To Bus" "Measurement" "Noise" "Status" "Exact"]
                     ["Integer" "Integer" "Integer" "Magnitude [p.u.]" "Variance [p.u.]" "Integer" "Magnitude [p.u.]"]]

    legacyInjection = [["Bus" "Measurement" "Noise" "Status" "Measurement" "Noise" "Status" "Exact" "Exact"]
                       ["Integer" "Active Power [p.u.]" "Variance [p.u.]" "Integer" "Reactive Power [p.u.]" "Variance [p.u.]" "Integer" "Active Power [p.u.]" "Reactive Power [p.u.]"]]

    legacyVoltage = [["Bus" "Measurement" "Noise" "Status" "Exact"]
                     ["Integer" "Magnitude [p.u.]" "Variance [p.u.]" "Integer" "Magnitude [p.u.]"]]

    return (pmuVoltage = pmuVoltage, pmuCurrent = pmuCurrent, legacyFlow = legacyFlow, legacyCurrent = legacyCurrent, legacyInjection = legacyInjection, legacyVoltage = legacyVoltage)
end

function dcseheader()
    main = [["Bus" "Voltage" "Injection"]
            ["Integer" "Angle [deg]" "Active Power [MW]"]]

    flow = [["Branch" "From Bus" "To Bus" "From Bus Flow" "To Bus Flow"]
           ["Integer" "Integer" "Integer" "Active Power [MW]" "Active Power [MW]"]]

    estimate = [["Device" "Device" "Device" "Device" "Device" "Device" "Algorithm" "Residual" "User" "Residual" ]
                ["In-service(1), Bad Data(2), Pseudo(3)" "Legacy(1), PMU(2)" "Pij(1), Pi(4), Ti(8)" "Local Number" "Measure" "Variance" "Estimate" "Estimate to Measure" "Exact" "Estimate to Exact"]]


    estimatedisplay = [["Device" "Device" "Device" "Device" "Device" "Device" "Algorithm" "Residual" "User" "Residual" ]
                       ["Status" "Class" "Type" "Local Number" "Measure" "Variance" "Estimate" "Estimate to Measure" "Exact" "Estimate to Exact"]]

    error = [["MAE" "RMS" "WRSSE" "MAE" "RMSE" "WRSSE"]
            ["estimates to measurements" "estimates to measurements" "estimates to measurements" "estimates to exacts"  "estimates to exacts"  "estimates to exacts"]]

    errordisplay = [["Estimate and corresponding measurement values in per-unit system" ""]
                    ["Mean absolute error" "."^10]
                    ["Root mean square error" "."^10]
                    ["Weighted residual sum of squares error" "."^10]
                    ["" ""]
                    ["Estimate and corresponding exact values in per-unit system" ""]
                    ["Mean absolute error" "."^10]
                    ["Root mean square error" "."^10]
                    ["Weighted residual sum of squares error" "."^10]]

    bad = [["Algorithm" "Device" "Device" "Device"  "Algorithm" "Device"]
           ["Pass" "Type" "Suspected Bad Data" "Local Index" "Normalized Residual" "Status"]]

    observe  = [["Flow Island" "Bus in Island"  "Device" "Device" "Device" "Device" "Device"]
                ["Integer" "Integer" "Class" "Pseudo-measurement" "Local Index" "Measure" "Variance"]]

    return (main = main, flow = flow, estimatedisplay = estimatedisplay, estimate = estimate, error = error, errordisplay = errordisplay, bad = bad, observe = observe)
end
    # error = [["Description" "MAE" "RMSE" "WRSS"]
    #         ["Values-Comparing Errors" "Per-Unit/Radian" "Per-Unit/Radian" "Per-Unit/Radian"]]

    # SEDCestimate1H5 = ["Number" "Algorithm" "Device" "Residual" "User" "Residual" "Device"]
    # SEDCestimate2H5 = ["Integer" "Estimate" "Measure" "Absolute Value" "Exact" "Absolute Value" "Variance"]
    #
    # SEDCestimate1H5noexact = ["Number" "Algorithm" "Device" "Residual" "Device"]
    # SEDCestimate2H5noexact = ["Integer" "Estimate" "Measure" "Absolute Value" "Variance"]
    #

    #
    # SEDCerrordes = ["measurement and corresponding estimate values"; "estimate values and corresponding exact values"; "state variable estimates and corresponding exact values"]
    # SEDCerrordesnoexact = ["measurement and corresponding estimate values"]
    #
    # groupsedc = ["bus", "branch", "estimate", "error"]
    #
    # h5open("D:/Dropbox/header.h5", "w") do file
    #     # Power System
    #     write(file, "system/bus", [PSbus1; PSbus2])
    #     write(file, "system/branch", [PSbranch1; PSbranch2])
    #     write(file, "system/generator", [PSgenerator1; PSgenerator2])
    #     write(file, "system/basePower", [PSbase1; PSbase2])
    #     write(file, "system/group", PSgroup)
    #
    #     # DC Power Flow
    #     write(file, "flowdc/main", [DCPFmain1; DCPFmain2])
    #     write(file, "flowdc/flow", [DCPFflow1; DCPFflow2])
    #     write(file, "flowdc/generation", [DCPFgeneration1; DCPFgeneration2])
    #     write(file, "flowdc/group", DCPFgroup)
    #
    #     # AC Power Flow
    #     write(file, "flowac/main", [ACPFmain1; ACPFmain2])
    #     write(file, "flowac/flow", [ACPFflow1; ACPFflow2])
    #     write(file, "flowac/generation", [ACPFgeneration1; ACPFgeneration2])
    #     write(file, "flowac/group", ACPFgroup)
    #
    #         #
    #         # write(file, "measurement/bus", [busi; busu])
    #         # write(file, "measurement/branch", [branchi; branchu])
    #         # write(file, "measurement/generator", [generatori; generatoru])
    #         # write(file, "measurement/basePower", [basei; baseu])
    #         # write(file, "measurement/pmuVoltage", [pmuVoltage; pmuVoltageu])
    #         # write(file, "measurement/pmuCurrent", [pmuCurrent; pmuCurrentu])
    #         # write(file, "measurement/legacyFlow", [legFlow; legFlowu])
    #         # write(file, "measurement/legacyCurrent", [legCurrent; legCurrentu])
    #         # write(file, "measurement/legacyInjection", [legInjection; legInjectionu])
    #         # write(file, "measurement/legacyVoltage", [legVoltage; legVoltageu])
    #         # write(file, "measurement/group", group)
    #         #
    #         #
    #         #
    #         # write(file, "flowac/bus", [busac; busuac])
    #         # write(file, "flowac/branch", [branchac; branchuac])
    #         # write(file, "flowac/generator", [generatorac; generatoruac])
    #         # write(file, "flowac/group", groupac)
    #         #
    #         # write(file, "estimationdc/bus", [SEDCbus1; SEDCbus2])
    #         # write(file, "estimationdc/branch", [SEDCbranch1; SEDCbranch2])
    #         # write(file, "estimationdc/estimate", [SEDCestimate1; SEDCestimate2])
    #         # write(file, "estimationdc/estimateno", [SEDCestimate1noexact; SEDCestimate2noexact])
    #         # write(file, "estimationdc/estimateH5", [SEDCestimate1H5; SEDCestimate2H5])
    #         # write(file, "estimationdc/estimateH5no", [SEDCestimate1H5noexact; SEDCestimate2H5noexact])
    #         # write(file, "estimationdc/error", [SEDCerror1; SEDCerror2])
    #         # write(file, "estimationdc/errordes", SEDCerrordes)
    #         # write(file, "estimationdc/errordesno", SEDCerrordesnoexact)
    #         # write(file, "estimationdc/group", groupsedc)
