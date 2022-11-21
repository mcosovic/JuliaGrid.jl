using Documenter, JuliaGrid

makedocs(
    sitename = "JuliaGrid",
    modules = [JuliaGrid],
    clean = false,
    doctest = false,
    format = Documenter.HTML(assets=["assets/tablestyle.css"]),
    pages = [
        "Home" => "index.md",
        "Power System" =>
            ["Power System Model" => "man/powerSystemModel.md"],
    ]
)

deploydocs(
    repo = "github.com/mcosovic/JuliaGrid.jl.git",
    target = "build",
)
