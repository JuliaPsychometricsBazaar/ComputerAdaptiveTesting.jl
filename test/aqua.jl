using Aqua
using CATPlots
using ComputerAdaptiveTesting
using IRTSupport

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
