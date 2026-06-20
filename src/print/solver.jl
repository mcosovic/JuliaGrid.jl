##### Power System Statistics #####
function printTop(system::PowerSystem, analysis::Union{AcPowerFlow, DcPowerFlow}, verbose::Int64)
    if verbose != 3
        return
    end

    bus = system.bus
    brc = system.branch
    gen = system.generator

    shunt = 0
    capacitor = 0
    reactor = 0
    @inbounds for i = 1:system.bus.number
        if bus.shunt.susceptance[i] != 0.0 || bus.shunt.conductance[i] != 0.0
            shunt += 1
            if bus.shunt.susceptance[i] > 0.0
                capacitor += 1
            elseif bus.shunt.susceptance[i] < 0.0
                reactor += 1
            end
        end
    end

    transformer = 0
    transformerInservice = 0
    @inbounds for i = 1:brc.number
        if brc.parameter.turnsRatio[i] != 1.0 || brc.parameter.shiftAngle[i] != 0.0
            transformer += 1
            if brc.layout.status[i] == 1
                transformerInservice += 1
            end
        end
    end
    transformerOutservice = transformer - transformerInservice

    pq = npq(system, analysis)

    col1 = max(textwidth(string(bus.number)), textwidth(string(brc.number)))
    col2 = max(textwidth(string(shunt)), textwidth(string(brc.number - transformer)))
    col3 = max(textwidth(string(gen.number)), textwidth(string(transformer)))

    print("Number of buses:    ")
    print(format(Format("%*i"), col1, bus.number))

    print("   Number of shunts: ")
    print(format(Format("%*i"), col2, shunt))

    print("   Number of generators:   ")
    print(format(Format("%*i\n"), col3, gen.number))

    print("  Demand:           ")
    print(format(Format("%*i"), col1, pq))

    print("     Capacitor:      ")
    print(format(Format("%*i"), col2, capacitor))

    print("     In-service:           ")
    print(format(Format("%*i\n"), col3, gen.layout.inservice))

    print("  Generator:        ")
    print(format(Format("%*i"), col1, bus.number - 1 - pq))

    print("     Reactor:        ")
    print(format(Format("%*i"), col2, reactor))

    print("     Out-of-service:       ")
    print(format(Format("%*i\n\n"), col3, gen.number - gen.layout.inservice))

    print("Number of branches: ")
    print(format(Format("%*i"), col1, brc.number))

    print("   Number of lines:  ")
    print(format(Format("%*i"), col2, brc.number - transformer))

    print("   Number of transformers: ")
    print(format(Format("%*i\n"), col3, transformer))

    print("  In-service:       ")
    print(format(Format("%*i"), col1, brc.layout.inservice))

    print("     In-service:     ")
    print(format(Format("%*i"), col2, brc.layout.inservice - transformerInservice))

    print("     In-service:           ")
    print(format(Format("%*i\n"), col3, transformerInservice))

    print("  Out-of-service:   ")
    print(format(Format("%*i"), col1, brc.number - brc.layout.inservice))

    print("     Out-of-service: ")
    print(format(Format("%*i"), col2, brc.number - brc.layout.inservice - transformerOutservice))

    print("     Out-of-service:       ")
    print(format(Format("%*i\n\n"), col3, transformerOutservice))
end

function npq(system::PowerSystem, analysis::AcPowerFlow{<:NewtonRaphson})
    lastindex(analysis.method.increment) - system.bus.number + 1
end

function npq(::PowerSystem, analysis::AcPowerFlow{<:FastNewtonRaphson})
    lastindex(analysis.method.reactive.increment)
end

function npq(::PowerSystem, analysis::AcPowerFlow{GaussSeidel})
    lastindex(analysis.method.pq)
end

function npq(system::PowerSystem, ::DcPowerFlow)
    count(x -> x == 1, system.bus.layout.type)
end

##### Measurement Statistics #####
function printTop(analysis::AcStateEstimation, verbose::Int64)
    if verbose != 3
        return
    end

    mtg = analysis.monitoring

    dev =
        mtg.voltmeter.number + mtg.ammeter.number + mtg.wattmeter.number + mtg.varmeter.number +
        mtg.pmu.number

    volo = count(x -> x == 0, mtg.voltmeter.magnitude.status)
    ampo = count(x -> x == 0, mtg.ammeter.magnitude.status)
    wato = count(x -> x == 0, mtg.wattmeter.active.status)
    varo = count(x -> x == 0, mtg.varmeter.reactive.status)
    pmuo = count(
        i -> mtg.pmu.magnitude.status[i] == 0 || mtg.pmu.angle.status[i] == 0,
        1:mtg.pmu.number
    )

    col1 = max(textwidth(string(mtg.wattmeter.number)), textwidth(string(mtg.ammeter.number)))
    col2 = max(textwidth(string(mtg.varmeter.number)), textwidth(string(mtg.pmu.number)))
    col3 = max(textwidth(string(mtg.voltmeter.number)), textwidth(string(dev)))

    print("Number of wattmeters: ")
    print(format(Format("%*i"), col1, mtg.wattmeter.number))

    print("   Number of varmeters: ")
    print(format(Format("%*i"), col2, mtg.varmeter.number))

    print("   Number of voltmeters: ")
    print(format(Format("%*i\n"), col3, mtg.voltmeter.number))

    print("  In-service:         ")
    print(format(Format("%*i"), col1, mtg.wattmeter.number - wato))

    print("     In-service:        ")
    print(format(Format("%*i"), col2, mtg.varmeter.number - varo))

    print("     In-service:         ")
    print(format(Format("%*i\n"), col3, mtg.voltmeter.number - volo))

    print("  Out-of-service:     ")
    print(format(Format("%*i"), col1, wato))

    print("     Out-of-service:    ")
    print(format(Format("%*i"), col2, varo))

    print("     Out-of-service:     ")
    print(format(Format("%*i\n\n"), col3, volo))

    print("Number of ammeters:   ")
    print(format(Format("%*i"), col1, mtg.ammeter.number))

    print("   Number of PMUs:      ")
    print(format(Format("%*i"), col2, mtg.pmu.number))

    print("   Number of devices:    ")
    print(format(Format("%*i\n"), col3, dev))

    print("  In-service:         ")
    print(format(Format("%*i"), col1, mtg.ammeter.number - ampo))

    print("     In-service:        ")
    print(format(Format("%*i"), col2, mtg.pmu.number - pmuo))

    print("     In-service:         ")
    print(format(Format("%*i\n"), col3, dev - volo - ampo - wato - varo - pmuo))

    print("  Out-of-service:     ")
    print(format(Format("%*i"), col1, ampo))

    print("     Out-of-service:    ")
    print(format(Format("%*i"), col2, pmuo))

    print("     Out-of-service:     ")
    print(format(Format("%*i\n\n"), col3, volo + ampo + wato + varo + pmuo))
end

##### Model Statistics #####
function printMiddle(analysis::AcPowerFlow{<:NewtonRaphson}, verbose::Int64)
    if verbose == 2 || verbose == 3
        entries = nnz(analysis.method.jacobian)
        state = lastindex(analysis.method.increment)
        message = "Number of entries in the Jacobian:"

        wd1 = textwidth(string(entries)) + 1
        wd2 = textwidth(message)

        print(message)
        print(format(Format("%*i\n"), wd1, entries))

        print("Number of state variables:")
        print(format(Format("%*i\n\n"), wd1 + wd2 - 26, state))
    end
end

function printMiddle(analysis::AcPowerFlow{<:FastNewtonRaphson}, verbose::Int64)
    if verbose == 2 || verbose == 3
        method = analysis.method

        active = nnz(method.active.jacobian)
        reactive = nnz(method.reactive.jacobian)
        entries = active + reactive
        state = lastindex(method.active.increment) + lastindex(method.reactive.increment)
        message = "Number of entries in the Jacobians:"

        wd1 = textwidth(string(entries)) + 1
        wd2 = textwidth(message)

        print(message)
        print(format(Format("%*i\n"), wd1, entries))

        print("  Active Power:")
        print(format(Format("%*i\n"), wd1 + wd2 - 15, active))

        print("  Reactive Power:")
        print(format(Format("%*i\n"), wd1 + wd2 - 17, reactive))

        print("Number of state variables:")
        print(format(Format("%*i\n\n"), wd1 + wd2 - 26, state))
    end
end

function printMiddle(analysis::AcPowerFlow{GaussSeidel}, verbose::Int64)
    if verbose == 2 || verbose == 3
        pq = lastindex(analysis.method.pq)
        pv = lastindex(analysis.method.pv)
        state = pq + pv
        message = "Number of complex state variables:"

        wd1 = textwidth(string(state)) + 1
        wd2 = textwidth(message)

        print("Number of complex state variables:")
        print(format(Format("%*i\n"), wd1, state))

        print("Number of complex equations:")
        print(format(Format("%*i\n\n"), wd1 + wd2 - 28, pq + 3 * pv))
    end
end

function printMiddle(system::PowerSystem, ::DcPowerFlow, verbose::Int64)
    if verbose == 2 || verbose == 3
        entries = nnz(system.model.dc.nodalMatrix)
        message = "Number of entries in the nodal matrix:"

        wd1 = textwidth(string(entries)) + 1
        wd2 = textwidth(message)

        print(message)
        print(format(Format("%*i\n"), wd1, entries))

        print("Number of state variables:")
        print(format(Format("%*i\n\n"), wd1 + wd2 - 26, system.bus.number - 1))
    end
end

function printMiddle(system::PowerSystem, analysis::AcStateEstimation, verbose::Int64)
    if verbose == 2 || verbose == 3
        entries = nnz(analysis.method.jacobian)
        message = "Number of entries in the Jacobian:"
        wd = textwidth(string(entries)) + 1
        mwd = textwidth(message)
        tot = wd + mwd

        print(message)
        print(format(Format("%*i\n"), wd, entries))

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

function printMiddle(system::PowerSystem, analysis::DcStateEstimation, verbose::Int64)
    if verbose == 2 || verbose == 3
        entries = nnz(analysis.method.coefficient)
        message = "Number of entries in the coefficient matrix:"

        wd1 = textwidth(string(entries)) + 1
        wd2 = textwidth(message)

        print(message)
        print(format(Format("%*i\n"), wd1, entries))

        print("Number of measurement functions:")
        print(format(Format("%*i\n"), wd1 + wd2 - 32, lastindex(analysis.method.mean)))

        print("Number of state variables:")
        print(format(Format("%*i\n\n"), wd1 + wd2 - 26, system.bus.number - 1))
    end
end

function printMiddle(system::PowerSystem, analysis::PmuStateEstimation, verbose::Int64)
    if verbose == 2 || verbose == 3
        entries = nnz(analysis.method.coefficient)
        message = "Number of entries in the coefficient matrix:"

        wd1 = textwidth(string(entries)) + 1
        wd2 = textwidth(message)

        print(message)
        print(format(Format("%*i\n"), wd1, entries))

        print("Number of measurement functions:")
        print(format(Format("%*i\n"), wd1 + wd2 - 32, lastindex(analysis.method.mean)))

        print("Number of state variables:")
        print(format(Format("%*i\n\n"), wd1 + wd2 - 26, 2 * system.bus.number))
    end
end

##### Solver Data #####
function printSolver(analysis::AcPowerFlow, delP::Float64, delQ::Float64, verbose::Int64)
    if verbose == 2 || verbose == 3
        if analysis.method.iteration % 10 == 0
            println("-"^63)
            println("Iteration   Maximum Active Mismatch   Maximum Reactive Mismatch")
            println("-"^63)
        end
        print(format(Format("%*i "), 9, analysis.method.iteration))
        print(format(Format("%*.8e"), 25, delP))
        print(format(Format("%*.8e\n"), 28, delQ))
    end
end

function printSolver(
    system::PowerSystem,
    analysis::AcPowerFlow{<:Union{NewtonRaphson, FastNewtonRaphson}},
    verbose::Int64,
)

    if verbose == 2 || verbose == 3
        mag, ang = minmaxIncrement(system, analysis)

        println()
        print(" "^23)
        print("Minimum Value   Maximum Value")

        print("\nMagnitude Increment:")
        print(format(Format("%*.4e"), 16, mag[1]))
        print(format(Format("%*.4e\n"), 16, mag[2]))

        print("Angle Increment:")
        print(format(Format("%*.4e"), 20, ang[1]))
        print(format(Format("%*.4e\n\n"), 16, ang[2]))
    end
end

function printSolver(::PowerSystem, ::AcPowerFlow{GaussSeidel}, verbose::Int64)
    if verbose == 2 || verbose == 3
        println()
    end
end

function minmaxIncrement(system::PowerSystem, analysis::AcPowerFlow{<:NewtonRaphson})
    increment = analysis.method.increment
    extrema(abs, @view increment[1:(system.bus.number - 1)]),
    extrema(abs, @view increment[system.bus.number:end])
end

function minmaxIncrement(::PowerSystem, analysis::AcPowerFlow{<:FastNewtonRaphson})
    extrema(abs, analysis.method.active.increment),
    extrema(abs, analysis.method.reactive.increment)
end

function printSolver(analysis::AcStateEstimation, inc::Float64, verbose::Int64)
    if verbose == 2 || verbose == 3
        if analysis.method.iteration % 10 == 0
            println("-"^47)
            println("Iteration   Objective Value   Maximum Increment")
            println("-"^47)
        end

        print(format(Format("%*i "), 9, analysis.method.iteration))
        print(format(Format("%*.8e"), 17, analysis.method.objective))
        print(format(Format("%*.8e\n"), 20, inc))
    end
end

function printSolver(system::PowerSystem, analysis::AcStateEstimation, verbose::Int64)
    if verbose == 2 || verbose == 3
        residual = analysis.method.residual
        precision = analysis.method.precision
        maxres, idxres = findmax(abs, residual)
        maxwrss, idxwrss = findmax(i -> residual[i]^2 * precision[i, i], eachindex(residual))

        println()
        print(" "^20)
        print("Measurement   Maximum Value")

        print("\nAbsolute Residual:")
        print(format(Format("%*i"), 13, idxres))
        print(format(Format("%*.4e\n"), 16, maxres))

        print("Objective Value:")
        print(format(Format("%*i"), 15, idxwrss))
        print(format(Format("%*.4e\n\n"), 16, maxwrss))
    end
end

##### Print Exit Messages #####
function printExit(analysis::AC, maxExceeded::Bool, converged::Bool, verbose::Int64)
    if verbose != 0
        method = printMethodName(analysis)
        if converged
            println(
                "EXIT: The solution was found using the ", method,
                " method in ", analysis.method.iteration, " iterations."
            )
        else
            if maxExceeded
                println("EXIT: The ", method, " method exceeded the maximum number of iterations.")
            else
                println("EXIT: The ", method, " method failed to converge.")
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
                println("EXIT: Solved to acceptable level.")
            elseif status == MOI.LOCALLY_INFEASIBLE
                println("EXIT: Converged to a point of local infeasibility. Problem may be infeasible.")
            elseif status == MOI.NUMERICAL_ERROR
                println("EXIT: Restoration failed.")
            else
                println("EXIT: The optimal solution was not found.")
            end
        end
    end
end

function printExit(::DcPowerFlow, verbose::Int64)
    if verbose != 0
        println("EXIT: The solution of the DC power flow was found.")
    end
end

function printExit(::DcStateEstimation, verbose::Int64)
    if verbose != 0
        println("EXIT: The solution of the DC state estimation was found.")
    end
end

function printExit(::PmuStateEstimation, verbose::Int64)
    if verbose != 0
        println("EXIT: The solution of the PMU state estimation was found.")
    end
end

function printMethodName(::AcPowerFlow{<:NewtonRaphson})
    "Newton-Raphson"
end

function printMethodName(::AcPowerFlow{<:FastNewtonRaphson})
    "fast Newton-Raphson"
end

function printMethodName(::AcPowerFlow{GaussSeidel})
    "Gauss-Seidel"
end

function printMethodName(::AcStateEstimation)
    "Gauss-Newton"
end
