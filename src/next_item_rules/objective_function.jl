"""
$(TYPEDEF)
"""
abstract type ItemCriterion <: CatConfigBase end

function ItemCriterion(bits...; ability_estimator = nothing, ability_tracker = nothing)
    @returnsome find1_instance(ItemCriterion, bits)
    @returnsome find1_type(ItemCriterion, bits) typ->typ(
        ability_estimator = ability_estimator,
        ability_tracker = ability_tracker)
    @returnsome ExpectationBasedItemCriterion(bits...;
        ability_estimator = ability_estimator,
        ability_tracker = ability_tracker)
end

"""
$(TYPEDEF)
"""
abstract type StateCriterion <: CatConfigBase end

function StateCriterion(bits...; ability_estimator = nothing, ability_tracker = nothing)
    @returnsome find1_instance(StateCriterion, bits)
    @returnsome find1_type(StateCriterion, bits) typ->typ()
end

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

function AbilityVarianceStateCriterion(bits...)
    skip_zero = false
    # XXX: Weakness in this initialisation system is showing now
    # This needs ot be explicitly passed dist_est and integrator, but this may
    # be burried within a MeanAbilityEstimator
    @returnsome find1_instance(AbilityVarianceStateCriterion, bits)
    dist_est = DistributionAbilityEstimator(bits...)
    integrator = AbilityIntegrator(bits...)
    if dist_est !== nothing && integrator !== nothing
        return AbilityVarianceStateCriterion(dist_est, integrator, skip_zero)
    end
    # So let's just handle this case individually for now
    # (Is this going to cause a problem with this being picked over something more appropriate?)
    @requiresome mean_ability_est = MeanAbilityEstimator(bits...)
    return AbilityVarianceStateCriterion(
        mean_ability_est.dist_est,
        mean_ability_est.integrator,
        skip_zero
    )
end

function (criterion::AbilityVarianceStateCriterion)(tracked_responses::TrackedResponses)::Float64
    # XXX: Not sure if the estimator should come from somewhere else here
    denom = normdenom(criterion.integrator,
        criterion.dist_est,
        tracked_responses)
    if denom == 0.0 && criterion.skip_zero
        return Inf
    end
    criterion(DomainType(tracked_responses.item_bank), tracked_responses, denom)
end

function (criterion::AbilityVarianceStateCriterion)(
        ::Union{OneDimContinuousDomain, DiscreteDomain},
        tracked_responses::TrackedResponses,
        denom)::Float64
    mean = expectation(IntegralCoeffs.id,
        0,
        criterion.integrator,
        criterion.dist_est,
        tracked_responses,
        denom)
    # XXX: This is not type stable and seems to possibly allocate. We need to
    # show that mean is the same as our tracked responses.
    return expectation(IntegralCoeffs.SqDev(mean),
        0,
        criterion.integrator,
        criterion.dist_est,
        tracked_responses,
        denom)
end

function (criterion::AbilityVarianceStateCriterion)(::Vector,
        tracked_responses::TrackedResponses,
        denom)::Float64
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

"""
$(TYPEDEF)
$(TYPEDFIELDS)

This item criterion just picks the item with the raw difficulty closest to the
current ability estimate.
"""
struct UrryItemCriterion{AbilityEstimatorT <: PointAbilityEstimator} <: ItemCriterion
    ability_estimator::AbilityEstimatorT
end

# TODO: Slow + poor error handling
function raw_difficulty(item_bank, item_idx)
    item_params(item_bank, item_idx).difficulty
end

function (item_criterion::UrryItemCriterion)(tracked_responses::TrackedResponses, item_idx)
    ability = maybe_tracked_ability_estimate(tracked_responses,
        item_criterion.ability_estimator)
    diff = raw_difficulty(tracked_responses.item_bank, item_idx)
    abs(ability - diff)
end

# TODO: Should have Variants for point ability versus distribution ability
struct InformationItemCriterion{AbilityEstimatorT <: PointAbilityEstimator} <: ItemCriterion
    ability_estimator::AbilityEstimatorT
end

function (item_criterion::InformationItemCriterion)(tracked_responses::TrackedResponses,
        item_idx)
    ability = maybe_tracked_ability_estimate(tracked_responses,
        item_criterion.ability_estimator)
    ir = ItemResponse(tracked_responses.item_bank, item_idx)
    return -item_information(ir, ability)
end

abstract type InformationMatrixCriterion <: ItemCriterion end

function init_thread(item_criterion::InformationMatrixCriterion,
        responses::TrackedResponses)
    # TODO: No need to do this one per thread. It just need to be done once per
    # θ update.
    # TODO: Update this to use track!(...) mechanism
    ability = maybe_tracked_ability_estimate(responses, item_criterion.ability_estimator)
    responses_information(responses.item_bank, responses.responses, ability)
end

function information_matrix(ability_estimator,
        acc_info,
        tracked_responses::TrackedResponses,
        item_idx)
    # TODO: Add in information from the prior
    ability = maybe_tracked_ability_estimate(tracked_responses, ability_estimator)
    acc_info .+
    expected_item_information(ItemResponse(tracked_responses.item_bank, item_idx), ability)
end

struct DRuleItemCriterion{AbilityEstimatorT <: PointAbilityEstimator} <:
       InformationMatrixCriterion
    ability_estimator::AbilityEstimatorT
end

function (item_criterion::DRuleItemCriterion)(acc_info::Matrix{Float64},
        tracked_responses::TrackedResponses,
        item_idx)
    -det(information_matrix(item_criterion.ability_estimator,
        acc_info,
        tracked_responses,
        item_idx))
end

# TODO: Weighted version
struct TRuleItemCriterion{AbilityEstimatorT <: PointAbilityEstimator} <:
       InformationMatrixCriterion
    ability_estimator::AbilityEstimatorT
end

function (item_criterion::TRuleItemCriterion)(acc_info::Matrix{Float64},
        tracked_responses,
        item_idx)
    # XXX: Should not strictly need to calculate whole information matrix to get this.
    # Should just be able to calculate Laplacians as we go, but ForwardDiff doesn't support this (yet?).
    -tr(information_matrix(item_criterion.ability_estimator,
        acc_info,
        tracked_responses,
        item_idx))
end

struct ARuleItemCriterion{AbilityEstimatorT <: PointAbilityEstimator} <: ItemCriterion
    ability_estimator::AbilityEstimatorT
end

function (item_criterion::ARuleItemCriterion)(acc_info::Nothing,
        tracked_responses,
        item_idx)
    # TODO
    # Step 1. Get covariance of ability estimate
    # Basically the same idea as AbilityVarianceStateCriterion
    # Step 2. Get the (weighted) trace
end
