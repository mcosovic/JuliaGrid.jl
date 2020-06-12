### Export Data to HDF5

using HDF5


### Power System Data
function powesystem()
    reference = "https://labs.ece.uw.edu/pstca/pf14/pg_tca14bus.htm"
    grid = "transmission"
    name = "case14"

    basePower = 100

    bus = [1	3   0	    0      0	0	1	1.06	 0	    0	1	1.06	0.94
    	   2	2   21.7	12.7   0	0	1	1.045	-4.98	0	1	1.06	0.94
    	   3	2	94.2	19     0	0	1	1.01	-12.72	0	1	1.06	0.94
    	   4	1	47.8   -3.9    0	0	1	1.019	-10.33	0	1	1.06	0.94
    	   5	1	7.6	    1.6	   0	0	1	1.02	-8.78	0	1	1.06	0.94
    	   6	2	11.2	7.5    0	0	1	1.07	-14.22	0	1	1.06	0.94
    	   7	1	0	    0      0	0	1	1.062	-13.37	0	1	1.06	0.94
    	   8	2	0	    0      0	0	1	1.09	-13.36	0	1	1.06	0.94
    	   9	1	29.5	16.6   0	19	1	1.056	-14.94	0	1	1.06	0.94
    	  10	1	9	    5.8	   0	0	1	1.051	-15.1	0	1	1.06	0.94
    	  11	1	3.5	    1.8	   0	0	1	1.057	-14.79	0	1	1.06	0.94
    	  12	1	6.1	    1.6	   0	0	1	1.055	-15.07	0	1	1.06	0.94
    	  13	1	13.5	5.8	   0	0	1	1.05	-15.16	0	1	1.06	0.94
    	  14	1	14.9	5	   0	0	1	1.036	-16.04	0	1	1.06	0.94]

    branch = [1     1	   2	0.01938	 0.05917	0.0528	0	0	0	0	   0	1	-360	360
    	      2     1	   5	0.05403	 0.22304	0.0492	0	0	0	0	   0	1	-360	360
    	      3     2	   3	0.04699	 0.19797	0.0438	0	0	0	0	   0	1	-360	360
    	      4     2	   4	0.05811	 0.17632	0.034	0	0	0	0      0	1	-360	360
              5     2	   5	0.05695	 0.17388	0.0346	0	0	0	0	   0	1	-360	360
              6     3	   4	0.06701	 0.17103	0.0128	0	0	0	0	   0	1	-360	360
              7     4	   5	0.01335	 0.04211	0	    0	0	0	0	   0	1	-360	360
              8     4	   7	0	     0.20912	0	    0	0	0	0.978  0	1	-360	360
              9     4	   9	0	     0.55618	0	    0	0	0	0.969  0	1	-360	360
              10    5	   6	0	     0.25202	0	    0	0	0	0.932  0	1	-360	360
              11    6	  11	0.09498	 0.1989	    0	    0	0	0	0	   0	1	-360	360
              12    6	  12	0.12291	 0.25581	0	    0	0	0	0	   0	1	-360	360
              13    6	  13	0.06615	 0.13027	0	    0	0	0	0	   0	1	-360	360
              14    7	   8	0	     0.17615	0	    0	0	0	0	   0	1	-360	360
              15    7	   9	0	     0.11001	0	    0	0	0	0	   0	1	-360	360
              16    9	  10	0.03181	 0.0845	    0	    0	0	0	0	   0	1	-360	360
              17    9	  14	0.12711	 0.27038	0	    0	0	0	0	   0	1	-360	360
              18    10    11	0.08205	 0.19207	0	    0	0	0	0	   0	1	-360	360
              19    12    13	0.22092	 0.19988	0	    0	0	0	0	   0	1	-360	360
              20    13    14	0.17093	 0.34802	0	    0	0	0	0	   0	1	-360	360]

    generator = [1	232.4  -16.9	10	 0	 1.06	100	 1	332.4	0	0	0	0	0	0	0	0	0	0	0	0
              	 2	40	    42.4	50	-40	 1.045	100	 1	140	    0	0	0	0	0	0	0	0	0	0	0	0
              	 3	0	    23.4	40	 0	 1.01	100	 1	100	    0	0	0	0	0	0	0	0	0	0	0	0
              	 6	0	    12.2	24	-6	 1.07	100	 1	100	    0	0	0	0	0	0	0	0	0	0	0	0
              	 8	0	    17.4	24	-6	 1.09	100	 1 	100	    0	0	0	0	0	0	0	0	0	0	0	0]

    generatorcost = [2  0	0	3	0.0430292599	20	 0
             	     2	0	0	3	0.25	        20	 0
             	     2	0	0	3	0.01	        40	 0
             	     2	0	0	3	0.01	        40	 0
             	     2	0	0	3	0.01	        40	 0]

    return bus, branch, generator, generatorcost, basePower, reference, grid, name
end


### Save Data to HDF5
function savetoHDF5(ARGS...; reference = "", grid = "", path = "", name = "")
    busi = ["Bus" "Type" "Demand" "Demand" "Shunt Conductance" "Shunt Susceptance" "Area" "Voltage" "Voltage" "Base Voltage" "Loss Zone" "Maximum Voltage" "Minimum Voltage"]
    generatori = ["Bus" "Generation" "Generation" "Maximum Generation" "Minimum Generation" "Voltage" "Base" "Status" "Maximum Generation" "Minimum Generation" "Lower of PQ Curve" "Upper of PQ Curve" "Minimum at PC1" "Maximum at PC1" "Minimum at PC2" "Maximum at PC2" "Ramp Rate ACG" "Ramp Rate 10" "Ramp Rate 30" "Ramp Rate Q" "Area Factor"]
    branchi = ["Branch" "From Bus" "To Bus" "Series Parameter" "Series Parameter" "Charging Parameter" "Long Term Rate" "Short Term Rate" "Emergency Rate" "Transformer" "Transformer" "Status" "Minimum Voltage Difference" "Maximum Voltage Difference"]
    basei = ["Base Power"]

    busu = ["Integer" "PQ(1), PV(2), Slack(3)" "Active Power [MW]" "Reactive Power [MVAr]" "Active Power [MW]" "Reactive Power [MVAr]" "Integer" "Magnitude [p.u.]" "Angle [deg]" "Magnitude [kV]" "Integer" "Magnitude [p.u.]" "Magnitude [p.u.]"]
    generatoru = ["Integer" "Active Power [MW]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Magnitude [p.u.]" "Power [MVA]" "Integer" "Active Power [MW]" "Active Power [MW]" "Active Power [MW]" "Active Power [MW]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Reactive Power [MVAr]" "Active Power per Minut [MW/min]" "Active Power [MW]" "Active Power [MW]" "Reactive Power per Minut [MVAr/min]" "Integer"]
    branchu = ["Integer" "Integer" "Integer" "Resistance [p.u.]" "Reactance [p.u.]" "Susceptance [p.u.]" "Power [MVA]" "Power [MVA]" "Power [MVA]" "Turns Ratio" "Shift Angle [deg]" "Integer" "Angle [deg]" "Angle [deg]"]
    baseu = ["Power [MVA]"]

    generatorcosti = ["Cost Model" "Cost" "Cost" "Cost Model"]
    generatorcostu = ["Piecewise(1), Polynomial(2)" "Startup [currency]" "Shutdown [currency]" "Number of Data Points"]
    generatorcosta = ["Cost Model" for n = 1:generatorcost[1, 4]]
    generatorcostb = ["Coefficient c$(trunc(Int, (n-1)))" for n = generatorcost[1, 4]:-1:1]
    generatorcosti = [generatorcosti hcat(generatorcosta...)]
    generatorcostu = [generatorcostu hcat(generatorcostb...)]

    header1 = [busi, branchi, generatori, generatorcosti, basei]
    header2 = [busu, branchu, generatoru, generatorcostu, baseu]
    group = ["bus", "branch", "generator", "generatorcost", "basePower"]

    Nbus = size(bus, 1); Nbranch = size(branch, 1); Ngen = size(generator, 1)
    Ntrain = 0; Ntra = 0; pv = 0
    for i = 1:Nbranch
        if branch[i, 12] == 1 && (branch[i, 10] != 0 || branch[i, 11] != 0)
            Ntrain += 1
        end
        if branch[i, 10] != 0 || branch[i, 11] != 0
            Ntra += 1
        end
    end
    pv = length(unique(generator[:, 1]))

    info = [["Reference" string(reference) ""]
            ["Data" string(name) ""]
            ["Grid" string(grid) ""]
            ["" "" ""]
            ["Bus" string(Nbus) ""]
            ["PV bus" string(pv) ""]
            ["PQ bus" string(Nbus - pv - 1) ""]
            ["Shunt element" string(count(x->x != 0, abs.(bus[:, 5]) + abs.(bus[:, 6]))) ""]
            ["Generator" string(Ngen) "$(trunc(Int, sum(generator[:, 8]))) in-service"]
            ["Branch" string(Nbranch) "$(trunc(Int, sum(branch[:, 12]))) in-service"]
            ["Transformer" string(Ntra) "$Ntrain in-service"]]

    path = joinpath(path, string(name, ".h5"))
    h5open(path, "w") do file
        for i = 1:length(ARGS)
            write(file, group[i], ARGS[i])
            atr = Dict(string("row", k) => if !isempty(header2[i][k]) string(s, ": ", header2[i][k]) else s end for (k, s) in enumerate(header1[i]))
            h5writeattr(path, group[i], atr)
        end
        write(file, "info", info)
    end
end

### Run
pathtosave = "D:/Dropbox/"
bus, branch, generator, generatorcost, basePower, reference, grid, name = powesystem()
savetoHDF5(bus, branch, generator, generatorcost, basePower; reference = reference, grid = grid, name = name, path = pathtosave)
