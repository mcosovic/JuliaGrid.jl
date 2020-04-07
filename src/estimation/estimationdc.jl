###################
#  DC Power Flow  #
###################


#-------------------------------------------------------------------------------
function rundcse(settings, system, measurement)
    busi, fromi, toi, reactance, transTap, transShift, fromPij, toPij, zPij, vPij, onPij,
           busPi, zPi, vPi, onPi, busTi, zTi, vTi, onTi, Pshift, Ydiag, admitance, label = view_dcsystem(system, measurement)

    numbering = false
    Nbus = size(system.bus, 1)
    Nbranch = size(system.branch, 1)
    bus = collect(1:Nbus)

    @inbounds for i = 1:Nbus
        if bus[i] != busi[i]
            numbering = true
        end
    end

    # busPi = numbering_generator(busPi, busi, Nbus, bus, numbering)
    # busTi = numbering_generator(busTi, busi, Nbus, bus, numbering)
    # from, to = numbering_branch(fromi, toi, busi, Nbranch, Nbus, bus, numbering)
    # fromPij, toPij = numbering_branch(fromPij, toPij, busi, Nbranch, Nbus, bus, numbering)






    @inbounds for i = 1:Nbranch
        if transTap[i] == 0
            admitance[i] = 1 / reactance[i]
        else
            admitance[i] = 1 / (transTap[i] * reactance[i])
        end

        shift = (pi / 180) * transShift[i] * reactance[i]
        Pshift[from[i]] -= shift
        Pshift[to[i]] += shift

        Ydiag[from[i]] += admitance[i]
        Ydiag[to[i]] += admitance[i]
    end


    NPij = length(zPij)
    NPij_on = 0
    for i = 1:NPij
        if onPij[i] == 1
           NPij_on += 1
        end
    end



    # fromPij_on = fill(0, NPij_on)
    # toPij_on = similar(fromPij_on)
    # admitancePij = fill(0.0, NPij_on)
    # cnt = 1
    # for i = 1:NPij
    #     if onPij[i] == 1
    #        fromPij_on[cnt] = fromPij[i]
    #        toPij_on[cnt] = toPij[i]
    #         for j = 1:Nbranch
    #             if fromPij[i] == fromi[j] && toPij[i] == toi[j] || toPij[i] == fromi[j] && fromPij[i] == toi[j]
    #                 if transTap[j] == 0
    #                     admitancePij[cnt] = 1 / reactance[j]
    #                 else
    #                     admitancePij[cnt] = 1 / (transTap[j] * reactance[j])
    #                 end
    #                 cnt += 1
    #                 break
    #             end
    #         end
    #     end
    # end

    # NTi = length(zTi)
    # NTi_on = 0
    # for i = 1:NTi
    #     if onTi[i] == 1
    #        NTi_on += 1
    #     end
    # end
    # coeffTi = fill(0.0, NTi_on)
    # colTi = fill(0, NTi_on)
    # cnt = 1
    # for i = 1:NTi
    #     if onTi[i] == 1
    #        colTi[cnt] = busTi[i]
    #        cnt += 1
    #     end
    # end
    #
    # NPi = length(zPi)
    # NPi_on = 0
    # for i = 1:NPi
    #     if onPi[i] == 1
    #        NPi_on += 1
    #     end
    # end



    # row = collect(1:NPij_on)
    # row1 = collect(2*NPij_on+1:2*NPij_on+1+NTi_on)
    # Ybus = sparse([row; row; row1], [fromPij_on; toPij_on; colTi], [admitancePij; -admitancePij; ones(colTi,1)], nPijOn, Nbus)
    # display(Matrix(Ybus))
    # nTi = length(zTi)
    # nTiservice = 0
    # for i = 1:nTi
    #     if Tion[i] == 1
    #        nTiservice += 1
    #     end
    # end
    # rowTi = fill(0, Nbranch)
    # colTi = similar(rowTi)
    # cnt = 1
    # for i = 1:nTi
    #     if Tion[i] == 1
    #        rowTi[cnt] = cnt
    #        colTi[cnt] = busTi[i]
    #        cnt += 1
    #    end
    # end





    # nPi = length(zPi)
    # nPiservice = 0
    # for i = 1:nPi
    #     if Pion[i] == 1
    #        nPiservice += 1
    #     end
    # end
    # rowPi = fill(0, Nbranch + Nbus)
    # colTi = similar(Nbranch + Nbus)
    # cnt = 1
    # for i = 1:nPi
    #     if Tion[i] == 1
    #        rowPi[cnt] = cnt
    #        colPi[cnt] = busTi[i]
    #        cnt += 1
    #    end
    # end

    # for i = 1:NPi
    #     if Pion[i] == 1
    #       Nservice += 1
    #     end
    # end
    # for i = 1:NPij
    #     if Pijon[i] == 1
    #        Nservice += 1
    #     end
    # end


    # label = collect(1:2*Nbranch)
    # for i = 1:NPij
    #     for j = 1:Nbranch
    #         if fromPij[i] == fromi[j] && toPij[i] == toi[j]
    #             labelPij[i] = label[j]
    #             break
    #         end
    #         if toPij[i] == fromi[j] && fromPij[i] == toi[j]
    #             labelPij[i] = label[j]
    #             break
    #         end
    #     end
    # end









    # Nti = 0
    # Npi =
    # for i = 1:Nbus
    #     if Tion[i] == 1
    #         Nti += 1
    #     end
    #     if Pion[i] == 1
    #         Npi += 1
    #     end
    # end
    #
    # Npij = 0
    # for i = 1:2*Nbranch
    #     if Pijon[i] == 1
    #         Npij += 1
    #     end
    # end
    #
    # h = fill(0.0, Nti + Npi + Npij)
    #
    # for i = 1:Nti + Npi + Npij
    #     if Pion[i] == 1
    #
    #     end
    #
    # end

    return measurement
end
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
function view_dcsystem(system, measurement)
    # Read Data
    fromPij = @view(measurement.legFlow[:, 1])
    toPij = @view(measurement.legFlow[:, 2])
    zPij = @view(measurement.legFlow[:, 3])
    vPij = @view(measurement.legFlow[:, 4])
    onPij = @view(measurement.legFlow[:, 5])

    busPi = @view(measurement.legInjection[:, 1])
    zPi = @view(measurement.legInjection[:, 2])
    vPi = @view(measurement.legInjection[:, 3])
    onPi = @view(measurement.legInjection[:, 4])

    busTi = @view(measurement.pmuVoltage[:, 1])
    zTi = @view(measurement.pmuVoltage[:, 5])
    vTi = @view(measurement.pmuVoltage[:, 6])
    onTi = @view(measurement.pmuVoltage[:, 7])

    busi = @view(system.bus[:, 1])
    fromi = @view(system.branch[:, 1])
    toi = @view(system.branch[:, 2])
    reactance = @view(system.branch[:, 4])
    transTap = @view(system.branch[:, 9])
    transShift = @view(system.branch[:, 10])

    # Write Data
    Pshift = @view(system.bus[:, 12])
    Ydiag = @view(system.bus[:, 13])

    admitance = @view(system.branch[:, 4]);
    label = @view(measurement.legFlow[:, 6])

    return busi, fromi, toi, reactance, transTap, transShift, fromPij, toPij, zPij, vPij, onPij,
           busPi, zPi, vPi, onPi, busTi, zTi, vTi, onTi, Pshift, Ydiag, admitance, label

end
#-------------------------------------------------------------------------------
