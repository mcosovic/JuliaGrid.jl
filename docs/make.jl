using Documenter, JuliaGrid
using JuMP, HiGHS, Ipopt, GLPK

makedocs(
    sitename = "JuliaGrid",
    modules = [JuliaGrid],
    clean = false,
    doctest = false,
    format = Documenter.HTML(
        assets=["assets/tablestyle.css"],
        prettyurls = get(ENV, "CI", nothing) == "true",
        collapselevel = 1
        ),
    pages = [
        "Introduction" => "index.md",
        "Manual" =>
            ["Power System Model" => "manual/powerSystemModel.md",
             "AC Power Flow" => "manual/acPowerFlow.md",
             "DC Power Flow" => "manual/dcPowerFlow.md",
             "AC Optimal Power Flow" => "manual/acOptimalPowerFlow.md",
             "DC Optimal Power Flow" => "manual/dcOptimalPowerFlow.md",
             "Measurement Model" => "manual/measurementModel.md",
             "PMU State Estimation" => "manual/pmuStateEstimation.md",
             "DC State Estimation" => "manual/dcStateEstimation.md"],
        "Tutorials" =>
            ["AC and DC Model" => "tutorials/acdcModel.md",
             "AC Power Flow" => "tutorials/acPowerFlow.md",
             "DC Power Flow" => "tutorials/dcPowerFlow.md",
             "AC Optimal Power Flow" => "tutorials/acOptimalPowerFlow.md",
             "DC Optimal Power Flow" => "tutorials/dcOptimalPowerFlow.md",
             "Measurement Model" => "tutorials/measurementModel.md",
             "DC State Estimation" => "tutorials/dcStateEstimation.md"],
        "API Reference" =>
            ["Power System Model" => "api/powerSystemModel.md",
             "Power Flow" => "api/powerFlow.md",
             "Optimal Power Flow" => "api/optimalPowerFlow.md",
             "Measurement Model" => "api/measurementModel.md",
             "State Estimation" => "api/stateEstimation.md",
             "Power and Current Analysis" => "api/analysis.md",
             "Configuration Setup" => "api/configuration.md"]
    ]
)

deploydocs(
    repo = "github.com/mcosovic/JuliaGrid.jl.git",
    target = "build",
)
