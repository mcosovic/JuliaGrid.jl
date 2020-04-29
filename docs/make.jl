using Documenter, JuliaGrid

makedocs(
    sitename = "JuliaGrid",
    modules = [JuliaGrid],
    clean = false,
    doctest = false,
    format = Documenter.HTML(assets=["assets/style.css"]),
    pages = [
        "Home" => "index.md",
        "Power Flow" => "man/flow.md",
        "Measurement Generator" => "man/generator.md",
        "State Estimation" => "man/estimation.md",    
    ]
)

deploydocs(
    repo = "github.com/mcosovic/JuliaGrid.jl.git",
    target = "build",
)
