using ComputerAdaptiveTesting
using CATPlots

using Documenter
using Documenter.Remotes: GitHub
using Literate
using DemoCards

build_demos = !("SKIP_DEMOS" in keys(ENV))

DocMeta.setdocmeta!(ComputerAdaptiveTesting,
    :DocTestSetup,
    :(using ComputerAdaptiveTesting; using CATPlots);
    recursive = true)

if build_demos
    demopage, postprocess_cb, demo_assets = makedemos("examples"; throw_error = true)
end

assets = []
if build_demos
    isnothing(demo_assets) || (push!(assets, demo_assets))
end

format = Documenter.HTML(prettyurls = get(ENV, "CI", "false") == "true",
    canonical = "https://JuliaPsychometricsBazaar.github.io/ComputerAdaptiveTesting.jl",
    assets = assets)

makedocs(;
    modules = [ComputerAdaptiveTesting, CATPlots],
    authors = "Frankie Robertson",
    repo = GitHub("JuliaPsychometricsBazaar", "ComputerAdaptiveTesting.jl"),
    sitename = "ComputerAdaptiveTesting.jl",
    format = format,
    pages = [
        "Getting started" => "index.md",
        "Creating a CAT" => "creating_a_cat.md",
        "Using your CAT" => "using_your_cat.md",
        (build_demos ? demopage : "Demo page skipped" => []),
        "API reference" => "api.md",
        "Contributing" => "contributing.md",
    ],
    warnonly = [:missing_docs],
    linkcheck = true)

if build_demos
    postprocess_cb()
end

deploydocs(;
    repo = "github.com/JuliaPsychometricsBazaar/ComputerAdaptiveTesting.jl",
    devbranch = "main",)
