using Documenter, JuliaGrid

makedocs(
    sitename = "JuliaGrid",
    modules = [JuliaGrid],
    clean = false,
    doctest = false,
    format = Documenter.HTML(assets=["assets/style.css"]),
    pages = [
        "Home" => "index.md",
        "Input Data" => "man/input.md",
        "Power Flow" => "man/flow.md",
        "Optimal Power Flow" => "man/optimalflow.md",
        "State Estimation" => "man/estimation.md",
        "Measurement Generator" => "man/generator.md",
        "Theoretical Background" => [
            "Network Equations" => "man/tbbranch.md",
            "Power Flow" => "man/tbflow.md",
            "State Estimation" => "man/tbestimate.md",
            "State Estimation Routines" => "man/tbestimaterest.md",
        ],
    ]
)

deploydocs(
    repo = "github.com/mcosovic/JuliaGrid.jl.git",
    target = "build",
)
