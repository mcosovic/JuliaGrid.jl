##### Power System Statistics #####
function printTop(
    system::PowerSystem,
    analysis::Union{ACPowerFlow, DCPowerFlow},
    verbose::Int64,
)
    if verbose == 3
        bus = system.bus
        brc = system.branch
        gen = system.generator

        shunt = fill(0.0, 3)
        @inbounds for i = 1:system.bus.number
            if bus.shunt.susceptance[i] != 0.0 || bus.shunt.conductance[i] != 0.0
                shunt[1] += 1
                if bus.shunt.susceptance[i] > 0.0
                    shunt[2] += 1
                elseif bus.shunt.susceptance[i] < 0.0
                    shunt[3] += 1
                end
            end
        end

        tran = fill(0.0, 3)
        @inbounds for i = 1:brc.number
            if brc.parameter.turnsRatio[i] != 1.0 || brc.parameter.shiftAngle[i] != 0.0
                tran[1] += 1
                if brc.layout.status[i] == 1
                    tran[2] += 1
                end
            end
        end
        tran[3] = tran[1] - tran[2]

        pq = npq(system, analysis)

        col1 = max(textwidth(string(bus.number)), textwidth(string(brc.number)))
        col2 = max(textwidth(string(shunt[1])), textwidth(string(brc.number - tran[1])))
        col3 = max(textwidth(string(gen.number)), textwidth(string(tran[1])))

        print("Number of buses:    ")
        print(format(Format("%*i"), col1, bus.number))

        print("   Number of shunts: ")
        print(format(Format("%*i"), col2, shunt[1]))

        print("   Number of generators:   ")
        print(format(Format("%*i\n"), col3, gen.number))

        print("  Demand:           ")
        print(format(Format("%*i"), col1, pq))

        print("     Capacitor:      ")
        print(format(Format("%*i"), col2, shunt[2]))

        print("     In-service:           ")
        print(format(Format("%*i\n"), col3, gen.layout.inservice))

        print("  Generator:        ")
        print(format(Format("%*i"), col1, bus.number - 1 - pq))

        print("     Reactor:        ")
        print(format(Format("%*i"), col2, shunt[3]))

        print("     Out-of-service:       ")
        print(format(Format("%*i\n\n"), col3, gen.number - gen.layout.inservice))

        print("Number of branches: ")
        print(format(Format("%*i"), col1, brc.number))

        print("   Number of lines:  ")
        print(format(Format("%*i"), col2, brc.number - tran[1]))

        print("   Number of transformers: ")
        print(format(Format("%*i\n"), col3, tran[1]))

        print("  In-service:       ")
        print(format(Format("%*i"), col1, brc.layout.inservice))

        print("     In-service:     ")
        print(format(Format("%*i"), col2, brc.layout.inservice - tran[2]))

        print("     In-service:           ")
        print(format(Format("%*i\n"), col3, tran[2]))

        print("  Out-of-service:   ")
        print(format(Format("%*i"), col1, brc.number - brc.layout.inservice))

        print("     Out-of-service: ")
        print(format(Format("%*i"), col2, brc.number - brc.layout.inservice - tran[3]))

        print("     Out-of-service:       ")
        print(format(Format("%*i\n\n"), col3, tran[3]))
    end
end

function npq(system::PowerSystem, analysis::ACPowerFlow{NewtonRaphson})
    lastindex(analysis.method.increment) - system.bus.number + 1
end

function npq(::PowerSystem, analysis::ACPowerFlow{FastNewtonRaphson})
    lastindex(analysis.method.reactive.increment)
end

function npq(::PowerSystem, analysis::ACPowerFlow{GaussSeidel})
    lastindex(analysis.method.pq)
end

function npq(system::PowerSystem, ::DCPowerFlow)
    count(x -> x == 1, system.bus.layout.type)
end

##### Measurement Statistics #####
function printTop(
    analysis::ACStateEstimation{GaussNewton{T}},
    verbose::Int64
) where T <: Union{Normal, Orthogonal}

    if verbose == 3
        range = analysis.method.range
        type = analysis.method.type

        vol = count(x -> x == 0, type[range[1]:range[2] - 1])
        amp = count(x -> x == 0, type[range[2]:range[3] - 1])
        wat = count(x -> x == 0, type[range[3]:range[4] - 1])
        var = count(x -> x == 0, type[range[4]:range[5] - 1])
        pmu = Int64(floor(eps() + count(x -> x == 0, type[range[5]:range[6] - 1]) / 2))
        printTopData(range, vol, amp, wat, var, pmu, verbose)
    end
end

function printTop(analysis::ACStateEstimation{LAV}, verbose::Int64)
    if verbose == 3
        range = analysis.method.range
        type = is_fixed.(analysis.method.deviation.positive)

        vol = count(x -> x == 1, type[range[1]:range[2] - 1])
        amp = count(x -> x == 1, type[range[2]:range[3] - 1])
        wat = count(x -> x == 1, type[range[3]:range[4] - 1])
        var = count(x -> x == 1, type[range[4]:range[5] - 1])
        display(count(x -> x == 1, type[range[5]:range[6] - 1]) / 2)
        pmu = Int64(floor(eps() + count(x -> x == 1, type[range[5]:range[6] - 1]) / 2))
        printTopData(range, vol, amp, wat, var, pmu, verbose)
    end
end

function printTopData(
    range::Vector{Int64},
    volo::Int64,
    ampo::Int64,
    wato::Int64,
    varo::Int64,
    pmuo::Int64,
    verbose::Int64
)
    if verbose == 3
        vol = range[2] - range[1]
        amp = range[3] - range[2]
        wat = range[4] - range[3]
        var = range[5] - range[4]
        pmu = Int64((range[6] - range[5]) / 2)
        dev = vol + amp + wat + var + pmu

        col1 = max(textwidth(string(wat)), textwidth(string(amp)))
        col2 = max(textwidth(string(var)),textwidth(string(pmu)))
        col3 = textwidth(string(dev))

        print("Number of wattmeters: ")
        print(format(Format("%*i"), col1, wat))

        print("   Number of varmeters: ")
        print(format(Format("%*i"), col2, var))

        print("   Number of voltmeters: ")
        print(format(Format("%*i\n"), col3, vol))

        print("  In-service:         ")
        print(format(Format("%*i"), col1, wat - wato))

        print("     In-service:        ")
        print(format(Format("%*i"), col2, var - varo))

        print("     In-service:         ")
        print(format(Format("%*i\n"), col3, vol - volo))

        print("  Out-of-service:     ")
        print(format(Format("%*i"), col1, wato))

        print("     Out-of-service:    ")
        print(format(Format("%*i"), col2, varo))

        print("     Out-of-service:     ")
        print(format(Format("%*i\n\n"), col3, volo))

        print("Number of ammeters:   ")
        print(format(Format("%*i"), col1, amp))

        print("   Number of PMUs:      ")
        print(format(Format("%*i"), col2, pmu))

        print("   Number of devices:    ")
        print(format(Format("%*i\n"), col3, dev))

        print("  In-service:         ")
        print(format(Format("%*i"), col1, amp - ampo))

        print("     In-service:        ")
        print(format(Format("%*i"), col2, pmu - pmuo))

        print("     In-service:         ")
        print(format(Format("%*i\n"), col3, dev - volo - ampo - wato - varo - pmuo))

        print("  Out-of-service:     ")
        print(format(Format("%*i"), col1, ampo))

        print("     Out-of-service:    ")
        print(format(Format("%*i"), col2, pmuo))

        print("     Out-of-service:     ")
        print(format(Format("%*i\n\n"), col3, volo + ampo + wato + varo + pmuo))
    end
end

##### Model Statistics #####
function printMiddle(analysis::ACPowerFlow{NewtonRaphson}, verbose::Int64)
    if verbose == 2 || verbose == 3
        entri = nnz(analysis.method.jacobian)
        state = lastindex(analysis.method.increment)
        maxms = "Number of entries in the Jacobian:"

        wd1 = textwidth(string(entri)) + 1
        wd2 = textwidth(maxms)

        print(maxms)
        print(format(Format("%*i\n"), wd1, entri))

        print("Number of state variables:")
        print(format(Format("%*i\n\n"), wd1 + wd2 - 26, state))
    end
end

function printMiddle(analysis::ACPowerFlow{FastNewtonRaphson}, verbose::Int64)
    if verbose == 2 || verbose == 3
        method = analysis.method

        activ = nnz(method.active.jacobian)
        react = nnz(method.reactive.jacobian)
        entri = activ + react
        state = lastindex(method.active.increment) + lastindex(method.reactive.increment)
        maxms = "Number of entries in the Jacobians:"

        wd1 = textwidth(string(entri)) + 1
        wd2 = textwidth(maxms)

        print(maxms)
        print(format(Format("%*i\n"), wd1, entri))

        print("  Active Power:")
        print(format(Format("%*i\n"), wd1 + wd2 - 15, activ))

        print("  Reactive Power:")
        print(format(Format("%*i\n"), wd1 + wd2 - 17, react))

        print("Number of state variables:")
        print(format(Format("%*i\n\n"), wd1 + wd2 - 26, state))
    end
end

function printMiddle(analysis::ACPowerFlow{GaussSeidel}, verbose::Int64)
    if verbose == 2 || verbose == 3
        stapq = lastindex(analysis.method.pq)
        stapv = lastindex(analysis.method.pv)
        state = stapq + stapv
        maxms = "Number of complex state variables:"

        wd1 = textwidth(string(state)) + 1
        wd2 = textwidth(maxms)

        print("Number of complex state variables:")
        print(format(Format("%*i\n"), wd1, state))

        print("Number of complex equations:")
        print(format(Format("%*i\n\n"), wd1 + wd2 - 28, stapq + 3 * stapv))
    end
end

function printMiddle(system::PowerSystem, ::DCPowerFlow, verbose::Int64)
    if verbose == 2 || verbose == 3
        entries = nnz(system.model.dc.nodalMatrix)
        maxmess = "Number of entries in the nodal matrix:"

        wd1 = textwidth(string(entries)) + 1
        wd2 = textwidth(maxmess)

        print(maxmess)
        print(format(Format("%*i\n"), wd1, entries))

        print("Number of state variables:")
        print(format(Format("%*i\n\n"), wd1 + wd2 - 26, system.bus.number - 1))
    end
end

function printMiddle(system::PowerSystem, analysis::ACStateEstimation, verbose::Int64)
    if verbose == 2 || verbose == 3
        wd = textwidth(string(nnz(analysis.method.jacobian))) + 1
        mwd = textwidth("Number of entries in the Jacobian:")
        tot = wd + mwd

        print("Number of entries in the Jacobian:")
        print(format(Format("%*i\n"), wd, nnz(analysis.method.jacobian)))

        print("Number of measurement functions:")
        print(format(Format("%*i\n"), tot - 32, lastindex(analysis.method.mean)))

        print("Number of state variables:")
        print(format(Format("%*i\n"), tot - 26, lastindex(analysis.method.increment) - 1))

        print("Number of buses:")
        print(format(Format("%*i\n"), tot - 16, system.bus.number))

        print("Number of branches:")
        print(format(Format("%*i\n\n"), tot - 19, system.branch.number))
    end
end

function printMiddle(system::PowerSystem, analysis::DCStateEstimation, verbose::Int64)
    if verbose == 2 || verbose == 3
        entries = nnz(analysis.method.coefficient)
        maxmess = "Number of entries in the coefficient matrix:"

        wd1 = textwidth(string(entries)) + 1
        wd2 = textwidth(maxmess)

        print(maxmess)
        print(format(Format("%*i\n"), wd1, entries))

        print("Number of measurement functions:")
        print(format(Format("%*i\n"), wd1 + wd2 - 32, lastindex(analysis.method.mean)))

        print("Number of state variables:")
        print(format(Format("%*i\n\n"), wd1 + wd2 - 26, system.bus.number - 1))
    end
end

function printMiddle(system::PowerSystem, analysis::PMUStateEstimation, verbose::Int64)
    if verbose == 2 || verbose == 3
        entries = nnz(analysis.method.coefficient)
        maxmess = "Number of entries in the coefficient matrix:"

        wd1 = textwidth(string(entries)) + 1
        wd2 = textwidth(maxmess)

        print(maxmess)
        print(format(Format("%*i\n"), wd1, entries))

        print("Number of measurement functions:")
        print(format(Format("%*i\n"), wd1 + wd2 - 32, lastindex(analysis.method.mean)))

        print("Number of state variables:")
        print(format(Format("%*i\n\n"), wd1 + wd2 - 26, 2 * system.bus.number))
    end
end

##### Solver Data #####
function printSolver(analysis::ACPowerFlow, delP::Float64, delQ::Float64, verbose::Int64)
    if verbose == 2 || verbose == 3
        if analysis.method.iteration % 10 == 0
            println("-"^63)
            println("Iteration   Max Abs Active Mismatch   Max Abs Reactive Mismatch")
            println("-"^63)
        end
        print(format(Format("%*i "), 9, analysis.method.iteration))
        print(format(Format("%*.8e"), 25, delP))
        print(format(Format("%*.8e\n"), 28, delQ))
    end
end

function printSolver(
    system::PowerSystem,
    analysis::ACPowerFlow{T},
    verbose::Int64,
) where T <: Union{NewtonRaphson, FastNewtonRaphson}

    if verbose == 2 || verbose == 3
        mag, ang = minmaxIncrement(system, analysis)

        print("\n" * " "^23 * "Minimum Value   Maximum Value")

        print("\nMagnitude Increment:")
        print(format(Format("%*.4e"), 16, mag[1]))
        print(format(Format("%*.4e\n"), 16, mag[2]))

        print("Angle Increment:")
        print(format(Format("%*.4e"), 20, ang[1]))
        print(format(Format("%*.4e\n\n"), 16, ang[2]))
    end
end

function printSolver(::PowerSystem, ::ACPowerFlow{GaussSeidel}, verbose::Int64)
    if verbose == 2 || verbose == 3
        print("\n")
    end
end

function minmaxIncrement(system::PowerSystem, analysis::ACPowerFlow{NewtonRaphson})
    extrema(analysis.method.increment[1:(system.bus.number - 1)]),
    extrema(analysis.method.increment[system.bus.number:end])
end

function minmaxIncrement(::PowerSystem, analysis::ACPowerFlow{FastNewtonRaphson})
    extrema(analysis.method.active.increment),
    extrema(analysis.method.reactive.increment)
end

function printSolver(analysis::ACStateEstimation, inc::Float64, verbose::Int64)
    if verbose == 2 || verbose == 3
        if analysis.method.iteration % 10 == 0
            println("-"^47)
            println("Iteration   Objective Value   Max Abs Increment")
            println("-"^47)
        end

        print(format(Format("%*i "), 9, analysis.method.iteration))
        print(format(Format("%*.8e"), 17, analysis.method.objective))
        print(format(Format("%*.8e\n"), 20, inc))
    end
end

function printSolver(system::PowerSystem, analysis::ACStateEstimation, verbose::Int64)
    if verbose == 2 || verbose == 3
        slack = copy(analysis.method.increment[system.bus.layout.slack])

        maxres, idxres = findmax(abs, analysis.method.residual)
        maxwrss, idxwrss = findmax(analysis.method.residual.^2 .* diag(analysis.method.precision))

        print("\n" * " "^20 * "Measurement   Maximum Value")

        print("\nAbsolute Residual:")
        print(format(Format("%*i"), 13, idxres))
        print(format(Format("%*.4e\n"), 16, maxres))

        print("Objective Value:")
        print(format(Format("%*i"), 15, idxwrss))
        print(format(Format("%*.4e\n\n"), 16, maxwrss))
    end
end

##### Print Exit Messages #####
function printExit(
    analysis::AC,
    maxExceeded::Bool,
    converged::Bool,
    verbose::Int64,
)
    if verbose != 0
        method = printMethodName(analysis)
        if converged
            println(
                "EXIT: The solution was found using the " * method *
                " method in $(analysis.method.iteration) iterations."
            )
        else
            if maxExceeded
                println("EXIT: The " * method * " method exceeded the maximum number of iterations.")
            else
                println("EXIT: The " * method * " method failed to converge.")
            end
        end
    end
end

function printExit(jump::JuMP.Model, verbose::Int64)
    if verbose == 1
        if is_solved_and_feasible(jump)
            println("EXIT: The optimal solution was found.")
        else
            status = termination_status(jump)
            if status == MOI.ITERATION_LIMIT
                println("EXIT: The maximum number of iterations exceeded.")
            elseif status == MOI.ALMOST_LOCALLY_SOLVED
                println("EXIT: Solved To Acceptable Level.")
            elseif status == MOI.LOCALLY_INFEASIBLE
                println("EXIT: Converged to a point of local infeasibility. Problem may be infeasible.")
            elseif status == MOI.NUMERICAL_ERROR
                println("EXIT: Restoration Failed!")
            else
                println("EXIT: The optimal solution was not found.")
            end
        end
    end
end

function printExit(::DCPowerFlow, verbose::Int64)
    if verbose != 0
        println("EXIT: The solution of the DC power flow was found.")
    end
end

function printExit(::DCStateEstimation, verbose::Int64)
    if verbose != 0
        println("EXIT: The solution of the DC state estimation was found.")
    end
end

function printExit(::PMUStateEstimation, verbose::Int64)
    if verbose != 0
        println("EXIT: The solution of the PMU state estimation was found.")
    end
end

function printMethodName(::ACPowerFlow{NewtonRaphson})
    "Newton-Raphson"
end

function printMethodName(::ACPowerFlow{FastNewtonRaphson})
    "fast Newton-Raphson"
end

function printMethodName(::ACPowerFlow{GaussSeidel})
    "Gauss-Seidel"
end

function printMethodName(::ACStateEstimation)
    "Gauss-Newton"
end