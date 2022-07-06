abstract type ItemCriterionConfig end
abstract type ItemCriterion end

function ItemCriterion(bits...; ability_estimator=nothing)
    @returnsome find1_instance(ItemCriterion, bits)
    @returnsome find1_type(ItemCriterion, bits) typ -> typ(ability_estimator=ability_estimator)
    @returnsome ExpectationBasedItemCriterion(bits...; ability_estimator=ability_estimator)
end

abstract type StateCriterion end

function StateCriterion(bits...; ability_estimator=nothing)
    @returnsome find1_instance(StateCriterion, bits)
    @returnsome find1_type(StateCriterion, bits) typ -> typ()
end

"""
This StateCriterion returns the variance of the ability estimate given a set of
responses.
"""
struct AbilityVarianceStateCriterion{DistEst <: DistributionAbilityEstimator, IntegratorT <: AbilityIntegrator} <: StateCriterion
    dist_est::DistEst
    integrator::IntegratorT
end

function AbilityVarianceStateCriterion(bits...)
    # XXX: Weakness in this initialisation system is showing now
    # This needs ot be explicitly passed dist_est and integrator, but this may
    # be burried within a MeanAbilityEstimator
    @returnsome find1_instance(AbilityVarianceStateCriterion, bits)
    @requiresome dist_est = DistributionAbilityEstimator(bits...)
    @requiresome integrator = AbilityIntegrator(bits...)
    AbilityVarianceStateCriterion(dist_est, integrator)
end

function (criterion::AbilityVarianceStateCriterion)(tracked_responses::TrackedResponses)::Float64
    # XXX: Not sure if the estimator should come from somewhere else here
    denom = normdenom(
        criterion.integrator,
        criterion.dist_est,
        tracked_responses
    )
    criterion(tracked_responses, DomainType(tracked_responses.item_bank), denom)
end

function (criterion::AbilityVarianceStateCriterion)(::OneDimContinuousDomain, tracked_responses::TrackedResponses, denom)::Float64
    mean = expectation(
        IntegralCoeffs.id,
        0,
        criterion.integrator,
        criterion.dist_est,
        tracked_responses,
        denom
    )
    expectation(
        IntegralCoeffs.SqDev(mean),
        0,
        criterion.integrator,
        criterion.dist_est,
        tracked_responses,
        denom
    )
end

function (criterion::AbilityVarianceStateCriterion)(::Vector, tracked_responses::TrackedResponses, denom)::Float64
    # XXX: Not quite sure about this --- is it useful, the MIRT rules cover this case
    mean = expectation(
        IntegralCoeffs.id,
        dim(tracked_responses.item_bank),
        criterion.integrator,
        criterion.dist_est,
        tracked_responses,
        denom
    )
    expectation(
        IntegralCoeffs.SqDev(mean),
        dim(tracked_responses.item_bank),
        criterion.integrator,
        criterion.dist_est,
        tracked_responses,
        denom
    )
end

abstract type ExpectationBasedItemCriterion <: ItemCriterion end

function ExpectationBasedItemCriterion(bits...; ability_estimator=nothing)
    println(join(stacktrace(), "\n"))
    criterion = StateCriterion(bits...; ability_estimator=ability_estimator)
    if criterion === nothing
        return nothing
    end
    ability_estimator = AbilityEstimator(bits..., ability_estimator=ability_estimator)
    if ability_estimator === nothing
        return nothing
    end
    ExpectationBasedItemCriterion(ability_estimator, criterion, bits...)
end

function ExpectationBasedItemCriterion(ability_estimator::PointAbilityEstimator, criterion::StateCriterion, bits...)
    PointExpectationBasedItemCriterion(ability_estimator, criterion)
end

function ExpectationBasedItemCriterion(ability_estimator::DistributionAbilityEstimator, criterion::StateCriterion, bits...)
    @returnsome Integrator(bits...) integrator -> DistributionBasedItemCriterion(ability_estimator, integrator, criterion)
end

"""
This ItemCriterion wraps a StateCriterion and looks at its expected value for a
particular item 1-ply ahead based on a point ability estimate.
"""
struct PointExpectationBasedItemCriterion{PointAbilityEstimatorT <: PointAbilityEstimator, StateCriterionT <: StateCriterion} <: ExpectationBasedItemCriterion
    ability_estimator::PointAbilityEstimatorT
    state_criterion::StateCriterionT
end

"""
This ItemCriterion wraps a StateCriterion and looks at its expected value for a
particular item 1-ply ahead by integrating over an ability curve.
"""
struct DistributionExpectationBasedItemCriterion{DistributionAbilityEstimatorT <: DistributionAbilityEstimator, AbilityIntegratorT <: AbilityIntegrator, StateCriterionT <: StateCriterion} <: ExpectationBasedItemCriterion
    ability_estimator::DistributionAbilityEstimatorT
    integrator::AbilityIntegratorT
    state_criterion::StateCriterionT
end

function init_thread(::ExpectationBasedItemCriterion, responses::TrackedResponses)
    Speculator(responses, 1)
end

function Aggregators.response_expectation(item_criterion::PointExpectationBasedItemCriterion, tracked_responses, item_idx)
    response_expectation(
        item_criterion.ability_estimator,
        tracked_responses,
        item_idx
    )
end

function Aggregators.response_expectation(item_criterion::DistributionExpectationBasedItemCriterion, tracked_responses, item_idx)
    response_expectation(
        item_criterion.ability_estimator,
        item_criterion.integrator,
        tracked_responses,
        item_idx
    )
end

function (item_criterion::ExpectationBasedItemCriterion)(speculator::Speculator, tracked_responses::TrackedResponses, item_idx)
    exp_resp = response_expectation(
        item_criterion,
        tracked_responses,
        item_idx
    )
    replace_speculation!(speculator, SVector(item_idx), SVector(0))
    neg_var = item_criterion.state_criterion(speculator.responses)
    replace_speculation!(speculator, SVector(item_idx), SVector(1))
    pos_var = item_criterion.state_criterion(speculator.responses)
    (1 - exp_resp) * neg_var + exp_resp * pos_var
end

struct UrryItemCriterion{AbilityEstimatorT <: PointAbilityEstimator} <: ItemCriterion
    ability_estimator::AbilityEstimatorT
end

function (item_criterion::UrryItemCriterion)(tracked_responses::TrackedResponses, item_idx)
    ability = maybe_tracked_ability_estimate(tracked_responses, item_criterion.ability_estimator)
    diff = raw_difficulty(tracked_responses.item_bank, item_idx)
    abs(ability - diff)
end

struct InformationItemCriterion{AbilityEstimatorT <: PointAbilityEstimator} <: ItemCriterion
    ability_estimator::AbilityEstimatorT
end

function (item_criterion::InformationItemCriterion)(tracked_responses::TrackedResponses, item_idx)
    ability = maybe_tracked_ability_estimate(tracked_responses, item_criterion.ability_estimator)
    ir = ItemResponse(tracked_responses.item_bank, item_idx)
    return -item_information(ir, ability)
end

abstract type InformationMatrixCriterion <: ItemCriterion end

function init_thread(item_criterion::InformationMatrixCriterion, responses::TrackedResponses)
    # TODO: No need to do this one per thread. It just need to be done once per
    # θ update.
    ability = maybe_tracked_ability_estimate(responses, item_criterion.ability_estimator)
    responses_information(responses.item_bank, responses.responses, ability)
end

function information_matrix(ability_estimator, acc_info, tracked_responses::TrackedResponses, item_idx)
    # TODO: Add in information from the prior
    ability = maybe_tracked_ability_estimate(tracked_responses, ability_estimator)
    acc_info .+ expected_item_information(ItemResponse(tracked_responses.item_bank, item_idx), ability)
end

struct DRuleItemCriterion{AbilityEstimatorT <: PointAbilityEstimator} <: InformationMatrixCriterion 
    ability_estimator::AbilityEstimatorT
end

function (item_criterion::DRuleItemCriterion)(acc_info::Matrix{Float64}, tracked_responses::TrackedResponses, item_idx)
    -det(information_matrix(item_criterion.ability_estimator, acc_info, tracked_responses, item_idx))
end

# TODO: Weighted version
struct TRuleItemCriterion{AbilityEstimatorT <: PointAbilityEstimator} <: InformationMatrixCriterion 
    ability_estimator::AbilityEstimatorT
end

function (item_criterion::TRuleItemCriterion)(acc_info::Matrix{Float64}, tracked_responses, item_idx)
    # XXX: Should not strictly need to calculate whole information matrix to get this.
    # Should just be able to calculate Laplacians as we go, but ForwardDiff doesn't support this (yet?).
    -tr(information_matrix(item_criterion.ability_estimator, acc_info, tracked_responses, item_idx))
end

struct ARuleItemCriterion{AbilityEstimatorT <: PointAbilityEstimator} <: ItemCriterion
    ability_estimator::AbilityEstimatorT
end

function (item_criterion::ARuleItemCriterion)(acc_info::Nothing, tracked_responses, item_idx)
    # TODO
    # Step 1. Get covariance of ability estimate
    # Basically the same idea as AbilityVarianceStateCriterion
    # Step 2. Get the (weighted trace)
end