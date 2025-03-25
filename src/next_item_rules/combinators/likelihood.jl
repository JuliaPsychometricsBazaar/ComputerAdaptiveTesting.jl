struct LikelihoodWeightedItemCriterion{
    PointwiseItemCriterionT <: PointwiseItemCriterion,
    AbilityIntegratorT <: AbilityIntegrator,
    AbilityEstimatorT <: DistributionAbilityEstimator
} <: ItemCriterion
    criterion::PointwiseItemCriterionT
    integrator::AbilityIntegratorT
    estimator::AbilityEstimatorT
end

function compute_criterion(
        lwic::LikelihoodWeightedItemCriterion,
        tracked_responses::TrackedResponses,
        item_idx
)
    func = FunctionProduct(
        pdf(lwic.estimator, tracked_responses), lwic.criterion(tracked_responses, item_idx))
    lwic.integrator(func, 0, lwic.estimator, tracked_responses)
end
