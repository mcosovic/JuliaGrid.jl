using Documenter, JuliaGrid

using Pkg
pkg"activate .."
push!(LOAD_PATH,"../src/")


makedocs(;
    modules=[JuliaGrid],
	format = Documenter.HTML(
        prettyurls = prettyurls = get(ENV, "CI", nothing) == "true",
    ),
    pages=[
    "Home" => "index.md",
    "Power Flow" => "man/flow.md"
    ],
    repo="https://github.com/mcosovic/JuliaGrid/{commit}{path}#L{line}",
    sitename="JuliaGridd",
    authors="Mirsad Cosovic",
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
# deploydocs(;
#     repo="github.com/juliamatlab/MatLang.git",
# )
