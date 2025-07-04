struct LikelihoodWeightedItemCriterion{
    PointwiseItemCriterionT <: PointwiseItemCriterion,
    AbilityIntegratorT <: AbilityIntegrator,
    AbilityEstimatorT <: DistributionAbilityEstimator
} <: ItemCriterion
    criterion::PointwiseItemCriterionT
    integrator::AbilityIntegratorT
    estimator::AbilityEstimatorT
end

function LikelihoodWeightedItemCriterion(bits...)
    @requiresome dist_est_integrator_pair = get_dist_est_and_integrator(bits...)
    (dist_est, integrator) = dist_est_integrator_pair
    criterion = PointwiseItemCriterion(bits...)
    return LikelihoodWeightedItemCriterion(criterion, integrator, dist_est)
end

function compute_criterion(
    lwic::LikelihoodWeightedItemCriterion,
    tracked_responses::TrackedResponses,
    item_idx
)
    func = FunctionProduct(
        pdf(lwic.estimator, tracked_responses), ability -> compute_criterion(lwic.criterion, tracked_responses, item_idx, ability))
    intval(lwic.integrator(func, 0, lwic.estimator, tracked_responses))
end

struct PointItemCriterion{
    PointwiseItemCriterionT <: PointwiseItemCriterion,
    AbilityEstimatorT <: PointAbilityEstimator
} <: ItemCriterion
    criterion::PointwiseItemCriterionT
    estimator::AbilityEstimatorT
end

function compute_criterion(
    pic::PointItemCriterion,
    tracked_responses::TrackedResponses,
    item_idx
)
    ability = maybe_tracked_ability_estimate(
        tracked_responses,
        pic.estimator
    )
    return compute_criterion(pic.criterion, tracked_responses, item_idx, ability)
end

struct LikelihoodWeightedItemCategoryCriterion{
    PointwiseItemCategoryCriterionT <: PointwiseItemCategoryCriterion,
    AbilityIntegratorT <: AbilityIntegrator,
    AbilityEstimatorT <: DistributionAbilityEstimator
} <: ItemCategoryCriterion
    criterion::PointwiseItemCategoryCriterionT
    integrator::AbilityIntegratorT
    estimator::AbilityEstimatorT
end

function LikelihoodWeightedItemCategoryCriterion(bits...)
    @requiresome dist_est_integrator_pair = get_dist_est_and_integrator(bits...)
    (dist_est, integrator) = dist_est_integrator_pair
    criterion = PointwiseItemCategoryCriterion(bits...)
    return LikelihoodWeightedItemCategoryCriterion(criterion, integrator, dist_est)
end

function compute_criterion(
    lwicc::LikelihoodWeightedItemCategoryCriterion,
    tracked_responses::TrackedResponses,
    item_idx,
    category
)
    func = FunctionProduct(
        pdf(lwicc.estimator, tracked_responses),
        ability -> compute_criterion(lwicc.criterion, tracked_responses, item_idx, ability, category)
    )
    intval(lwicc.integrator(func, 0, lwicc.estimator, tracked_responses))
end

struct PointItemCategoryCriterion{
    PointwiseItemCategoryCriterionT <: PointwiseItemCategoryCriterion,
    AbilityEstimatorT <: PointAbilityEstimator
} <: ItemCategoryCriterion
    criterion::PointwiseItemCategoryCriterionT
    estimator::AbilityEstimatorT
end

function compute_criterion(
    pic::PointItemCategoryCriterion,
    tracked_responses::TrackedResponses,
    item_idx,
    category
)
    ability = maybe_tracked_ability_estimate(
        tracked_responses,
        pic.estimator
    )
    return compute_criterion(pic.criterion, tracked_responses, item_idx, ability, category)
end