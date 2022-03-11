using ComputerAdaptiveTesting
using Documenter

DocMeta.setdocmeta!(ComputerAdaptiveTesting, :DocTestSetup, :(using ComputerAdaptiveTesting); recursive=true)

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
    ],
)

deploydocs(;
    repo="github.com/frankier/ComputerAdaptiveTesting.jl",
    devbranch="main",
)
