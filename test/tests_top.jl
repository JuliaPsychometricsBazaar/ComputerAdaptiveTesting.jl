using Base.Filesystem: mktempdir
using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.Aggregators
using FittedItemBanks.DummyData: dummy_full, SimpleItemBankSpec, StdModel3PL,
                                 VectorContinuousDomain, BooleanResponse, std_normal
using FittedItemBanks
using ComputerAdaptiveTesting.CatConfig
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.TerminationConditions
using ComputerAdaptiveTesting.Sim
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.Optimizers
using ComputerAdaptiveTesting.DecisionTree
using Distributions
using Distributions: ZeroMeanIsoNormal, Zeros, ScalMat
using Optim
using Random
using ResumableFunctions

using XUnit

include("./dummy.jl")
using .Dummy

@testset "aqua" begin
    include("./aqua.jl")
end

@testset "jet" begin
    include("./jet.jl")
end

@testset "abilest_1d" begin
    include("./ability_estimator_1d.jl")
end

@testset "abilest_2d" begin
    include("./ability_estimator_2d.jl")
end

@testset "smoke" begin
    include("./smoke.jl")
end

@testset "dt" begin
    include("./dt.jl")
end

@testset "format" begin
    include("./format.jl")
end
