struct GriddedAbilityTracker{AbilityEstimatorT <: DistributionAbilityEstimator, IntegratorT} <: AbilityTracker
    ability_estimator::AbilityEstimatorT 
    integrator::IntegratorT
    cur_ability::Vector{Float64}
end

function GriddedAbilityTracker(ability_estimator::DistributionAbilityEstimator, integrator::FixedGridIntegrator)
    GriddedAbilityTracker(ability_estimator, integrator, fill(NaN, length(integrator.grid)))
end

function track!(responses, ability_tracker::GriddedAbilityTracker)
    ability_pdf = pdf(ability_tracker.ability_estimator, responses)
    ability_tracker.cur_ability .= ability_pdf.(ability_tracker.integrator.grid)
end