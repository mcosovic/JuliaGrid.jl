# [Power Flow Solution](@id powerFlowSolutionAPI)

For further information on this topic, please see the [Power System Analysis](@ref PowerSystemModelManual) section of the Manual.

---

## API Index

###### Newton Raphson Method
* [`newtonRaphson`](@ref newtonRaphson)
* [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson))
* [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson))

###### Fast Newton Raphson Method
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB)
* [`mismatch!`](@ref mismatch!(::PowerSystem, ::FastNewtonRaphson))
* [`solve!`](@ref solve!(::PowerSystem, ::FastNewtonRaphson))

###### Gauss-Seidel Method
* [`gaussSeidel`](@ref gaussSeidel)
* [`mismatch!`](@ref mismatch!(::PowerSystem, ::GaussSeidel))
* [`solve!`](@ref solve!(::PowerSystem, ::GaussSeidel))

###### Power and Current Analysis
* [`analysisBus`](@ref analysisBus(::PowerSystem, ::ACPowerFlow))
* [`analysisBranch`](@ref analysisBranch(::PowerSystem, ::ACPowerFlow))
* [`analysisGenerator`](@ref analysisGenerator(::PowerSystem, ::ACPowerFlow))

###### Additional Functions
* [`reactiveLimit!`](@ref reactiveLimit!)
* [`adjustAngle!`](@ref adjustAngle!)

###### DC Power Flow
* [`dcPowerFlow`](@ref dcPowerFlow)
* [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow))
* [`analysisBus`](@ref analysisBus(::PowerSystem, ::DCPowerFlow))
* [`analysisBranch`](@ref analysisBranch(::PowerSystem, ::DCPowerFlow))
* [`analysisGenerator`](@ref analysisGenerator(::PowerSystem, ::DCPowerFlow))

---

## Newton Raphson Method
```@docs
newtonRaphson
mismatch!(::PowerSystem, ::NewtonRaphson)
solve!(::PowerSystem, ::NewtonRaphson)
```

---

## Fast Newton Raphson Method
```@docs
fastNewtonRaphsonBX
fastNewtonRaphsonXB
mismatch!(::PowerSystem, ::FastNewtonRaphson)
solve!(::PowerSystem, ::FastNewtonRaphson)
```

---

## Gauss-Seidel Method
```@docs
gaussSeidel
mismatch!(::PowerSystem, ::GaussSeidel)
solve!(::PowerSystem, ::GaussSeidel)
```

---

###### Power and Current Analysis
```@docs
analysisBus(::PowerSystem, ::ACPowerFlow)
analysisBranch(::PowerSystem, ::ACPowerFlow)
analysisGenerator(::PowerSystem, ::ACPowerFlow)
```

---

## Additional Functions
```@docs
reactiveLimit!
adjustAngle!
```

---

## DC Power Flow
```@docs
dcPowerFlow
solve!(::PowerSystem, ::DCPowerFlow)
analysisBus(::PowerSystem, ::DCPowerFlow)
analysisBranch(::PowerSystem, ::DCPowerFlow)
analysisGenerator(::PowerSystem, ::DCPowerFlow)
```

