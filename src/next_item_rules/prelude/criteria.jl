#= Single dimensional =#

function ItemCriterion(bits...; ability_estimator = nothing, ability_tracker = nothing, skip_expectation = false)
    @returnsome find1_instance(ItemCriterion, bits)
    @returnsome find1_type(ItemCriterion, bits) typ->typ(
        ability_estimator = ability_estimator,
        ability_tracker = ability_tracker)
    if !skip_expectation
        @returnsome ExpectationBasedItemCriterion(bits...;
            ability_estimator = ability_estimator,
            ability_tracker = ability_tracker)
    end
end

function StateCriterion(bits...; ability_estimator = nothing, ability_tracker = nothing)
    @returnsome find1_instance(StateCriterion, bits)
    @returnsome find1_type(StateCriterion, bits) typ->typ()
end

function ItemCategoryCriterion(bits...)
    @returnsome find1_instance(ItemCategoryCriterion, bits)
    @returnsome find1_type(ItemCategoryCriterion, bits) typ->typ()
end

function PointwiseItemCriterion(bits...)
    @returnsome find1_instance(PointwiseItemCriterion, bits)
    @returnsome find1_type(PointwiseItemCriterion, bits) typ->typ()
end

function PointwiseItemCategoryCriterion(bits...)
    @returnsome find1_instance(PointwiseItemCategoryCriterion, bits)
    @returnsome find1_type(PointwiseItemCategoryCriterion, bits) typ->typ()
end

function init_thread(::ItemCriterion, ::TrackedResponses)
    nothing
end

function init_thread(::StateCriterion, ::TrackedResponses)
    nothing
end

function compute_criterion(
        item_criterion::ItemCriterion, ::Nothing, tracked_responses, item_idx)
    compute_criterion(item_criterion, tracked_responses, item_idx)
end

function compute_criterion(item_criterion::ItemCriterion, tracked_responses, item_idx)
    criterion_state = init_thread(item_criterion, tracked_responses)
    if criterion_state === nothing
        error("Tried to run an state-requiring item criterion $(typeof(item_criterion)), but init_thread(...) returned nothing")
    end
    compute_criterion(item_criterion, criterion_state, tracked_responses, item_idx)
end

function compute_criterion(state_criterion::StateCriterion, ::Nothing, tracked_responses)
    compute_criterion(state_criterion, tracked_responses)
end

function compute_criteria(
        criterion::ItemCriterionT,
        responses::TrackedResponseT,
        items::AbstractItemBank
) where {ItemCriterionT <: ItemCriterion, TrackedResponseT <: TrackedResponses}
    objective_state = init_thread(criterion, responses)
    return [compute_criterion(criterion, objective_state, responses, item_idx)
            for item_idx in eachindex(items)]
end

function compute_criteria(
        criterion::ItemCriterion,
        responses::TrackedResponses,
)
    compute_criteria(criterion, responses, responses.item_bank)
end

function compute_criteria(
        rule::ItemStrategyNextItemRule{StrategyT, ItemCriterionT},
        responses,
        items
) where {StrategyT, ItemCriterionT <: ItemCriterion}
    compute_criteria(rule.criterion, responses, items)
end

function compute_criteria(
        rule::ItemStrategyNextItemRule{StrategyT, ItemCriterionT},
        responses::TrackedResponses
) where {StrategyT, ItemCriterionT <: ItemCriterion}
    compute_criteria(rule.criterion, responses)
end

function compute_criterion(
        ppic::ItemCriterionBase, tracked_responses::TrackedResponses, item_idx, args...)
    compute_criterion(ppic, ItemResponse(tracked_responses.item_bank, item_idx), args...)
end

function init_thread(::ItemMultiCriterion, ::TrackedResponses)
    nothing
end

function init_thread(::StateMultiCriterion, ::TrackedResponses)
    nothing
end

function compute_multi_criterion(
        item_criterion::ItemMultiCriterion, ::Nothing, tracked_responses, item_idx)
    compute_multi_criterion(item_criterion, tracked_responses, item_idx)
end

function compute_multi_criterion(
        state_criterion::StateMultiCriterion, ::Nothing, tracked_responses)
    compute_multi_criterion(state_criterion, tracked_responses)
end

function get_dist_est_and_integrator(bits...)
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
