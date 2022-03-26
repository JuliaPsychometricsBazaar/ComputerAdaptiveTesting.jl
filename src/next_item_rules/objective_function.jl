
abstract type ItemCriterionConfig end
abstract type ItemCriterion end

abstract type StateCriterion end

struct AbilityVarianceStateCriterion <: StateCriterion end

struct ExpectationBasedItemCriterion{AbilityEstimatorT <: AbilityEstimator, StateCriterionT <: StateCriterion} <: ItemCriterion
    ability_estimator::AbilityEstimatorT
    state_criterion::StateCriterionT
end

function (item_criterion::ExpectationBasedItemCriterion)(tracked_responses::TrackedResponses, item_idx)
    exp_resp = response_expectation(
        item_criterion.ability_estimator,
        tracked_responses,
        item_idx
    )
    item_criterion.state_criterion(exp_resp)
end