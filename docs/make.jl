using Documenter
using PrettyTables

makedocs(
    modules = [JuliaGrid],
    format = Documenter.HTML(
        prettyurls = !("local" in ARGS),
        # canonical = "https://ronisbr.github.io/PrettyTables.jl/stable/",
    ),
    sitename = "JuliaGrid",
    authors = "Mirsad Cosovic",
    pages = [
        "Home"               => "index.md",
    ]
)

deploydocs(
    repo = "github.com/mcosovic/JuliaGrid.jl.git",
    target = "build",
)