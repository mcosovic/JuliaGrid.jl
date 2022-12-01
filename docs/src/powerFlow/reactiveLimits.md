# [Generator Reactive Power Limits](@id generatorReactivePowerLimits)

By default, the AC power flow methods solve the system of non-linear equations and reveal bus voltage magnitudes and angles ignoring any limits. However, JuliaGrid provides a function [`reactivePowerLimit!()`](@ref reactivePowerLimit!) that checks reactive power limits.
```@docs
reactivePowerLimit!
```

---

Furthermore, if there is a slack bus conversion, it is possible to adjust the voltage angles according to the original slack bus.
```@docs
adjustVoltageAngle!
```