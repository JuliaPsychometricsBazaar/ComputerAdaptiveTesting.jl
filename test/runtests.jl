using Test

include("./utils.jl")

using .CATTestUtils: @namedtestset

@namedtestset aqua "Aqua automated quality checks" begin
    using Aqua
    using CATPlots
    using ComputerAdaptiveTesting
    using IRTSupport
    print("Aqua automated quality checks")
    Aqua.test_all(
        ComputerAdaptiveTesting;
        ambiguities=false,
        stale_deps=false,
        deps_compat=false #tmp
    )
    Aqua.test_all(
        IRTSupport;
        ambiguities=false
    )
    Aqua.test_all(
        CATPlots;
        ambiguities=false,
        stale_deps=false # GLMakie is not loaded by CATPlots
                         # (could possibly be removed as a dependency anyway)
    )
    # Ambiguities are not tested in default configuration as a workaround for
    # https://github.com/JuliaTesting/Aqua.jl/issues/77
    # Core is not included because of Core.Number, namely

    # CATPlots gets lots of errors from Makie extending Core.Number
    # Could possibly get some of these fixed in Makie eventually?
    Aqua.test_ambiguities([CATPlots])

    # ComputerAdaptiveTesting gets errors from FowardDiff extending Core.Number
    # Could possibly get some of these fixed in ForwardDiff eventually?
    # https://github.com/JuliaDiff/ForwardDiff.jl/issues/597
    Aqua.test_ambiguities([ComputerAdaptiveTesting])
    Aqua.test_ambiguities([IRTSupport])
end

@namedtestset ability_estimator_1d "1-dimensional ability estimators" begin
    include("./ability_estimator_1d.jl")
end

@namedtestset ability_estimator_2d "1-dimensional ability estimators" begin
    include("./ability_estimator_2d.jl")
end

@namedtestset smoke "Smoke tests" begin
    include("./smoke.jl")
end
