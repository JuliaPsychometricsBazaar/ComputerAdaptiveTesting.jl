struct GriddedAbilityTracker{
    AbilityEstimatorT <: DistributionAbilityEstimator,
    IntegratorT
} <: AbilityTracker
    ability_estimator::AbilityEstimatorT
    integrator::IntegratorT
    cur_ability::Vector{Float64}
end

function GriddedAbilityTracker(ability_estimator::DistributionAbilityEstimator,
        integrator::FixedGridIntegrator)
    GriddedAbilityTracker(ability_estimator, integrator, fill(1.0, length(integrator.grid)))
end

find_grid(integrator::FixedGridIntegrator) = integrator.grid
find_grid(integrator::PreallocatedFixedGridIntegrator) = integrator.inner.grid

function track!(responses, ability_tracker::GriddedAbilityTracker)
    ability_pdf = pdf(ability_tracker.ability_estimator, responses)
    grid = find_grid(ability_tracker.integrator)
    ability_tracker.cur_ability .= ability_pdf.(grid)
end
