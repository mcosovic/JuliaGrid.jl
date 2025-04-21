##### Test Structs #####
function teststruct(obj1::S, obj2::S; atol = nothing) where S
    for name in fieldnames(typeof(obj1))
        field1 = getfield(obj1, name)
        field2 = getfield(obj2, name)

        if isa(field1, Vector) || isa(field1, Number)
            if isnothing(atol)
                @test ==(field1, field2)
            else
                if !isempty(field1)
                    @test ≈(field1, field2, atol = atol)
                end
            end
        elseif isa(field1, OrderedDict{Int64, Vector{Float64}}) ||
               isa(field1, OrderedDict{Int64, Matrix{Float64}})
            @test ==(keys(field1), keys(field2))
            for (idx, value) in field1
                if isnothing(atol)
                    @test ==(value, field2[idx])
                else
                    @test ≈(value, field2[idx], atol = atol)
                end
            end
        elseif isa(field1, AbstractDict) || isa(field1, String)
            @test ==(field1, field2)
        else
            teststruct(field1, field2; atol)
        end
    end
end

##### Test Voltages using Matpower Data #####
function testVoltage(matpower::Dict{String, Any}, analysis::AC; atol = 0)
    if haskey(matpower, "iteration")
        @test analysis.method.iteration == matpower["iteration"][1]
    end
    @test analysis.voltage.magnitude ≈ matpower["voltageMagnitude"] atol = atol
    @test analysis.voltage.angle ≈ matpower["voltageAngle"] atol = atol
end

##### Test Powers using Matpower Data #####
function testPower(matpower::Dict{String, Any}, analysis::AC; atol = 0)
    @test analysis.power.injection.active ≈ matpower["injectionActive"] atol = atol
    @test analysis.power.injection.reactive ≈ matpower["injectionReactive"] atol = atol
    @test analysis.power.supply.active ≈ matpower["supplyActive"] atol = atol
    @test analysis.power.supply.reactive ≈ matpower["supplyReactive"] atol = atol
    @test analysis.power.shunt.active ≈ matpower["shuntActive"] atol = atol
    @test analysis.power.shunt.reactive ≈ matpower["shuntReactive"] atol = atol
    @test analysis.power.from.active ≈ matpower["fromActive"] atol = atol
    @test analysis.power.from.reactive ≈ matpower["fromReactive"] atol = atol
    @test analysis.power.to.active ≈ matpower["toActive"] atol = atol
    @test analysis.power.to.reactive ≈ matpower["toReactive"] atol = atol
    @test analysis.power.charging.reactive ≈ matpower["chargingFrom"] + matpower["chargingTo"] atol = atol
    @test analysis.power.series.active ≈ matpower["lossActive"] atol = atol
    @test analysis.power.series.reactive ≈ matpower["lossReactive"] atol = atol
    @test analysis.power.generator.active ≈ matpower["generatorActive"] atol = atol
    @test analysis.power.generator.reactive ≈ matpower["generatorReactive"] atol = atol
end

function testGenPower(matpower::Dict{String, Any}, analysis::AC; atol = 0)
    @test analysis.power.generator.active ≈ matpower["generatorActive"] atol = atol
    @test analysis.power.generator.reactive ≈ matpower["generatorReactive"] atol = atol
end

function testPower(matpower::Dict{String, Any}, analysis::DC; atol = 0)
    @test analysis.power.injection.active ≈ matpower["injection"] atol = atol
    @test analysis.power.supply.active ≈ matpower["supply"] atol = atol
    @test analysis.power.from.active ≈ matpower["from"] atol = atol
    @test analysis.power.to.active ≈ -matpower["from"] atol = atol
    @test analysis.power.generator.active ≈ matpower["generator"] atol = atol
end

##### Test Bus Analysis Data #####
function testBus(analysis::AC)
    for (key, value) in analysis.system.bus.label
        active, reactive = injectionPower(analysis; label = key)
        @test active ≈ analysis.power.injection.active[value] atol = 1e-14
        @test reactive ≈ analysis.power.injection.reactive[value]

        active, reactive = supplyPower(analysis; label = key)
        @test active ≈ analysis.power.supply.active[value]
        @test reactive ≈ analysis.power.supply.reactive[value]

        active, reactive = shuntPower(analysis; label = key)
        @test active ≈ analysis.power.shunt.active[value]
        @test reactive ≈ analysis.power.shunt.reactive[value]

        magnitude, angle = injectionCurrent(analysis; label = key)
        @test magnitude ≈ analysis.current.injection.magnitude[value]
        @test angle ≈ analysis.current.injection.angle[value]
    end
end

function testBus(analysis::DC)
    for (key, value) in analysis.system.bus.label
        injection = injectionPower(analysis; label = key)
        supply = supplyPower(analysis; label = key)

        @test injection ≈ analysis.power.injection.active[value]
        @test supply ≈ analysis.power.supply.active[value]
    end
end

##### Test Branch Analysis Data #####
function testBranch(analysis::AC)
    for (key, value) in analysis.system.branch.label
        active, reactive = fromPower(analysis; label = key)
        @test active ≈ analysis.power.from.active[value]
        @test reactive ≈ analysis.power.from.reactive[value]

        active, reactive = toPower(analysis; label = key)
        @test active ≈ analysis.power.to.active[value]
        @test reactive ≈ analysis.power.to.reactive[value]

        active, reactive = chargingPower(analysis; label = key)
        @test active ≈ analysis.power.charging.active[value]
        @test reactive ≈ analysis.power.charging.reactive[value]

        active, reactive = seriesPower(analysis; label = key)
        @test active ≈ analysis.power.series.active[value]
        @test reactive ≈ analysis.power.series.reactive[value]

        magnitude, angle = fromCurrent(analysis; label = key)
        @test magnitude ≈ analysis.current.from.magnitude[value]
        @test angle ≈ analysis.current.from.angle[value]

        magnitude, angle = toCurrent(analysis; label = key)
        @test magnitude ≈ analysis.current.to.magnitude[value]
        @test angle ≈ analysis.current.to.angle[value]

        magnitude, angle = seriesCurrent(analysis; label = key)
        @test magnitude ≈ analysis.current.series.magnitude[value]
        @test angle ≈ analysis.current.series.angle[value]
    end
end

function testBranch(analysis::DC)
    for (key, value) in analysis.system.branch.label
        from = fromPower(analysis; label = key)
        to = toPower(analysis; label = key)

        @test from ≈ analysis.power.from.active[value]
        @test to ≈ analysis.power.to.active[value]
    end
end

##### Test Generator Analysis Data #####
function testGenerator(analysis::AC)
    for (key, value) in analysis.system.generator.label
        active, reactive = generatorPower(analysis; label = key)
        @test active ≈ analysis.power.generator.active[value]
        @test reactive ≈ analysis.power.generator.reactive[value]
    end
end

function testGenerator(analysis::DC)
    for (key, value) in analysis.system.generator.label
        generator = generatorPower(analysis; label = key)
        @test generator ≈ analysis.power.generator.active[value]
    end
end

##### Test Current Analysis Data #####
function testCurrent(analysis::AC)
    power = analysis.power
    voltage = analysis.voltage
    current = analysis.current
    branch = analysis.system.branch
    to = branch.layout.to
    from = branch.layout.from

    Si = complex.(power.injection.active, power.injection.reactive)
    Vi = voltage.magnitude .* cis.(voltage.angle)
    @test current.injection.magnitude .* cis.(-current.injection.angle) ≈ Si ./ Vi

    Sij = complex.(power.from.active, power.from.reactive)
    Vi = voltage.magnitude[from] .* cis.(voltage.angle[from])
    @test current.from.magnitude .* cis.(-current.from.angle) ≈ Sij ./ Vi

    Sji = complex.(power.to.active, power.to.reactive)
    Vj = voltage.magnitude[to] .* cis.(voltage.angle[to])
    @test current.to.magnitude .* cis.(-current.to.angle) ≈ Sji ./ Vj

    ratio = (1 ./ branch.parameter.turnsRatio) .* cis.(-branch.parameter.shiftAngle)
    Sijb = complex.(power.series.active, power.series.reactive)
    @test current.series.magnitude .* cis.(-current.series.angle) ≈ Sijb ./ (ratio .* Vi - Vj)
end

##### Test Devices #####
function testDevice(meter, fully, idx::Int64, status::Int64)
    @test meter.mean[end] ≈ fully.mean[idx] atol = 1e-14
    @test meter.status[end] == status
end

##### Test Reusing Power Flow #####
function testReusing(analysis::AcPowerFlow{NewtonRaphson})
    pf = newtonRaphson(analysis.system)
    powerFlow!(pf; tolerance = 1e-10)

    setInitialPoint!(analysis)
    powerFlow!(analysis; tolerance = 1e-10)

    @test pf.method.iteration == analysis.method.iteration
    teststruct(pf.voltage, analysis.voltage; atol = 1e-8)
end

function testReusing(analysis::AcPowerFlow{FastNewtonRaphson})
    pf = fastNewtonRaphsonBX(analysis.system)
    powerFlow!(pf; tolerance = 1e-10)

    setInitialPoint!(analysis)
    powerFlow!(analysis; tolerance = 1e-10)

    @test analysis.method.active.jacobian ≈ pf.method.active.jacobian
    @test analysis.method.reactive.jacobian ≈ pf.method.reactive.jacobian

    @test pf.method.iteration == analysis.method.iteration
    teststruct(pf.voltage, analysis.voltage; atol = 1e-8)
end

function testReusing(analysis::AcPowerFlow{GaussSeidel})
    pf = gaussSeidel(analysis.system)
    powerFlow!(pf; iteration = 1000, tolerance = 1e-10)

    setInitialPoint!(analysis)
    powerFlow!(analysis; iteration = 1000, tolerance = 1e-10)

    @test pf.method.iteration == analysis.method.iteration
    teststruct(pf.voltage, analysis.voltage; atol = 1e-8)
end

function testReusing(analysis::DcPowerFlow)
    pf = dcPowerFlow(analysis.system)
    powerFlow!(pf)

    powerFlow!(analysis)

    teststruct(pf.voltage, analysis.voltage; atol = 1e-8)
end

##### Test Reusing Optimal Power Flow #####
function testReusing(analysis::AcOptimalPowerFlow)
    opf = acOptimalPowerFlow(analysis.system, Ipopt.Optimizer)
    powerFlow!(opf)

    setInitialPoint!(analysis)
    powerFlow!(analysis)

    @test is_solved_and_feasible(opf.method.jump) == true
    @test is_solved_and_feasible(analysis.method.jump) == true

    @test objective_value(opf.method.jump) ≈ objective_value(analysis.method.jump) atol = 1e-3
    @test barrier_iterations(opf.method.jump) == barrier_iterations(analysis.method.jump)
    for i in list_of_constraint_types(opf.method.jump)
        @test num_constraints(opf.method.jump, i...) == num_constraints(analysis.method.jump, i...)
    end

    teststruct(opf.voltage, analysis.voltage; atol = 1e-8)
end

function testReusing(analysis::DcOptimalPowerFlow)
    opf = dcOptimalPowerFlow(analysis.system, Ipopt.Optimizer)
    powerFlow!(opf)

    setInitialPoint!(analysis)
    powerFlow!(analysis)

    @test is_solved_and_feasible(opf.method.jump) == true
    @test is_solved_and_feasible(analysis.method.jump) == true

    @test objective_value(opf.method.jump) ≈ objective_value(analysis.method.jump) atol = 1e-8
    @test barrier_iterations(opf.method.jump) == barrier_iterations(analysis.method.jump)
    for i in list_of_constraint_types(opf.method.jump)
        @test num_constraints(opf.method.jump, i...) == num_constraints(analysis.method.jump, i...)
    end

    teststruct(opf.voltage, analysis.voltage; atol = 1e-8)
end

##### Test AC State Estimation #####
function testAcEstimation(monitoring::Measurement, analysis::AcPowerFlow)
    gn = gaussNewton(monitoring)
    stateEstimation!(gn; iteration = 200, tolerance = 1e-12)
    teststruct(gn.voltage, analysis.voltage; atol = 1e-10)

    lav = acLavStateEstimation(monitoring, Ipopt.Optimizer)
    stateEstimation!(lav)
    teststruct(lav.voltage, analysis.voltage; atol = 1e-8)
end

##### Test PMU State Estimation #####
function testPmuEstimation(monitoring::Measurement, analysis::AcPowerFlow)
    pmu = pmuStateEstimation(monitoring)
    stateEstimation!(pmu)
    teststruct(pmu.voltage, analysis.voltage; atol = 1e-10)

    lav = pmuLavStateEstimation(monitoring, Ipopt.Optimizer)
    solve!(lav)
    teststruct(lav.voltage, analysis.voltage; atol = 1e-8)
end

##### Test DC State Estimation #####
function testDcEstimation(monitoring::Measurement, analysis::DcPowerFlow)
    dc = dcStateEstimation(monitoring)
    stateEstimation!(dc)
    @test dc.voltage.angle ≈ analysis.voltage.angle

    lav = dcLavStateEstimation(monitoring, Ipopt.Optimizer)
    stateEstimation!(lav)
    @test lav.voltage.angle ≈ analysis.voltage.angle
end

##### Add PMU at All Buses #####
function addPmuBus(monitoring::Measurement, analysis::AcPowerFlow)
    for (key, idx) in monitoring.system.bus.label
        addPmu!(
            monitoring; bus = key, magnitude = analysis.voltage.magnitude[idx],
            angle = analysis.voltage.angle[idx], polar = true
        )
    end
end

##### Test Reusing Gauss-Newton State Estimation #####
function testReusing(
    monitoring::Measurement,
    wls::AcStateEstimation{GaussNewton{Normal}},
    lav::AcStateEstimation{LAV},
    idx::Int64;
    pmu::Bool = false
)
    setInitialPoint!(wls)
    setInitialPoint!(lav)

    analysis = gaussNewton(monitoring)
    stateEstimation!(analysis; iteration = 1)
    stateEstimation!(wls; iteration = 1)

    @test analysis.method.precision == wls.method.precision
    @test analysis.method.mean == wls.method.mean
    @test analysis.method.jacobian ≈ wls.method.jacobian atol = 1e-10
    @test analysis.method.increment ≈ wls.method.increment atol = 1e-10
    @test analysis.method.type == wls.method.type

    stateEstimation!(analysis; iteration = 100, tolerance = 1e-10)
    stateEstimation!(wls; iteration = 100, tolerance = 1e-10)

    @test analysis.method.iteration == wls.method.iteration
    teststruct(analysis.voltage, wls.voltage; atol = 1e-10)

    analysis = acLavStateEstimation(monitoring, Ipopt.Optimizer)
    stateEstimation!(analysis)
    stateEstimation!(lav)

    testConstraint(lav, wls, idx)
    if pmu
        testConstraint(lav, wls, idx + 1)
    end
    testOptimization(analysis, lav)
end

function testOptimization(a, b)
    @test is_solved_and_feasible(a.method.jump) == true
    @test is_solved_and_feasible(b.method.jump) == true

    @test objective_value(a.method.jump) ≈ objective_value(b.method.jump) atol = 1e-8
    @test barrier_iterations(a.method.jump) == barrier_iterations(b.method.jump)
    for i in list_of_constraint_types(a.method.jump)
        @test num_constraints(a.method.jump, i...) == num_constraints(b.method.jump, i...)
    end

    teststruct(a.voltage, b.voltage; atol = 1e-8)
end

function testConstraint(lav, wls, idx::Int64)
    if wls.method.mean[idx] == 0
        haskey(lav.method.residual, idx) == false
    else
        f = JuMP.constraint_object(lav.method.residual[idx])
        if f.func isa JuMP.GenericAffExpr
            @test f.set.value == wls.method.mean[idx]
        else
            @test f.func.args[end] == wls.method.mean[idx]
        end

        @test is_valid(lav.method.jump, lav.method.residual[idx]) == true
    end
end

##### Test Reusing PMU State Estimation #####
function testReusing(
    monitoring::Measurement,
    wls::PmuStateEstimation{WLS{Normal}},
    lav::PmuStateEstimation{LAV},
    idx::Int64
)
    analysis = pmuStateEstimation(monitoring)

    @test analysis.method.precision == wls.method.precision
    @test analysis.method.mean == wls.method.mean
    @test analysis.method.coefficient ≈ wls.method.coefficient atol = 1e-10

    stateEstimation!(analysis)
    stateEstimation!(wls)
    teststruct(analysis.voltage, wls.voltage; atol = 1e-10)

    analysis = pmuLavStateEstimation(monitoring, Ipopt.Optimizer)
    stateEstimation!(analysis)

    setInitialPoint!(lav)
    stateEstimation!(lav)

    testConstraint(lav, wls, idx)
    testConstraint(lav, wls, idx + 1)
    testOptimization(analysis, lav)
end

##### Test Reusing DC State Estimation #####
function testReusing(
    monitoring::Measurement,
    wls::DcStateEstimation{WLS{Normal}},
    lav::DcStateEstimation{LAV},
    idx::Int64
)
    analysis = dcStateEstimation(monitoring)

    @test analysis.method.precision == wls.method.precision
    @test analysis.method.mean == wls.method.mean
    @test analysis.method.coefficient ≈ wls.method.coefficient atol = 1e-10

    stateEstimation!(analysis)
    stateEstimation!(wls)
    teststruct(analysis.voltage, wls.voltage; atol = 1e-10)

    analysis = dcLavStateEstimation(monitoring, Ipopt.Optimizer)
    stateEstimation!(analysis)

    setInitialPoint!(lav)
    stateEstimation!(lav)

    testConstraint(lav, wls, idx)
    testOptimization(analysis, lav)
end