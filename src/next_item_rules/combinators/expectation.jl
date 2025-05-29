#=
This file implements next item combinators which take a state criterion
or item criterion and look at its value in expectation with regards to
a particular item.
=#

abstract type ResponseExpectation end

function ResponseExpectation(ability_estimator::PointAbilityEstimator,
        bits...)
    PointResponseExpectation(ability_estimator)
end

function ResponseExpectation(ability_estimator::DistributionAbilityEstimator,
        bits...)
    @returnsome Integrator(bits...) integrator->DistributionResponseExpectation(
        ability_estimator,
        integrator)
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

This `ResponseExpectation` gets expected outcomes based on a point ability estimates.
"""
struct PointResponseExpectation{
    PointAbilityEstimatorT <: PointAbilityEstimator,
} <: ResponseExpectation
    ability_estimator::PointAbilityEstimatorT
end

function Aggregators.response_expectation(
        point_response_expectation::PointResponseExpectation,
        tracked_responses,
        item_idx)
    response_expectation(point_response_expectation.ability_estimator,
        tracked_responses,
        item_idx)
end

struct DistributionResponseExpectation{
    DistributionAbilityEstimatorT <: DistributionAbilityEstimator,
    AbilityIntegratorT <: AbilityIntegrator
} <: ResponseExpectation
    ability_estimator::DistributionAbilityEstimatorT
    integrator::AbilityIntegratorT
end

function Aggregators.response_expectation(
        dist_response_expectation::DistributionResponseExpectation,
        tracked_responses,
        item_idx)
    response_expectation(dist_response_expectation.ability_estimator,
        dist_response_expectation.integrator,
        tracked_responses,
        item_idx)
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

This ItemCriterion wraps a a `ResponseExpectation` and a `StateCriterion` or
`ItemCriterion` to look at the criterion's expected value for a particular
item 1-ply ahead.
"""
struct ExpectationBasedItemCriterion{
    ResponseExpectationT <: ResponseExpectation,
    CriterionT <: Union{StateCriterion, ItemCriterion, ItemCategoryCriterion},
} <: ItemCriterion
    response_expectation::ResponseExpectationT
    criterion::CriterionT
end

function _get_some_criterion(bits...; kwargs...)
    @returnsome StateCriterion(bits...; kwargs...)
    @returnsome ItemCriterion(bits...; skip_expectation=true, kwargs...)
    @returnsome ItemCategoryCriterion(bits...)
end

function ExpectationBasedItemCriterion(bits...;
        ability_estimator = nothing,
        ability_tracker = nothing)
    @requiresome criterion = _get_some_criterion(
        bits...; ability_estimator = ability_estimator,
        ability_tracker = ability_tracker)
    @requiresome ability_estimator = AbilityEstimator(bits...,
        ability_estimator = ability_estimator,
        ability_tracker = ability_tracker)
    response_expectation = ResponseExpectation(ability_estimator, bits...)
    ExpectationBasedItemCriterion(response_expectation, criterion)
end

function init_thread(::ExpectationBasedItemCriterion, responses::TrackedResponses)
    Speculator(responses, 1)
end

function _generic_criterion(criterion::StateCriterion, tracked_responses, _item_idx, _response)
    compute_criterion(criterion, tracked_responses)
end
# TODO: Support init_thread for wrapped ItemCriterion
function _generic_criterion(criterion::ItemCriterion, tracked_responses, item_idx, _response)
    compute_criterion(criterion, tracked_responses, item_idx)
end
function _generic_criterion(criterion::ItemCategoryCriterion, tracked_responses, item_idx, response)
    compute_criterion(criterion, tracked_responses, item_idx, response)
end

function compute_criterion(
        item_criterion::ExpectationBasedItemCriterion,
        speculator::Speculator,
        tracked_responses::TrackedResponses,
        item_idx)
    exp_resp = Aggregators.response_expectation(item_criterion.response_expectation,
        tracked_responses,
        item_idx)
    possible_responses = responses(ItemResponse(tracked_responses.item_bank, item_idx))
    res = 0.0
    for (prob, possible_response) in zip(exp_resp, possible_responses)
        replace_speculation!(speculator, SVector(item_idx), SVector(possible_response))
        res += prob *
               _generic_criterion(item_criterion.criterion, speculator.responses, item_idx, possible_response)
    end
    res
end
