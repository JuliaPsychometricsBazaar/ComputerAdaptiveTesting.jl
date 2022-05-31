using Makie  # for ComputerAdaptiveTesting.Plots
using ComputerAdaptiveTesting

using Documenter
using Literate

DocMeta.setdocmeta!(ComputerAdaptiveTesting, :DocTestSetup, :(using ComputerAdaptiveTesting); recursive=true)

#EXAMPLE = joinpath(@__DIR__, "..", "examples", "ability_convergence_3pl.jl")
#OUTPUT = joinpath(@__DIR__, "src/generated")

#Literate.markdown(EXAMPLE, OUTPUT, execute=true, documenter=true)
#Literate.notebook(EXAMPLE, OUTPUT, documenter=true)

makedocs(;
    modules=[ComputerAdaptiveTesting],
    authors="Frankie Robertson",
    repo="https://github.com/frankier/ComputerAdaptiveTesting.jl/blob/{commit}{path}#{line}",
    sitename="ComputerAdaptiveTesting.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://frankier.github.io/ComputerAdaptiveTesting.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        #"Tutorial" => "generated/ability_convergence_3pl.md",
    ],
)

deploydocs(;
    repo="github.com/frankier/ComputerAdaptiveTesting.jl",
    devbranch="main",
)
