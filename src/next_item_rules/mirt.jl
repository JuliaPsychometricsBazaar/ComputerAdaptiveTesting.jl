abstract type MatrixScalarizer end

struct DeterminantScalarizer <: MatrixScalarizer end
(::DeterminantScalarizer)(mat) = det(mat)

struct TraceScalarizer <: MatrixScalarizer end
(::TraceScalarizer)(mat) = tr(mat)

abstract type StateCriteria end
abstract type ItemCriteria end

struct AbilityCovarianceStateCriteria{
    DistEstT <: DistributionAbilityEstimator,
    IntegratorT <: AbilityIntegrator
} <: StateCriteria
    dist_est::DistEstT
    integrator::IntegratorT
    skip_zero::Bool
end

function AbilityCovarianceStateCriteria(bits...)
    skip_zero = false
    @requiresome (dist_est, integrator) = _get_dist_est_and_integrator(bits...)
    return AbilityCovarianceStateCriteria(dist_est, integrator, skip_zero)
end

# XXX: Should be at type level
should_minimize(::AbilityCovarianceStateCriteria) = true

function (criteria::AbilityCovarianceStateCriteria)(
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

struct ScalarizedStateCriteron{
    StateCriteriaT <: StateCriteria,
    MatrixScalarizerT <: MatrixScalarizer
} <: StateCriterion
    criteria::StateCriteriaT
    scalarizer::MatrixScalarizerT
end

function (ssc::ScalarizedStateCriteron)(tracked_responses)
    res = ssc.criteria(tracked_responses) |> ssc.scalarizer
    if !should_minimize(ssc.criteria)
        res = -res
    end
    res
end
