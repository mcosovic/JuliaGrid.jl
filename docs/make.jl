using Documenter, JuliaGrid
using JuMP, HiGHS, Ipopt, GLPK
using DocumenterCitations

makedocs(
    sitename = "JuliaGrid",
    modules = [JuliaGrid],
    clean = false,
    doctest = false,
    plugins = [
        CitationBibliography(
            joinpath(@__DIR__, "src", "background/references.bib");
            style=:numeric
        )
    ],
    format = Documenter.HTML(
        assets = ["assets/tablestyle.css", "assets/citations.css", "assets/subfigure.css"],
        prettyurls = get(ENV, "CI", nothing) == "true",
        collapselevel = 1
    ),
    pages = [
        "Introduction" => "index.md",
        "Manual" =>[
            "Power System Model" => "manual/powerSystemModel.md",
            "AC Power Flow" => "manual/acPowerFlow.md",
            "DC Power Flow" => "manual/dcPowerFlow.md",
            "AC Optimal Power Flow" => "manual/acOptimalPowerFlow.md",
            "DC Optimal Power Flow" => "manual/dcOptimalPowerFlow.md",
            "Measurement Model" => "manual/measurementModel.md",
            "Observability Analysis" => "manual/observabilityAnalysis.md",
            "AC State Estimation" => "manual/acStateEstimation.md",
            "PMU State Estimation" => "manual/pmuStateEstimation.md",
            "DC State Estimation" => "manual/dcStateEstimation.md",
            "Bad Data Analysis" => "manual/badDataAnalysis.md"
        ],
        "Tutorials" => [
            "Power System Model" => "tutorials/powerSystemModel.md",
            "AC Power Flow" => "tutorials/acPowerFlow.md",
            "DC Power Flow" => "tutorials/dcPowerFlow.md",
            "AC Optimal Power Flow" => "tutorials/acOptimalPowerFlow.md",
            "DC Optimal Power Flow" => "tutorials/dcOptimalPowerFlow.md",
            "Measurement Model" => "tutorials/measurementModel.md",
            "Observability Analysis" => "tutorials/observabilityAnalysis.md",
            "AC State Estimation" => "tutorials/acStateEstimation.md",
            "PMU State Estimation" => "tutorials/pmuStateEstimation.md",
            "DC State Estimation" => "tutorials/dcStateEstimation.md",
            "Per-Unit System" => "tutorials/perunit.md",
            "Bad Data Analysis" => "tutorials/badDataAnalysis.md"
        ],
        "Examples" => [
            "Power System Datasets" => "examples/powerSystemDatasets.md",
            "AC Power Flow" => "examples/acPowerFlow.md",
            "DC Power Flow" => "examples/dcPowerFlow.md",
            "AC Optimal Power Flow" => "examples/acOptimalPowerFlow.md",
            "DC Optimal Power Flow" => "examples/dcOptimalPowerFlow.md",
            "Observability Analysis" => "examples/observabilityAnalysis.md",
            "AC State Estimation" => "examples/acStateEstimation.md",
            "PMU State Estimation" => "examples/pmuStateEstimation.md",
            "DC State Estimation" => "examples/dcStateEstimation.md"
        ],
        "API Reference" =>[
            "Power System Model" => "api/powerSystemModel.md",
            "Power Flow" => "api/powerFlow.md",
            "Optimal Power Flow" => "api/optimalPowerFlow.md",
            "Measurement Model" => "api/measurementModel.md",
            "State Estimation" => "api/stateEstimation.md",
            "Powers and Currents" => "api/analysis.md",
            "Setup and Print" => "api/setupPrint.md",
            "Public Types" => "api/publicTypes.md"
        ],
        "Background" => [
            "Installation Guide" => "background/installation.md",
            "Bibliography" => "background/bibliography.md"
        ]
    ]
)

deploydocs(
    repo = "github.com/mcosovic/JuliaGrid.jl.git",
    target = "build",
)