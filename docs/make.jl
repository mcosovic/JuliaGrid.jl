using Documenter, JuliaGrid

makedocs(
    sitename = "JuliaGrid",
    authors = "Mirsad Cosovic",
    format = Documenter.HTML(
        canonical = "a",
    ),
    pages = [
        "Home" => "index.md",
        "Power Flow" => "man/flow.md"
    ]
)

deploydocs(
    repo = "github.com/mcosovic/JuliaGrid.jl.git",
)
