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
        "Manual" => ["index.md"],
        "Tutorials" =>
            ["AC and DC Model" => "tutorials/modelACDC.md",
            "Power Flow Solution" => "tutorials/powerFlowSolution.md"],
        "API Reference" => 
            ["Power System Model" => "api/powerSystemModel.md",
            "AC and DC Model" => "api/modelACDC.md"]
    ]
)

deploydocs(
    repo = "github.com/mcosovic/JuliaGrid.jl.git",
    target = "build",
)
