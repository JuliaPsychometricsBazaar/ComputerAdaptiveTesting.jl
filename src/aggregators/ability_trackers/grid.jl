struct GriddedAbilityTracker{AbilityEstimatorT <: DistributionAbilityEstimator, GridT <: AbstractVector{Float64}} <: AbilityTracker
    ability_estimator::AbilityEstimatorT 
    grid::GridT
    cur_ability::Vector{Float64}
end

GriddedAbilityTracker(ability_estimator, grid) = GriddedAbilityTracker(ability_estimator, grid, fill(NaN, length(grid)))

function track!(responses, ability_tracker::GriddedAbilityTracker)
    ability_pdf = pdf(ability_tracker.ability_estimator, responses)
    ability_tracker.cur_ability .= ability_pdf.(ability_tracker.grid)
end