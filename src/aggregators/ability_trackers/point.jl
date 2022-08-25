mutable struct PointAbilityTracker{AbilityEstimatorT <: PointAbilityEstimator, AbilityT} <: AbilityTracker
    ability_estimator::AbilityEstimatorT 
    cur_ability::AbilityT
end

function track!(responses, ability_tracker::PointAbilityTracker)
    ability_tracker.cur_ability = ability_tracker.ability_estimator(responses)
end

function PointAbilityTracker(ability_estimator)
    # TODO: Multiple dimensions
    PointAbilityEstimator(ability_estimator, NaN)
end