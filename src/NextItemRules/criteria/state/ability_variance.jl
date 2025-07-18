"""
$(TYPEDEF)
$(TYPEDFIELDS)

This `StateCriterion` returns the variance of the ability estimate given a set
of responses.
"""
struct AbilityVariance{
    DistEst <: DistributionAbilityEstimator,
    IntegratorT <: AbilityIntegrator
} <: StateCriterion
    dist_est::DistEst
    integrator::IntegratorT
    skip_zero::Bool
end

function AbilityVariance(bits...)
    skip_zero = false
    @returnsome find1_instance(AbilityVariance, bits)
    @requiresome dist_est_integrator_pair = get_dist_est_and_integrator(bits...)
    (dist_est, integrator) = dist_est_integrator_pair
    return AbilityVariance(dist_est, integrator, skip_zero)
end

function compute_criterion(criterion::AbilityVariance,
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

function compute_criterion(criterion::AbilityVariance,
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
        criterion::AbilityVariance,
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

function show(io::IO, ::MIME"text/plain", criterion::AbilityVariance)
    println(io, "Minimise variance of ability estimate")
    indent_io = indent(io, 2)
    show(indent_io, MIME("text/plain"), criterion.dist_est)
    show(indent_io, MIME("text/plain"), criterion.integrator)
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
    @requiresome (dist_est, integrator) = get_dist_est_and_integrator(bits...)
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
