"""
The function checks reactive power limits of the generators. More precisely,
after the AC power flow analysis is done, all generators that violated reactive
power limits are placed at their limits, and corresponding PV buses or slack
bus are converted to PQ.

    reactivePowerLimit!(system::PowerSystem, result::Result)

The function updates fields `generator.layout.violate`, `generator.output.reactive`,
`bus.supply.reactive`, and `bus.layout.type` of the composite type `System`. Also,
for the case when the slack bus is converted the function updates field
`bus.layout.slackIndex` of the composite type `System`. In addition, in case the function
`generator!()` is not executed, the function `reactivePowerLimit!()` will trigger the execution
of the function `generator!()` and updates field `generator` of the composite type `Result`.

# Example
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

reactivePowerLimit!(system, result)

result = gaussSeidel(system)
stopping = result.algorithm.iteration.stopping
for i = 1:200
    gaussSeidel!(system, result)
    if stopping.active < 1e-8 && stopping.reactive < 1e-8
        break
    end
end
```
"""
function reactivePowerLimit!(system::PowerSystem, result::Result)
    bus = system.bus
    generator = system.generator

    power = result.generator.power
    errorVoltage(result.bus.voltage.magnitude)

    generator.layout.violate = fill(0, generator.number)
    if isempty(power.reactive)
        generator!(system, result)
    end

    bus.supply.active = fill(0.0, bus.number)
    bus.supply.reactive = fill(0.0, bus.number)
    @inbounds for (k, i) in enumerate(generator.layout.bus)
        if generator.layout.status[k] == 1
            bus.supply.active[i] += power.active[k]
            bus.supply.reactive[i] += power.reactive[k]
        end
    end

    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            violateMinimum = power.reactive[i] < generator.capability.minReactive[i]
            violateMaximum = power.reactive[i] > generator.capability.maxReactive[i]
            if generator.layout.violate[i] == 0 && (violateMinimum || violateMaximum)
                if violateMinimum
                    generator.layout.violate[i] = -1
                    newReactivePower = generator.capability.minReactive[i]
                end
                if violateMaximum
                    generator.layout.violate[i] = 1
                    newReactivePower = generator.capability.maxReactive[i]
                end
                j = generator.layout.bus[i]
                bus.layout.type[j] = 1

                bus.supply.reactive[j] -= result.generator.power.reactive[i]
                generator.output.reactive[i] = newReactivePower
                bus.supply.reactive[j] += newReactivePower

                if j == bus.layout.slackIndex
                    for k = 1:bus.number
                        if bus.layout.type[k] == 2
                            @info("The slack bus $(trunc(Int, bus.label[j])) is converted to PQ bus, bus $(trunc(Int, bus.label[k])) is the new slack bus.")
                            bus.layout.slackIndex = bus.label[k]
                            bus.layout.type[k] = 3
                            break
                        end
                    end
                end
            end
        end
    end
end

"""
The function adjust bus voltage angles according to the original slack bus.
More precisely, if the function `reactivePowerLimit!()` converts the slack bus
to PQ bus, a new slack bus will be defined during this conversion. Then, using
this function, it is possible to adjust the voltage angles in relation to the
original slack bus.

    adjustVoltageAngle!(system::PowerSystem, result::Result)

The function updates field `bus.voltage.angle` of the composite type `Result`.

# Example
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

reactivePowerLimit!(system, result)

result = gaussSeidel(system)
stopping = result.algorithm.iteration.stopping
for i = 1:200
    gaussSeidel!(system, result)
    if stopping.active < 1e-8 && stopping.reactive < 1e-8
        break
    end
end

adjustVoltageAngle!(system, result)
```
"""
function adjustVoltageAngle!(system::PowerSystem, result::Result)
    T = system.bus.voltage.angle[system.bus.layout.slackImmutable] - result.bus.voltage.angle[system.bus.layout.slackImmutable]
    @inbounds for i = 1:system.bus.number
        result.bus.voltage.angle[i] = result.bus.voltage.angle[i] + T
    end
end