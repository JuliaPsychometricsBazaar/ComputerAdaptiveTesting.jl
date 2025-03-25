"""
$(TYPEDEF)
$(TYPEDFIELDS)

This `StateCriterion` returns the variance of the ability estimate given a set
of responses.
"""
struct AbilityVarianceStateCriterion{
    DistEst <: DistributionAbilityEstimator,
    IntegratorT <: AbilityIntegrator
} <: StateCriterion
    dist_est::DistEst
    integrator::IntegratorT
    skip_zero::Bool
end

function _get_dist_est_and_integrator(bits...)
    # XXX: Weakness in this initialisation system is showing now
    # This needs ot be explicitly passed dist_est and integrator, but this may
    # be burried within a MeanAbilityEstimator
    dist_est = DistributionAbilityEstimator(bits...)
    integrator = AbilityIntegrator(bits...)
    if dist_est !== nothing && integrator !== nothing
        return (dist_est, integrator)
    end
    # So let's just handle this case individually for now
    # (Is this going to cause a problem with this being picked over something more appropriate?)
    @requiresome mean_ability_est = MeanAbilityEstimator(bits...)
    return (mean_ability_est.dist_est, mean_ability_est.integrator)
end

function AbilityVarianceStateCriterion(bits...)
    skip_zero = false
    @returnsome find1_instance(AbilityVarianceStateCriterion, bits)
    @requiresome dist_est_integrator_pair = _get_dist_est_and_integrator(bits...)
    (dist_est, integrator) = dist_est_integrator_pair
    return AbilityVarianceStateCriterion(dist_est, integrator, skip_zero)
end

function compute_criterion(criterion::AbilityVarianceStateCriterion,
        tracked_responses::TrackedResponses)::Float64
    # XXX: Not sure if the estimator should come from somewhere else here
    denom = normdenom(criterion.integrator,
        criterion.dist_est,
        tracked_responses)
    if denom == 0.0 && criterion.skip_zero
        return Inf
    end
    compute_criterion(
        criterion, DomainType(tracked_responses.item_bank), tracked_responses, denom)
end

function compute_criterion(criterion::AbilityVarianceStateCriterion,
        ::Union{OneDimContinuousDomain, DiscreteDomain},
        tracked_responses::TrackedResponses,
        denom)::Float64
    return variance(
        criterion.integrator,
        criterion.dist_est,
        tracked_responses,
        denom
    )
end

function compute_criterion(
        criterion::AbilityVarianceStateCriterion,
        ::Vector,
        tracked_responses::TrackedResponses,
        denom
)::Float64
    # XXX: Not quite sure about this --- is it useful, the MIRT rules cover this case
    mean = expectation(IntegralCoeffs.id,
        ndims(tracked_responses.item_bank),
        criterion.integrator,
        criterion.dist_est,
        tracked_responses,
        denom)
    expectation(IntegralCoeffs.SqDev(mean),
        ndims(tracked_responses.item_bank),
        criterion.integrator,
        criterion.dist_est,
        tracked_responses,
        denom)
end

struct AbilityCovarianceStateMultiCriterion{
    DistEstT <: DistributionAbilityEstimator,
    IntegratorT <: AbilityIntegrator
} <: StateMultiCriterion
    dist_est::DistEstT
    integrator::IntegratorT
    skip_zero::Bool
end

function AbilityCovarianceStateMultiCriterion(bits...)
    skip_zero = false
    @requiresome (dist_est, integrator) = _get_dist_est_and_integrator(bits...)
    return AbilityCovarianceStateMultiCriterion(dist_est, integrator, skip_zero)
end

# XXX: Should be at type level
should_minimize(::AbilityCovarianceStateMultiCriterion) = true

function compute_multi_criterion(
        criteria::AbilityCovarianceStateMultiCriterion,
        tracked_responses::TrackedResponses,
        denom = normdenom(criteria.integrator,
            criteria.dist_est,
            tracked_responses)
)
    if denom == 0.0 && criteria.skip_zero
        return Inf
    end
    covariance_matrix(
        criteria.integrator,
        criteria.dist_est,
        tracked_responses,
        denom
    )
end
