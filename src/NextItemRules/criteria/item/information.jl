# TODO: Should have Variants for point ability versus distribution ability
@kw_only struct InformationItemCriterion{AbilityEstimatorT <: PointAbilityEstimator, F} <:
       ItemCriterion
    ability_estimator::AbilityEstimatorT
    expected_item_information::F
end

function InformationItemCriterion(ability_estimator::PointAbilityEstimator)
    InformationItemCriterion(;
        ability_estimator,
        expected_item_information
    )
end

function InformationItemCriterion(bits...)
    @requiresome ability_estimator = PointAbilityEstimator(bits...)
    InformationItemCriterion(ability_estimator)
end

function compute_criterion(
        item_criterion::InformationItemCriterion, tracked_responses::TrackedResponses,
        item_idx)
    ability = maybe_tracked_ability_estimate(tracked_responses,
        item_criterion.ability_estimator)
    ir = ItemResponse(tracked_responses.item_bank, item_idx)
    return -item_criterion.expected_item_information(ir, ability)
end

struct InformationMatrixCriteria{AbilityEstimatorT <: AbilityEstimator, F, G} <:
       ItemMultiCriterion
    ability_estimator::AbilityEstimatorT
    known_item_information::F
    expected_item_information::G
end

function InformationMatrixCriteria(ability_estimator)
    InformationMatrixCriteria(ability_estimator, expected_item_information, expected_item_information)
end

function init_thread(item_criterion::InformationMatrixCriteria,
        responses::TrackedResponses)
    # TODO: No need to do this one per thread. It just need to be done once per
    # θ update.
    # TODO: Update this to use track!(...) mechanism
    ability = maybe_tracked_ability_estimate(responses, item_criterion.ability_estimator)
    responses_information(responses.item_bank, responses.responses, ability;
        information_func=item_criterion.known_item_information)
end

function compute_multi_criterion(
        item_criterion::InformationMatrixCriteria, acc_info::Matrix{Float64},
        tracked_responses::TrackedResponses,
        item_idx)
    # TODO: Add in information from the prior
    ability = maybe_tracked_ability_estimate(
        tracked_responses, item_criterion.ability_estimator)
    exp_info = item_criterion.expected_item_information(
        ItemResponse(tracked_responses.item_bank, item_idx), ability)
    return acc_info .+ exp_info
end

should_minimize(::InformationMatrixCriteria) = false
