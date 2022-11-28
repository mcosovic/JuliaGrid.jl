using Documenter, JuliaGrid

makedocs(
    sitename = "JuliaGrid",
    modules = [JuliaGrid],
    clean = false,
    doctest = false,
    format = Documenter.HTML(
        assets=["assets/tablestyle.css"],
        collapselevel = 1
        ),
    pages = [
        "Home" => "index.md",
        "Power System" =>
            ["Power System Model" => "powerSystem/model.md",
             "Build Power System Model" => "powerSystem/buildModel.md",
             "In-depth AC and DC Model" => "powerSystem/inDepthACDCModel.md"],
        "Power Flow" =>
            ["Power Flow Solution" => "powerFlow/solution.md",
             "In-depth Power Flow Solution" => "powerFlow/inDepthPowerFlow.md"],
        # "Operating State" =>
        #     ["Operating State of Buses" => "operatingState/bus.md",
        #      "Operating State of Branches" => "operatingState/branch.md",
        #      "Operating State of Generators" => "operatingState/generator.md"]
    ]
)

deploydocs(
    repo = "github.com/mcosovic/JuliaGrid.jl.git",
    target = "build",
)
