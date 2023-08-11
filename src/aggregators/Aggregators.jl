"""
This module takes care of integrating and optimizing over the ability/difficulty
space. It includes TrackedResponses, which can store cumulative results during a
test.
"""
module Aggregators

using PsychometricsBazaarBase.Parameters
using StaticArrays: SVector
using Distributions: Distribution, Normal, Distributions
using HCubature
using Base.Threads

using FittedItemBanks
using ..Responses
using ..Responses: concrete_response_type
using ..ConfigBase
using PsychometricsBazaarBase.ConfigTools
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase: Integrators
using PsychometricsBazaarBase.Optimizers
using PsychometricsBazaarBase.ConstDistributions: std_normal

import FittedItemBanks
import PsychometricsBazaarBase.IntegralCoeffs

export AbilityEstimator, TrackedResponses
export AbilityTracker, NullAbilityTracker, PointAbilityTracker, GriddedAbilityTracker
export ClosedFormNormalAbilityTracker, MultiAbilityTracker, track!
export response_expectation, add_response!, pop_response!, expectation, distribution_estimator
export PointAbilityEstimator, PriorAbilityEstimator, LikelihoodAbilityEstimator
export ModeAbilityEstimator, MeanAbilityEstimator
export Speculator, replace_speculation!, normdenom, maybe_tracked_ability_estimate
export AbilityIntegrator, AbilityOptimizer
export FunctionOptimizer, EnumerationOptimizer, FunctionIntegrator
export DistributionAbilityEstimator
export variance, variance_given_mean, mean_1d

# Basic types
# XXX: Does having a common supertype of DistributionAbilityEstimator and PointAbilityEstimator make sense?
abstract type AbilityEstimator <: CatConfigBase end

function AbilityEstimator(bits...; ability_estimator=nothing)
    @returnsome ability_estimator
    @returnsome find1_instance(AbilityEstimator, bits)
    item_bank = find1_type_sloppy(AbstractItemBank, bits)
    if item_bank !== nothing
        @returnsome AbilityEstimator(DomainType(item_bank))
    end
end
AbilityEstimator(::DomainType) = nothing
function AbilityEstimator(::ContinuousDomain, bits...)
    @returnsome Integrator(bits...) integrator -> MeanAbilityEstimator(LikelihoodAbilityEstimator(), integrator)
end

abstract type DistributionAbilityEstimator <: AbilityEstimator end
function DistributionAbilityEstimator(bits...)
    @returnsome find1_instance(DistributionAbilityEstimator, bits)
end

abstract type PointAbilityEstimator <: AbilityEstimator end
function PointAbilityEstimator(bits...)
    @returnsome find1_instance(PointAbilityEstimator, bits)
    mode_ability_estimator = find1_type(ModeAbilityEstimator, bits)
    if mode_ability_estimator !== nothing
        return mode_ability_estimator(bits...)
    end
    mean_ability_estimator = find1_type(MeanAbilityEstimator, bits)
    if mean_ability_estimator !== nothing
        return mean_ability_estimator(bits...)
    end
end

abstract type AbilityTracker <: CatConfigBase end

function AbilityTracker(bits...; ability_estimator=nothing)
    @returnsome find1_instance(AbilityTracker, bits)
    ability_tracker = find1_type(AbilityTracker, bits)
    if (ability_tracker !== nothing)
        ability_tracker()
    end
    NullAbilityTracker()
    # TODO: find if ability_estimator is GriddedAbilityEstimator and then propagate stuff to GriddedAbilityTracker
end

abstract type AbilityIntegrator <: CatConfigBase end
function AbilityIntegrator(bits...; ability_estimator=nothing)
    @returnsome find1_instance(AbilityIntegrator, bits)
    zero_arg_intergrators = find1_type(RiemannEnumerationIntegrator, bits)
    if (zero_arg_intergrators !== nothing)
        return RiemannEnumerationIntegrator()
    end
    @returnsome Integrator(bits...) integrator -> FunctionIntegrator(integrator)
end

abstract type AbilityOptimizer end
function AbilityOptimizer(bits...; ability_estimator=nothing)
    @returnsome find1_instance(AbilityOptimizer, bits)
    zero_arg_optimizers = find1_type(EnumerationOptimizer, bits)
    if (zero_arg_optimizers !== nothing)
        return EnumerationOptimizer()
    end
    @returnsome Optimizer(bits...) optimizer -> FunctionOptimizer(optimizer)
end

@with_kw struct TrackedResponses{
    BareResponsesT <: BareResponses,
    ItemBankT <: AbstractItemBank,
    AbilityTrackerT <: AbilityTracker
}
    responses::BareResponsesT
    item_bank::ItemBankT
    ability_tracker::AbilityTrackerT = NullAbilityTracker()
end

TrackedResponses(responses, item_bank) = TrackedResponses(responses, item_bank, NullAbilityTracker())

function Responses.AbilityLikelihood(
    tracked_responses::TrackedResponses{BareResponsesT, ItemBankT, AbilityTrackerT}
) where {
    BareResponsesT <: BareResponses,
    ItemBankT <: AbstractItemBank,
    AbilityTrackerT <: AbilityTracker
}
    Responses.AbilityLikelihood{ItemBankT, BareResponsesT}(tracked_responses.item_bank, tracked_responses.responses)
end

function Base.length(responses::TrackedResponses)
    length(responses.responses.indices)
end

# Defaults
const optim_tol = 1e-12
const int_tol = 1e-8

# Includes
include("./ability_estimator.jl")
include("./ability_tracker.jl")
include("./integrators.jl")
include("./optimizers.jl")
include("./speculators.jl")

end
