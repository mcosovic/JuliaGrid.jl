#######################
#  Service Functions  #
#######################


#-------------------------------------------------------------------------------
function flowdc_headers()
    bus = ["Bus" "Voltage" "Injection" "Generation" "Demand" "Shunt"]
    branch = ["Branch" "From Bus" "To Bus" "From Bus Flow" "To Bus Flow"]
    generator = ["Bus" "Generation"]

    busu = ["" "Angle [deg]" "Active Power [MW]" "Active Power [MW]" "Active Power [MW]" "Active Power [MW]"]
    branchu = ["" "" "" "Active Power [MW]" "Active Power [MW]"]
    generatoru = ["" "Active Power [MW]"]

    header1 = [bus, branch, generator]
    header2 = [busu, branchu, generatoru]

    return header1, header2
end
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
function flowac_headers()
    bus = ["Bus" "Voltage" "Voltage" "Injection" "Injection" "Generation" "Generation" "Demand" "Demand" "Shunt" "Shunt"]
    branch = ["Branch" "From Bus" "To Bus" "From Bus Flow" "From Bus Flow" "To Bus Flow" "To Bus Flow" "Branch Injection" "Loss" "Loss"]
    generator = ["Bus" "Generation" "Generation"]

    busu = ["" "Magnitude [p.u.]" "Angle [deg]" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]"]
    branchu = ["" "" "" "Active Power [MW]" "Active Power [MW]" "Active Power [MW]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]"]
    generatoru = ["" "Active Power [MW]" "Reactive Power [MVAr]"]

    header1 = [bus, branch, generator]
    header2 = [busu, branchu, generatoru]

    return header1, header2
end
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
function generator_headers()
    act = "Active Power [MW]"; rea = "Reactive Power [MVAr]"
    pmuVoltage = ["Bus" "Measurement" "Noise" "Status" "Measurement" "Noise" "Status" "Exact" "Exact"]
    pmuCurrent = ["Branch" "From Bus" "To Bus" "Measurement" "Noise" "Status" "Measurement" "Noise" "Status" "Exact" "Exact"]
    legFlow = ["Branch" "From Bus" "To Bus" "Measurement" "Noise" "Status" "Measurement" "Noise" "Status" "Exact" "Exact"]
    legCurrent = ["Branch" "From Bus" "To Bus" "Measurement" "Noise" "Status" "Exact"]
    legInjection = ["Bus" "Measurement" "Noise" "Status" "Measurement" "Noise" "Status" "Exact" "Exact"]
    legVoltage = ["Bus" "Measurement" "Noise" "Status" "Exact"]
    bus = ["Bus" "Type" "Demand" "Demand" "Shunt Conductance" "Shunt Susceptance" "Area" "Voltage" "Voltage" "Base Voltage" "Loss Zone" "Maximum Voltage" "Minimum Voltage"]
    generator = ["Bus" "Generation" "Generation" "Maximum Generation" "Minimum Generation" "Voltage" "Total Base" "Status" "Maximum Generation" "Minimum Generation" "Lower of PQ Curve" "Uppert of PQ Curve" "Minimum at PC1" "Maximum at PC1" "Minimum at PC2" "Maximum at PC2" "Ramp Rate" "Ramp Rate" "Ramp Rate" "Ramp Rate" "Area Factor"]
    branch = ["Branch" "From Bus" "To Bus" "Resistance" "Reactance" "Charging Susceptance" "Rating A" "Rating B" "Rating C" "Transformer" "Transformer" "Status" "Minimum Angle" "Maximum Angle"]
    base = ["Base Power"]

    pmuVoltageu = ["" "Magnitude [p.u.]" "Variance [p.u.]" "" "Angle [rad]" "Variance [p.u.]" "" "Magnitude [p.u.]" "Angle [rad]"]
    pmuCurrentu = ["" "" "" "Magnitude [p.u.]" "Variance [p.u.]" "" "Angle [rad]" "Variance [p.u.]" "" "Magnitude [p.u.]" "Angle [rad]"]
    legFlowu = ["" "" "" "Active Power [p.u.]" "Variance [p.u.]" "" "Reactive Power [p.u.]" "Variance [p.u.]" "" "Active Power [p.u.]" "Reactive Power [p.u.]"]
    legCurrentu = ["" "" "" "Magnitude [p.u.]" "Variance [p.u.]" "" "Magnitude [p.u.]"]
    legInjectionu = ["" "Active Power [p.u.]" "Variance [p.u.]" "" "Reactive Power [p.u.]" "Variance [p.u.]" "" "Active Power [p.u.]" "Reactive Power [p.u.]"]
    legVoltageu = ["" "Magnitude [p.u.]" "Variance [p.u.]" "" "Magnitude [p.u.]"]
    busu = ["" "" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "" "Magnitude [p.u.]" "Angle [deg]" "Magnitude [kV]" "" "Magnitude [p.u.]" "Magnitude [p.u.]"]
    generatoru = ["" "" "Active Power [MW]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Magnitude [p.u.]" "Power [MVA]" "" "Active Power [MW]" "Active Power [MW]" "Active Power [MW]" "Active Power [MW]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Load AGC [MW/min]" "10 minute reserves [MW]" "30 minute reserves [MW]" "Reactive Power (2 sec Timescale) [MVAr/min]"]
    branchu = ["" "" "" "[p.u.]" "[p.u.]" "[p.u.]" "Long Term" "Short Term" "Emergency" "Turns Ratio" "Shift Angle [deg]" "" "Difference" "Difference"]
    baseu = ["Power [MVA]"]

    header1 = [pmuVoltage, pmuCurrent, legFlow, legCurrent, legInjection, legVoltage, bus, generator, branch, base]
    header2 = [pmuVoltageu, pmuCurrentu, legFlowu, legCurrentu, legInjectionu, legVoltageu, busu, generatoru, branchu, baseu]
    group = ["pmuVoltage", "pmuCurrent", "legacyFlow", "legacyCurrent", "legacyInjection", "legacyVoltage", "bus", "generator", "branch", "basePower"]

    return header1, header2, group
end
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
function info_flow(system, settings)
    reference = "Reference: unknown"
    grid = "Grid: unknown"
    for i in system.info
        if occursin("Reference", i)
            reference = i
        end
        if occursin("Grid", i)
            grid = i
        end
    end
    info = [reference "";
            grid "";
            string("Algorithm: ", settings.algorithm) "";
            "" "";
            "Bus number" size(system.bus, 1);
            "Generator number" size(system.generator, 1);
            "Generator in-service" sum(system.generator[:, 8]);
            "Branch number" size(system.branch, 1);
            "Branch in-service" sum(system.branch[:, 12])]

    return info
end
#-------------------------------------------------------------------------------
