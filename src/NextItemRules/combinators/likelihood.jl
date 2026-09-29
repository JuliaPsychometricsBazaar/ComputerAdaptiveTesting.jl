"""
$(TYPEDEF)
$(TYPEDFIELDS)

Integrate a pointwise item criterion against the unnormalized ability density.
The `integrator` applies the response likelihood and, for a posterior
`estimator`, its prior exactly once.
"""
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
    func = ability -> compute_criterion(lwic.criterion, tracked_responses, item_idx, ability)
    intval(lwic.integrator(func, 0, lwic.estimator, tracked_responses))
end

function power_summary(io::IO, criterion::LikelihoodWeightedItemCriterion)
    println(io, "Integrate the pointwise criterion over the ability density")
    indent_io = indent(io, 2)
    power_summary(indent_io, criterion.estimator)
    power_summary(indent_io, criterion.integrator)
    power_summary(indent_io, criterion.criterion)
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

function power_summary(io::IO, criterion::PointItemCriterion)
    println(io, "Evaluate the pointwise criterion at the point ability estimate")
    indent_io = indent(io, 2)
    power_summary(indent_io, criterion.estimator)
    power_summary(indent_io, criterion.criterion)
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

Integrate a pointwise item-category criterion against the unnormalized ability
density. The `integrator` applies the response likelihood and, for a posterior
`estimator`, its prior exactly once.
"""
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
    func = ability -> compute_criterion(
        lwicc.criterion, tracked_responses, item_idx, ability, category)
    intval(lwicc.integrator(func, 0, lwicc.estimator, tracked_responses))
end

function power_summary(io::IO, criterion::LikelihoodWeightedItemCategoryCriterion)
    println(io, "Integrate the pointwise item-category criterion over the ability density")
    indent_io = indent(io, 2)
    power_summary(indent_io, criterion.estimator)
    power_summary(indent_io, criterion.integrator)
    power_summary(indent_io, criterion.criterion)
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

function power_summary(io::IO, criterion::PointItemCategoryCriterion)
    println(io, "Evaluate the pointwise item-category criterion at the point ability estimate")
    indent_io = indent(io, 2)
    power_summary(indent_io, criterion.estimator)
    power_summary(indent_io, criterion.criterion)
end
