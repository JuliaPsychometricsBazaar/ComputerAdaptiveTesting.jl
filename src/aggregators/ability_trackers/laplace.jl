struct LaplaceAbilityTracker{AbilityEstimatorT <: DistributionAbilityEstimator} <:
       AbilityTracker
    ability_estimator::AbilityEstimatorT
    optimizer::OneDimOptimOptimizer
    cur_ability::Union{Normal, Nothing}
end

function LaplaceAbilityTracker(ability_estimator, optimizer)
    @warn "LaplaceAbilityTracker is a work in progress, and will not accelerate anything yet."
    LaplaceAbilityTracker(ability_estimator, optimizer, nothing)
end

function track!(responses, ability_tracker::LaplaceAbilityTracker)
    f(x) = pdf(ability_tracker.ability_estimator, responses, x)
    mode = ability_tracker.optimizer(f)
    stddev = -(ForwardDiff.hessian(f, mode)^(-1))
    ability_tracker.cur_ability = Normal(mode, stddev)
end
