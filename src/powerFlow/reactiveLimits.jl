"""
The function checks the reactive power limits of the generators. More precisely,
after the bus voltage magnitudes and angles have been determined, the function
sets the reactive power of the generators within the limits if they are violated,
and corresponding PV buses or the slack bus will be converted to PQ buses.

The function returns the variable `violate` to indicate on which buses the limits
are violated. If the minimum limits are violated, the mark -1 will appear in the
appropriate place, and the violation of the maximum limits is marked with 1.

    reactivePowerLimit!(system::PowerSystem, result::Result)

First, in case the function [`generator!()`](@ref generator!) is not executed, the
function will trigger the execution of this function and will update the field
`result.generator`.

Then, the function sets variables `system.generator.output.active` and
`system.bus.supply.active` based on the results obtained by the function
[`generator!()`](@ref generator!).

Finally, the function checks the generator reactive powers, and if they are violated,
it sets them to maximum or minimum values, thus updating the variable
`system.generator.output.reactive`. Based on this, the variable `system.bus.supply.reactive`
is updated, and the bus types in the variable `system.bus.layout.type` is changed.

For the case when the slack bus is converted the function updates the field
`system.bus.layout.slackIndex`.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

result = newtonRaphson(system)
stopping = result.algorithm.iteration.stopping
for i = 1:200
    newtonRaphson!(system, result)
    if stopping.active < 1e-8 && stopping.reactive < 1e-8
        break
    end
end

violate = reactivePowerLimit!(system, result)

result = newtonRaphson(system)
stopping = result.algorithm.iteration.stopping
for i = 1:200
    newtonRaphson!(system, result)
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

    violate = fill(0, generator.number)
    if isempty(power.reactive)
        generator!(system, result)
    end

    bus.supply.active = fill(0.0, bus.number)
    bus.supply.reactive = fill(0.0, bus.number)
    @inbounds for (k, i) in enumerate(generator.layout.bus)
        if generator.layout.status[k] == 1
            generator.output.active[k] = power.active[k]
            bus.supply.active[i] += power.active[k]
            bus.supply.reactive[i] += power.reactive[k]
        end
    end

    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            j = generator.layout.bus[i]

            violateMinimum = power.reactive[i] < generator.capability.minReactive[i]
            violateMaximum = power.reactive[i] > generator.capability.maxReactive[i]
            if  bus.layout.type[j] != 1 && (violateMinimum || violateMaximum)
                if violateMinimum
                    violate[i] = -1
                    newReactivePower = generator.capability.minReactive[i]
                end
                if violateMaximum
                    violate[i] = 1
                    newReactivePower = generator.capability.maxReactive[i]
                end
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

    return violate
end

"""
The function adjust bus voltage angles according to the original slack bus. More precisely,
in the case when the reactive power of the generator is beyond the limit on the slack bus,
the function [`reactivePowerLimit!()`](@ref reactivePowerLimit!) will convert that bus into
PQ bus, and declare the first PV bus in the list as the new slack bus. Then, after the new
AC power flow solution is determined, it is possible to correct the voltage angles, so that
their values are in accordance with the angle of the original slack bus.

    adjustVoltageAngle!(system::PowerSystem, result::Result)

The function updates field `result.bus.voltage.angle`.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

result = newtonRaphson(system)
stopping = result.algorithm.iteration.stopping
for i = 1:200
    newtonRaphson!(system, result)
    if stopping.active < 1e-8 && stopping.reactive < 1e-8
        break
    end
end

reactivePowerLimit!(system, result)

result = newtonRaphson(system)
stopping = result.algorithm.iteration.stopping
for i = 1:200
    newtonRaphson!(system, result)
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