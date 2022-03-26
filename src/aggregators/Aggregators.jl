"""
This module takes care of integrating and optimizing over the ability/difficulty
space. It includes TrackedResponses, which can store cumulative results during a
test.
"""
module Aggregators

using ..ItemBanks: AbstractItemBank

# Basic types
abstract type AbilityEstimator end
abstract type DistributionAbilityEstimator <: AbilityEstimator end
abstract type PointAbilityEstimator <: AbilityEstimator end

abstract type AbilityTracker end

mutable struct BareResponses
    indices::Vector{Int32}
    values::Vector{Int8}
end

BareResponses() = BareResponses([], [])

mutable struct TrackedResponses{
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
    length(responses.indices)
end

# Includes
include("./ability_estimator.jl")
include("./ability_tracker.jl")

end