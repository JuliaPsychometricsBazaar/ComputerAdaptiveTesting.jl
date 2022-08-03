using ComputerAdaptiveTesting
using CATPlots

using Documenter
using Literate
using DemoCards

DocMeta.setdocmeta!(ComputerAdaptiveTesting, :DocTestSetup, :(using ComputerAdaptiveTesting; using CATPlots); recursive=true)

demopage, postprocess_cb, demo_assets = makedemos("examples"; throw_error=true)

assets = []
isnothing(demo_assets) || (push!(assets, demo_assets))

format = Documenter.HTML(
    prettyurls=get(ENV, "CI", "false") == "true",
    canonical="https://frankier.github.io/ComputerAdaptiveTesting.jl",
    assets=assets
)

makedocs(;
    modules=[ComputerAdaptiveTesting, CATPlots],
    authors="Frankie Robertson",
    repo="https://github.com/frankier/ComputerAdaptiveTesting.jl/blob/{commit}{path}#{line}",
    sitename="ComputerAdaptiveTesting.jl",
    format=format,
    pages=[
        "Home" => "index.md",
        demopage,
    ],
)

deploydocs(;
    repo="github.com/frankier/ComputerAdaptiveTesting.jl",
    devbranch="main",
)
