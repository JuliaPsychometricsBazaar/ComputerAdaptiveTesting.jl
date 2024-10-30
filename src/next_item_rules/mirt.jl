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

struct InformationMatrixCriteria{AbilityEstimatorT <: AbilityEstimator, F} <: ItemCriteria
    ability_estimator::AbilityEstimatorT
    expected_item_information::F
end

function InformationMatrixCriteria(ability_estimator)
    InformationMatrixCriteria(ability_estimator, expected_item_information)
end

function init_thread(item_criterion::InformationMatrixCriteria,
        responses::TrackedResponses)
    # TODO: No need to do this one per thread. It just need to be done once per
    # θ update.
    # TODO: Update this to use track!(...) mechanism
    ability = maybe_tracked_ability_estimate(responses, item_criterion.ability_estimator)
    responses_information(responses.item_bank, responses.responses, ability)
end

function (item_criterion::InformationMatrixCriteria)(acc_info::Matrix{Float64},
        tracked_responses::TrackedResponses,
        item_idx)
    # TODO: Add in information from the prior
    ability = maybe_tracked_ability_estimate(
        tracked_responses, item_criterion.ability_estimator)
    return acc_info .+
           item_criterion.expected_item_information(
        ItemResponse(tracked_responses.item_bank, item_idx), ability)
end

should_minimize(::InformationMatrixCriteria) = false

struct ScalarizedItemCriteron{
    ItemCriteriaT <: ItemCriteria,
    MatrixScalarizerT <: MatrixScalarizer
} <: ItemCriterion
    criteria::ItemCriteriaT
    scalarizer::MatrixScalarizerT
end

function (ssc::ScalarizedItemCriteron)(tracked_responses, item_idx)
    res = ssc.criteria(
        init_thread(ssc.criteria, tracked_responses), tracked_responses, item_idx) |>
          ssc.scalarizer
    if !should_minimize(ssc.criteria)
        res = -res
    end
    res
end

struct WeightedStateCriteria{InnerT <: StateCriteria} <: StateCriteria
    weights::Vector{Float64}
    criteria::InnerT
end

function (wsc::WeightedStateCriteria)(tracked_responses, item_idx)
    wsc.weights' * wsc.criteria(tracked_responses, item_idx) * wsc.weights
end

struct WeightedItemCriteria{InnerT <: ItemCriteria} <: ItemCriteria
    weights::Vector{Float64}
    criteria::InnerT
end

function (wsc::WeightedItemCriteria)(tracked_responses, item_idx)
    wsc.weights' * wsc.criteria(tracked_responses, item_idx) * wsc.weights
end
