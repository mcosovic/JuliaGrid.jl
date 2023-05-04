using Documenter, JuliaGrid

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
            "Power Flow Analysis" => "manual/powerFlowAnalysis.md"],
        "Tutorials" =>
            ["AC and DC Model" => "tutorials/acdcModel.md",
            "AC Power Flow Analysis" => "tutorials/acPowerFlowAnalysis.md",
            "DC Power Flow Analysis" => "tutorials/dcPowerFlowAnalysis.md"],
        "API Reference" =>
            ["Power System Model" => "api/powerSystemModel.md",
            "Power Flow Solution" => "api/powerFlowSolution.md",
            "Postprocessing Analysis" => "api/postprocessing.md",
            "Configuration Setup" => "api/configuration.md",
            "Wrapper Functions" => "api/wrapper.md"]
    ]
)

deploydocs(
    repo = "github.com/mcosovic/JuliaGrid.jl.git",
    target = "build",
)
