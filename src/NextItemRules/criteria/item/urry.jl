"""
$(TYPEDEF)
$(TYPEDFIELDS)

This item criterion just picks the item with the raw difficulty closest to the
current ability estimate.
"""
struct UrryItemCriterion{AbilityEstimatorT <: PointAbilityEstimator} <: ItemCriterion
    ability_estimator::AbilityEstimatorT
end

function UrryItemCriterion(bits...)
    @requiresome ability_estimator = PointAbilityEstimator(bits...)
    UrryItemCriterion(ability_estimator)
end

# TODO: Slow + poor error handling
function raw_difficulty(item_bank, item_idx)
    item_params(item_bank, item_idx).difficulty
end

function compute_criterion(
        item_criterion::UrryItemCriterion, tracked_responses::TrackedResponses, item_idx)
    ability = maybe_tracked_ability_estimate(tracked_responses,
        item_criterion.ability_estimator)
    diff = raw_difficulty(tracked_responses.item_bank, item_idx)
    abs(ability - diff)
end
