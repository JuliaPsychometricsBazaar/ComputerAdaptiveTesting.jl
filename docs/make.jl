using ComputerAdaptiveTesting
using CATPlots

using Documenter
using Documenter.Remotes: GitHub
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
    repo=GitHub("JuliaPsychometricsBazaar", "ComputerAdaptiveTesting.jl"),
    sitename="ComputerAdaptiveTesting.jl",
    format=format,
    pages=[
        "Getting started" => "index.md",
        "Creating a CAT" => "creating_a_cat.md",
        "Using your CAT" => "using_your_cat.md",
        (build_demos ? demopage : "Demo page skipped" => []),
        "API reference" => "api.md",
        "Contributing" => "contributing.md",
    ],
    warnonly=[:missing_docs, :cross_references]
)

postprocess_cb()

deploydocs(;
    repo="github.com/frankier/ComputerAdaptiveTesting.jl",
    devbranch="main",
)
