using Documenter, JuliaGrid

makedocs(
    sitename = "JuliaGrid",
    modules = [ JuliaGrid ],
    pages = [
        "Home" => "index.md",
        "Power Flow" => "man/flow.md"
    ]
)

deploydocs(
    repo = "github.com/mcosovic/JuliaGrid.git",
    target = "build",
    push_preview = true,
)
