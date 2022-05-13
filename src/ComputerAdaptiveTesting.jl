module ComputerAdaptiveTesting

using Pkg
using Reexport
using Requires

export ExtraDistributions, IntegralCoeffs, Integrators, Interpolators, Optimizers
export ConfigBase, Responses, IOUtils, ItemBanks, Aggregators, NextItemRules, TerminationConditions
export CatConfig, Sim, DummyData, Postprocess
    
# Maths stuff (no dependencies)
include("./maths/ExtraDistributions.jl")
include("./maths/IntegralCoeffs.jl")
include("./maths/Interpolators.jl")
include("./maths/Optimizers.jl")
include("./maths/MathTraits.jl")

# Base
include("./ConfigBase.jl")
include("./Responses.jl")
include("./IOUtils.jl")

# Near base
include("./maths/Integrators.jl")
include("./item_banks/ItemBanks.jl")
include("./aggregators/Aggregators.jl")

# Stages
include("./next_item_rules/NextItemRules.jl")
include("./TerminationConditions.jl")

# Combining / running
include("./CatConfig.jl")
include("./Sim.jl")

# Peripheral / contrib
#=
https://github.com/JuliaPackaging/Requires.jl/issues/109

function require_extra(cb, extra)
    function helper(tail)
        if length(tail) > 0
            pkg = tail[1]
            pkgid = Base.PkgId(pkg.uuid, pkg.name)
            @info "Checking for", pkg.name
            @require_pkgid pkgid begin
                @info "Got", pkg.name
                helper(tail[2:end])
            end
        else
            cb()
        end
    end
    helper(extras[extra])
end
=#

function __init__()
    #require_extra("plots") do end
    @require Makie="ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a" begin
        include("Plots.jl")
        export Plots
    end
end
include("DummyData.jl")
include("postprocess/Postprocess.jl")

@reexport using .CatConfig: CatLoopConfig, CatRules
@reexport using .Sim: run_cat

function pkg(name, uuid)
    PackageSpec(name, Base.UUID(uuid))
end

const extras = Dict(
    "docs" => [
        pkg("Documenter", "e30172f5-a6a5-5a46-863b-614d45cd2de4"),
        pkg("Literate", "98b081ad-f1c9-55d3-8b20-4c87d4299306")
    ],
    "plots" => [
        pkg("Makie", "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"),
        pkg("CairoMakie", "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"),
        pkg("GLMakie", "e9467ef8-e4e7-5192-8a1a-b1aee30e663a"),
        pkg("WGLMakie", "276b4fcb-3e11-5398-bf8b-a0c2d153d008"),
        pkg("DataFrames", "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"),
        pkg("AlgebraOfGraphics", "cbdf2221-f076-402e-a563-3d30da359d67")
    ],
    "dev" => [
        pkg("PProf", "e4faabce-9ead-11e9-39d9-4379958e3056"),
        pkg("StatProfilerHTML", "a8a75453-ed82-57c9-9e16-4cd1196ecbf5"),
        pkg("JET", "c3a54625-cd67-489e-a8e7-0a5a0ff4e31b"),
        pkg("Revise", "295af30f-e4ad-537b-8983-00126c2a3abe")
    ]
)

"""
Installs groups of optional dependencies for specific functionality can be 'plots', 'dev' or 'all'.
"""
function install_extra(extra)
    pkgs::Vector{PackageSpec} = []
    if extra in ["all" "all_headless"]
        for (_, specs) in extras
            append!(pkgs, [spec for spec in specs if extra != "all_headless" || spec.name != "GLMakie"])
        end
    else
        append!(pkgs, extras[extra])
    end
    Pkg.add(pkgs)
end

end