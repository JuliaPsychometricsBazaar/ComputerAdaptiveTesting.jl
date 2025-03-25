function kl(item_response::ItemResponse, r0, theta)
    r = resp_vec(item_response, theta)
    resp = 0.0
    for (p0, p) in zip(r0, r)
        resp += p0 * (log(p0) - log(p))
    end
    return resp
end

struct PosteriorExpectedKLInformationItemCriterion{
    PointEstimatorT <: PointAbilityEstimator,
    DistributionEstimatorT <: DistributionAbilityEstimator,
    IntegratorT <: AbilityIntegrator
} <: PointwiseItemCriterion
end

function PosteriorExpectedKLInformationItemCriterion(bits...)
    @requiresome point_estimator = PointAbilityEstimator(bits...)
    @requiresome distribution_estimator = DistributionAbilityEstimator(bits...)
    @requiresome integrator = AbilityIntegrator(bits...)
    PosteriorExpectedKLInformationItemCriterion(
        point_estimator, distribution_estimator, integrator)
end

function compute_pointwise_criterion(
        item_criterion::PosteriorExpectedKLInformationItemCriterion,
        tracked_responses::TrackedResponses,
        item_idx)
    theta_0 = maybe_tracked_ability_estimate(tracked_responses,
        item_criterion.point_estimator)
    item_response = ItemResponse(tracked_responses.item_bank, item_idx)
    r0 = resp_vec(item_response, theta_0)
    expectation(
        theta -> kl(item_response, r0, theta),
        item_criterion.integrator,
        item_criterion.distribution_estimator,
        tracked_responses)
end
