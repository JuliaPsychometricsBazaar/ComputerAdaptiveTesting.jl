"""
This module takes care of integrating and optimizing over the ability/difficulty
space. It includes TrackedResponses, which can store cumulative results during a
test.
"""
module Aggregators

using StaticArrays: SVector

using ..ItemBanks: AbstractItemBank, ItemResponse, AbilityLikelihood, LikelihoodFunction
using ..Responses: BareResponses
using ..MathTraits
using ..ConfigBase

export AbilityEstimator, TrackedResponses, AbilityTracker
export NullAbilityTracker
export response_expectation, add_response!, pop_response!, integrate, expectation, distribution_estimator
export PriorAbilityEstimator, LikelihoodAbilityEstimator, ModeAbilityEstimator, MeanAbilityEstimator
export Speculator, replace_speculation!

# Basic types
abstract type AbilityEstimator end

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
    @returnsome Integrator(bits...) integrator -> MeanAbilityEstimator(LikelihoodAbilityEstimator(integrator))
end

abstract type DistributionAbilityEstimator <: AbilityEstimator end
abstract type PointAbilityEstimator <: AbilityEstimator end

abstract type AbilityTracker end

function AbilityTracker(bits...; ability_estimator=nothing)
    @returnsome find1_instance(AbilityTracker, bits)
    ability_tracker = find1_type(AbilityTracker, bits)
    if (ability_tracker !== nothing)
        ability_tracker()
    end
    NullAbilityTracker()
    # TODO: find if ability_estimator is GriddedAbilityEstimator and then propagate stuff to GriddedAbilityTracker
end

struct TrackedResponses{
    ItemBankT <: AbstractItemBank,
    AbilityTrackerT <: AbilityTracker,
    AbilityEstimatorT <: AbilityEstimator
}
    responses::BareResponses
    item_bank::ItemBankT
    ability_tracker::AbilityTrackerT
    ability_estimator::AbilityEstimatorT
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
include("./speculators.jl")

end