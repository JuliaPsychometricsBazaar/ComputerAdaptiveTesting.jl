using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.ItemBanks
using ComputerAdaptiveTesting.Integrators
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.Optimizers
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.TerminationConditions
using ComputerAdaptiveTesting.Sim
using IRTSupport
using CATPlots
using Test
using Aqua
using Distributions
using Distributions: ZeroMeanIsoNormal, Zeros, ScalMat
using Optim
using Random

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
    ambiguities=false
)
# Workaround for https://github.com/JuliaTesting/Aqua.jl/issues/77
Aqua.test_ambiguities([
    ComputerAdaptiveTesting,
    IRTSupport,
    CATPlots,
    Core
])

include("./ability_estimator_1d.jl")
include("./ability_estimator_2d.jl")
include("./smoke.jl")
