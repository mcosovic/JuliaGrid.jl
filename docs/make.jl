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
            ["AC and DC Model" => "tutorials/modelACDC.md",
            "Power Flow Solution" => "tutorials/powerFlowSolution.md"],
        "API Reference" =>
            ["Power System Model" => "api/powerSystemModel.md",
            "Power Flow Solution" => "api/powerFlowSolution.md",
            "Unit System" => "api/unit.md",
            "Utility" => "api/utility.md"]
    ]
)

deploydocs(
    repo = "github.com/mcosovic/JuliaGrid.jl.git",
    target = "build",
)
