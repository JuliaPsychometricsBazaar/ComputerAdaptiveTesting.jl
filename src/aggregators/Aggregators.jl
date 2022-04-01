"""
This module takes care of integrating and optimizing over the ability/difficulty
space. It includes TrackedResponses, which can store cumulative results during a
test.
"""
module Aggregators

using StaticArrays: SVector

using ..ItemBanks: AbstractItemBank, ItemResponse, AbilityLikelihood, LikelihoodFunction
using ..Responses: BareResponses

export AbilityEstimator, TrackedResponses, AbilityTracker
export NullAbilityTracker
export response_expectation, add_response!, pop_response!, integrate, expectation, distribution_estimator
export PriorAbilityEstimator, LikelihoodAbilityEstimator, ModeAbilityEstimator, MeanAbilityEstimator
export Speculator, replace_speculation!

# Basic types
abstract type AbilityEstimator end
abstract type DistributionAbilityEstimator <: AbilityEstimator end
abstract type PointAbilityEstimator <: AbilityEstimator end

abstract type AbilityTracker end

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
const OPTIM_TOL = 1e-12
const INT_TOL = 1e-8

# Includes
include("./ability_estimator.jl")
include("./ability_tracker.jl")
include("./speculators.jl")

end