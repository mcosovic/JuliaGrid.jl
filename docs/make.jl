using Documenter, JuliaGrid
using JuMP, HiGHS

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
            "DC Optimal Power Flow" => "manual/dcOptimalPowerFlow.md"],
        "Tutorials" =>
            ["AC and DC Model" => "tutorials/acdcModel.md",
            "AC Power Flow" => "tutorials/acPowerFlow.md",
            "DC Power Flow" => "tutorials/dcPowerFlow.md"],
        "API Reference" =>
            ["Power System Model" => "api/powerSystemModel.md",
            "AC Power Flow Solution" => "api/acPowerFlowSolution.md",
            "DC Power Flow Solution" => "api/dcPowerFlowSolution.md",
            "DC Optimal Power Flow Solution" => "api/dcOptimalPowerFlowSolution.md",
            "AC Power and Current Analysis" => "api/acAnalysis.md",
            "DC Power Analysis" => "api/dcAnalysis.md",
            "Configuration Setup" => "api/configuration.md"]
    ]
)

deploydocs(
    repo = "github.com/mcosovic/JuliaGrid.jl.git",
    target = "build",
)
