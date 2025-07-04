using Base.Filesystem: mktempdir
using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.Aggregators
using FittedItemBanks.DummyData: dummy_full, SimpleItemBankSpec, StdModel3PL,
                                 VectorContinuousDomain, BooleanResponse, std_normal
using FittedItemBanks
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.TerminationConditions
using ComputerAdaptiveTesting.Sim
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.Optimizers
using ComputerAdaptiveTesting.DecisionTree
using ComputerAdaptiveTesting: Stateful, CatRules
using Distributions
using Distributions: ZeroMeanIsoNormal, Zeros, ScalMat
using Optim
using Random

using Test

include("./dummy.jl")
using .Dummy

@testset verbose=true "Test ComputerAdaptiveTesting.jl" begin
    include("./aqua.jl")
    include("./jet.jl")
    include("./ability_estimator_1d.jl")
    include("./ability_estimator_2d.jl")
    include("./smoke.jl")
    include("./dt.jl")
    include("./stateful.jl")
    include("./compat.jl")
end
