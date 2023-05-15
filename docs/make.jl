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
            "AC Power Flow" => "manual/acPowerFlow.md",
            "DC Power Flow" => "manual/dcPowerFlow.md"],
        "Tutorials" =>
            ["AC and DC Model" => "tutorials/acdcModel.md",
            "AC Power Flow" => "tutorials/acPowerFlow.md",
            "DC Power Flow" => "tutorials/dcPowerFlow.md"],
        "API Reference" =>
            ["Power System Model" => "api/powerSystemModel.md",
            "AC Power Flow" => "api/acPowerFlow.md",
            "DC Power Flow" => "api/dcPowerFlow.md",
            "Optimal Power Flow" => "api/optimaPowerFlow.md",
            "Configuration Setup" => "api/configuration.md"]
    ]
)

deploydocs(
    repo = "github.com/mcosovic/JuliaGrid.jl.git",
    target = "build",
)
