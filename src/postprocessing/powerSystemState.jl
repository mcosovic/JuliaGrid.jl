"""
The function computes powers and currents related to branches for the AC power flow analysis.
For the DC power flow analysis, the function computes only active powers.

    branch!(system::PowerSystem, result::Result)

The function updates the field `result.branch` of the composite type `Result`.

# Examples
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

result = gaussSeidel(system)
stopping = result.algorithm.iteration.stopping
for i = 1:200
    gaussSeidel!(system, result)
    if stopping.active < 1e-8 && stopping.reactive < 1e-8
        break
    end
end

branch!(system, result)
```

```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

result = dcPowerFlow(system)
branch!(system, result)
```
"""
function branch!(system::PowerSystem, result::Result)
    if result.algorithm.method == "DC Power Flow"
        dcBranch!(system, result)
    end

    if result.algorithm.method in ["Gauss-Seidel", "Newton-Raphson", "Fast Newton-Raphson BX", "Fast Newton-Raphson XB"]
        acBranch!(system, result)
    end

end

function dcBranch!(system::PowerSystem, result::Result)
    dc = system.dcModel
    branch = system.branch

    power = result.branch.power
    voltage = result.bus.voltage
    errorVoltage(voltage.angle)

    power.fromBus.active = copy(dc.admittance)
    power.toBus.active = similar(dc.admittance)
    @inbounds for i = 1:branch.number
        power.fromBus.active[i] *= (voltage.angle[branch.layout.from[i]] - voltage.angle[branch.layout.to[i]] - branch.parameter.shiftAngle[i])
        power.toBus.active[i] = -power.fromBus.active[i]
    end
end

function acBranch!(system::PowerSystem, result::Result)
    ac = system.acModel

    voltage = result.bus.voltage
    current = result.branch.current
    power = result.branch.power
    errorVoltage(voltage.magnitude)

    power.fromBus.active = fill(0.0, system.branch.number)
    power.fromBus.reactive = fill(0.0, system.branch.number)
    power.toBus.active = fill(0.0, system.branch.number)
    power.toBus.reactive = fill(0.0, system.branch.number)
    power.shunt.reactive = fill(0.0, system.branch.number)
    power.loss.active = fill(0.0, system.branch.number)
    power.loss.reactive = fill(0.0, system.branch.number)

    current.fromBus.magnitude = fill(0.0, system.branch.number)
    current.fromBus.angle = fill(0.0, system.branch.number)
    current.toBus.magnitude = fill(0.0, system.branch.number)
    current.toBus.angle = fill(0.0, system.branch.number)
    current.impedance.magnitude = fill(0.0, system.branch.number)
    current.impedance.angle = fill(0.0, system.branch.number)

    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            f = system.branch.layout.from[i]
            t = system.branch.layout.to[i]

            voltageFrom = voltage.magnitude[f] * exp(im * voltage.angle[f])
            voltageTo = voltage.magnitude[t] * exp(im * voltage.angle[t])

            currentFromBus = voltageFrom * ac.nodalFromFrom[i] + voltageTo * ac.nodalFromTo[i]
            current.fromBus.magnitude[i] = abs(currentFromBus)
            current.fromBus.angle[i] = angle(currentFromBus)

            currentToBus = voltageFrom * ac.nodalToFrom[i] + voltageTo * ac.nodalToTo[i]
            current.toBus.magnitude[i] = abs(currentToBus)
            current.toBus.angle[i] = angle(currentToBus)

            currentImpedance = ac.admittance[i] * (voltageFrom / ac.transformerRatio[i] - voltageTo)
            current.impedance.magnitude[i] = abs(currentImpedance)
            current.impedance.angle[i] = angle(currentImpedance)

            powerFromBus = voltageFrom * conj(currentFromBus)
            power.fromBus.active[i] = real(powerFromBus)
            power.fromBus.reactive[i] = imag(powerFromBus)

            powerToBus = voltageTo * conj(currentToBus)
            power.toBus.active[i] = real(powerToBus)
            power.toBus.reactive[i] = imag(powerToBus)

            power.shunt.reactive[i] = 0.5 * system.branch.parameter.susceptance[i] * (abs(voltageFrom / ac.transformerRatio[i])^2 +  voltage.magnitude[t]^2)

            power.loss.active[i] = current.impedance.magnitude[i]^2 * system.branch.parameter.resistance[i]
            power.loss.reactive[i] = current.impedance.magnitude[i]^2 * system.branch.parameter.reactance[i]
        end
    end
end


# ######### Bus Results ##########
# function bus!(system::PowerSystem, result::DCResult)
#     dc = system.dcModel
#     bus = system.bus
#     slack = bus.layout.slackIndex

#     power = result.bus.power
#     voltage = result.bus.voltage
#     errorVoltage(voltage.angle)

#     power.supply.active = copy(bus.supply.active)
#     power.injection.active = copy(bus.supply.active)
#     @inbounds for i = 1:bus.number
#         power.injection.active[i] -= bus.demand.active[i]
#     end

#     power.injection.active[slack] = bus.shunt.conductance[slack] + dc.shiftActivePower[slack]
#     @inbounds for j in dc.nodalMatrix.colptr[slack]:(dc.nodalMatrix.colptr[slack + 1] - 1)
#         row = dc.nodalMatrix.rowval[j]
#         power.injection.active[slack] += dc.nodalMatrix[row, slack] * voltage.angle[row]
#     end
#     power.supply.active[slack] = bus.demand.active[slack] + power.injection.active[slack]
# end

# ######### Generator Results ##########
# function generator!(system::PowerSystem, result::DCResult)
#     dc = system.dcModel
#     generator = system.generator
#     bus = system.bus
#     slack = bus.layout.slackIndex

#     power = result.generator.power
#     voltage = result.bus.voltage
#     errorVoltage(voltage.angle)

#     if isempty(result.bus.power.supply.active)
#         supplySlack = bus.demand.active[slack] + bus.shunt.conductance[slack] + dc.shiftActivePower[slack]
#         @inbounds for j in dc.nodalMatrix.colptr[slack]:(dc.nodalMatrix.colptr[slack + 1] - 1)
#             row = dc.nodalMatrix.rowval[j]
#             supplySlack += dc.nodalMatrix[row, slack] * voltage.angle[row]
#         end
#     else
#         supplySlack = result.bus.power.supply.active[slack]
#     end

#     power.active = fill(0.0, generator.number)
#     tempSlack = 0
#     @inbounds for i = 1:generator.number
#         if generator.layout.status[i] == 1
#             power.active[i] = generator.output.active[i]

#             if generator.layout.bus[i] == slack
#                 if tempSlack != 0
#                     power.active[tempSlack] -= power.active[i]
#                 end
#                 if tempSlack == 0
#                     power.active[i] = supplySlack
#                     tempSlack = i
#                 end
#             end
#         end
#     end
# end