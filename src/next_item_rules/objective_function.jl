abstract type ItemCriterionConfig end
abstract type ItemCriterion end

abstract type StateCriterion end

"""
This StateCriterion returns the variance of the ability estimate given a set of
responses.
"""
struct AbilityVarianceStateCriterion <: StateCriterion end

function (::AbilityVarianceStateCriterion)(tracked_responses::TrackedResponses)::Float64
    # XXX: Not sure if the estimator should come from somewhere else here
    est = distribution_estimator(tracked_responses.ability_estimator)
    denom = integrate(IntegralCoeffs.one, est, tracked_responses)
    mean = expectation(
        IntegralCoeffs.id,
        est,
        tracked_responses,
        denom
    )
    expectation(IntegralCoeffs.SqDev(mean), est, tracked_responses, denom)
end

"""
This ItemCriterion wraps a StateCriterion and looks at its expected value for a
particular item 1-ply ahead.
"""
struct ExpectationBasedItemCriterion{AbilityEstimatorT <: AbilityEstimator, StateCriterionT <: StateCriterion} <: ItemCriterion
    ability_estimator::AbilityEstimatorT
    state_criterion::StateCriterionT
end

function init_thread(::ExpectationBasedItemCriterion, responses::TrackedResponses)
    Speculator(responses, 1)
end

function (item_criterion::ExpectationBasedItemCriterion)(speculator::Speculator, tracked_responses::TrackedResponses, item_idx)
    exp_resp = response_expectation(
        item_criterion.ability_estimator,
        tracked_responses,
        item_idx
    )
    replace_speculation!(speculator, SVector(item_idx), SVector(0))
    neg_var = item_criterion.state_criterion(speculator.responses)
    replace_speculation!(speculator, SVector(item_idx), SVector(1))
    pos_var = item_criterion.state_criterion(speculator.responses)
    (1 - exp_resp) * neg_var + exp_resp * pos_var
end

struct UrryItemCriterion{AbilityEstimatorT <: AbilityEstimator} <: ItemCriterion
    ability_estimator::AbilityEstimatorT
end

function (item_criterion::UrryItemCriterion)(tracked_responses::TrackedResponses, item_idx)
    ability = item_criterion.ability_estimator(tracked_responses)
    diff = raw_difficulty(tracked_responses.item_bank, item_idx)
    abs(ability - diff)
end

struct InformationItemCriterion{AbilityEstimatorT <: AbilityEstimator} <: ItemCriterion
    ability_estimator::AbilityEstimatorT
end

function (item_criterion::InformationItemCriterion)(tracked_responses::TrackedResponses, item_idx)
    ability = item_criterion.ability_estimator(tracked_responses)
    ir = ItemResponse(tracked_responses.item_bank, item_idx)
    -item_information(ir, ability)
end