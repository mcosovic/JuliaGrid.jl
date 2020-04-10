#######################
#  Service Functions  #
#######################


#-------------------------------------------------------------------------------
function info_flow(system, settings, Nbranch, Nbus, Ngen)
    reference = "unknown"
    grid = "unknown"
    for (k, i) in enumerate(system.info[:, 1])
        if occursin("Reference", i)
            reference = system.info[k, 2]
        end
        if occursin("Grid", i)
            grid = system.info[k, 2]
        end
    end

    Ntrain = 0
    Ntra = 0
    for i = 1:Nbranch
        if system.branch[i, 12] == 1 && (system.branch[i, 10] != 0 || system.branch[i, 11] != 0)
            Ntrain += 1
        end
        if system.branch[i, 10] != 0 || system.branch[i, 11] != 0
            Ntra += 1
        end
    end
    info = ["Reference" string(reference) "";
            "Data" string(system.data) "";
            "Grid" string(grid) "";
            "" "" "";
            "Bus" string(Nbus) "";
            "PV bus" string(length(unique(system.generator[:, 1]))) "";
            "PQ bus" string(Nbus - length(unique(system.generator[:, 1])) - 1) "";
            "Shunt element" string(count(x->x != 0, abs.(system.bus[:, 5]) + abs.(system.bus[:, 6]))) "";
            "Generator" string(Ngen) string(trunc(Int, sum(system.generator[:, 8])), " in-service");
            "Branch" string(Nbranch) string(trunc(Int, sum(system.branch[:, 12])), " in-service");
            "Transformer" string(Ntra) string(Ntrain, " in-service")]
    return info
end
#-------------------------------------------------------------------------------
