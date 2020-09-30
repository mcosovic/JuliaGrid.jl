### Power System
function psheader(system)
    basePower = [["Base Power" ""]; ["Power [MVA]" ""]]

    bus = [["Bus" "Type" "Demand" "Demand" "Shunt Conductance" "Shunt Susceptance" "Area" "Voltage" "Voltage" "Base Voltage" "Loss Zone" "Maximum Voltage" "Minimum Voltage" "Lagrange multiplier" "Lagrange multiplier" "Kuhn-Tucker multiplier" "Kuhn-Tucker multiplier"]
           ["Integer" "PQ(1), PV(2), Slack(3)" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "Integer" "Magnitude [p.u.]" "Angle [deg]" "Magnitude [kV]" "Integer" "Magnitude [p.u.]" "Magnitude [p.u.]" "Active Power Mismatch [u/MW]" "Reactive Power Mismatch [u/MVAr]" "Upper Voltage Magnitude Limit [u/p.u.]" "Lower Voltage Magnitude Limit [u/p.u.]"]]

    branch = [["Branch" "From Bus" "To Bus" "Series Parameter" "Series Parameter" "Charging Parameter" "Long Term Rate" "Short Term Rate" "Emergency Rate" "Transformer" "Transformer" "Status" "Minimum Voltage Difference" "Maximum Voltage Difference" "Injected From Bus" "Injected From Bus" "Injected To Bus" "Injected To Bus" "Kuhn-Tucker Multiplier" "Kuhn-Tucker Multiplier" "Kuhn-Tucker Multiplier" "Kuhn-Tucker Multiplier"]
              ["Integer" "Integer" "Integer" "Resistance [p.u.]" "Reactance [p.u.]" "Susceptance [p.u.]" "Power [MVA]" "Power [MVA]" "Power [MVA]" "Turns Ratio" "Shift Angle [deg]" "Integer" "Angle [deg]" "Angle [deg]" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "Power From Bus Limit [u/MVA]" "Power To Bus Limit [u/MVA]" "Lower Angle Difference Limit [u/deg]" "Upper Angle Difference Limit [u/deg]"]]

    generator = [["Bus" "Generation" "Generation" "Maximum Generation" "Minimum Generation" "Voltage" "Base" "Status" "Maximum Generation" "Minimum Generation" "Lower of PQ Curve" "Upper of PQ Curve" "Minimum at PC1" "Maximum at PC1" "Minimum at PC2" "Maximum at PC2" "Ramp Rate ACG" "Ramp Rate 10" "Ramp Rate 30" "Ramp Rate Q" "Area Factor" "Kuhn-Tucker Multiplier" "Kuhn-Tucker Multiplier" "Kuhn-Tucker Multiplier" "Kuhn-Tucker Multiplier"]
                  ["Integer" "Active Power [MW]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Magnitude [p.u.]" "Power [MVA]" "Integer" "Active Power [MW]" "Active Power [MW]" "Active Power [MW]" "Active Power [MW]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Active Power per Minut [MW/min]" "Active Power [MW]" "Active Power [MW]" "Reactive Power per Minut [MVAr/min]" "Integer" "Upper Genration Active Power Limit [u/MW]" "Lower Genration Active Power Limit [u/MW]" "Upper Genration Reactive Power Limit [u/MVAr]" "Lower Genration Reactive Power Limit [u/MVAr]"]]

    N = size(system.generatorcost, 2) - 4
    generatorcost = [["Cost Model" "Cost" "Cost" "Cost Model" hcat(["Cost Model" for n = 1:N]...)]
                     ["Piecewise(1), Polynomial(2)" "Startup [currency]" "Shutdown [currency]" "Number of Data Points" hcat(["Coefficient c$(trunc(Int, (n-1)))" for n = N:-1:1]...)]]

    return (bus = bus, branch = branch, generator = generator, generatorcost = generatorcost, basePower = basePower)
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

    estimate = [["Number" "Device" "Device" "Device" "Device" "Device" "Device" "Algorithm" "Residual" "User" "Residual" ]
                ["Integer" "In-service(1), Bad Data(2), Pseudo(3)" "Legacy(1), PMU(2)" "Pij(1), Pi(4), Ti(8)" "Local Index" "Measure" "Variance" "Estimate" "Estimate to Measure" "Exact" "Estimate to Exact"]]


    estimatedisplay = [["Device" "Device" "Device" "Device" "Device" "Device" "Algorithm" "Residual" "User" "Residual" ]
                       ["Status" "Class" "Type" "Local Index" "Measure" "Variance" "Estimate" "Estimate to Measure" "Exact" "Estimate to Exact"]]

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
           ["Pass" "Class" "Suspected Bad Data" "Local Index" "Normalized Residual" "Status"]]

    observe  = [["Island" "Bus in Island"  "Device" "Device" "Device" "Device" "Device"]
                ["Integer" "Integer" "Class" "Pseudo-measurement" "Local Index" "Measure" "Variance"]]

    return (main = main, flow = flow, estimatedisplay = estimatedisplay, estimate = estimate, error = error, errordisplay = errordisplay, bad = bad, observe = observe)
end

### AC Power Flow
function pmuseheader()
    main = [["Bus" "Voltage" "Voltage" "Injection" "Injection" "Shunt" "Shunt"]
            ["Integer" "Magnitude [p.u.]" "Angle [deg]" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]"]]

    flow = [["Branch" "From Bus" "To Bus" "From Bus Flow" "From Bus Flow" "To Bus Flow" "To Bus Flow" "Branch Injection" "Loss" "Loss" "From Bus Current" "From Bus Current" "To Bus Current" "To Bus Current"]
            ["Integer" "Integer" "Integer" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "Magnitude [p.u.]" "Angle [deg]" "Magnitude [p.u.]" "Angle [deg]"]]

    estimate = [["Number" "Device" "Device" "Device" "Device" "Device" "Device" "Algorithm" "Residual" "User" "Residual" ]
                ["Integer" "In-service(1), Bad Data(2), Pseudo(3)" "Legacy(1), PMU(2)" "Pij(1), Pi(4), Ti(8)" "Local Index" "Measure" "Variance" "Estimate" "Estimate to Measure" "Exact" "Estimate to Exact"]]

    estimatedisplay = [["Device" "Device" "Device" "Device" "Device" "Device" "Algorithm" "Residual" "User" "Residual" ]
                       ["Status" "Class" "Type" "Local Index" "Measure" "Variance" "Estimate" "Estimate to Measure" "Exact" "Estimate to Exact"]]

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
            ["Pass" "Class" "Suspected Bad Data" "Local Index" "Normalized Residual" "Status"]]

    observe  = [["Flow Island" "Bus in Island"  "Device" "Device" "Device" "Device" "Device"]
                ["Integer" "Integer" "Class" "Pseudo-measurement" "Local Index" "Measure" "Variance"]]

    return (main = main, flow = flow, estimatedisplay = estimatedisplay, estimate = estimate, error = error, errordisplay = errordisplay, bad = bad, observe = observe)
end

### AC Power Flow
function acseheader()
    main = [["Bus" "Voltage" "Voltage" "Injection" "Injection" "Shunt" "Shunt"]
            ["Integer" "Magnitude [p.u.]" "Angle [deg]" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]"]]

    flow = [["Branch" "From Bus" "To Bus" "From Bus Flow" "From Bus Flow" "To Bus Flow" "To Bus Flow" "Branch Injection" "Loss" "Loss" "From Bus Current" "From Bus Current" "To Bus Current" "To Bus Current"]
            ["Integer" "Integer" "Integer" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "Magnitude [p.u.]" "Angle [deg]" "Magnitude [p.u.]" "Angle [deg]"]]

    estimate = [["Number" "Device" "Device" "Device" "Device" "Device" "Device" "Algorithm" "Residual" "User" "Residual" ]
                ["Integer" "In-service(1), Bad Data(2), Pseudo(3)" "Legacy(1), PMU(2)" "Pij(1), Pi(4), Ti(8)" "Local Index" "Measure" "Variance" "Estimate" "Estimate to Measure" "Exact" "Estimate to Exact"]]


    estimatedisplay = [["Device" "Device" "Device" "Device" "Device" "Device" "Algorithm" "Residual" "User" "Residual" ]
                        ["Status" "Class" "Type" "Local Index" "Measure" "Variance" "Estimate" "Estimate to Measure" "Exact" "Estimate to Exact"]]

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
            ["Pass" "Class" "Suspected Bad Data" "Local Index" "Normalized Residual" "Status"]]

    observe  = [["Island" "Bus in Island"  "Device" "Device" "Device" "Device" "Device"]
                ["Integer" "Integer" "Class" "Pseudo-measurement" "Local Index" "Measure" "Variance"]]

    return (main = main, flow = flow, estimatedisplay = estimatedisplay, estimate = estimate, error = error, errordisplay = errordisplay, bad = bad, observe = observe)
end
