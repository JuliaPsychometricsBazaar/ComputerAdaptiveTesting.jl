#= Single dimensional =#

function ItemCriterion(bits...; ability_estimator = nothing, ability_tracker = nothing)
    @returnsome find1_instance(ItemCriterion, bits)
    @returnsome find1_type(ItemCriterion, bits) typ->typ(
        ability_estimator = ability_estimator,
        ability_tracker = ability_tracker)
    @returnsome ExpectationBasedItemCriterion(bits...;
        ability_estimator = ability_estimator,
        ability_tracker = ability_tracker)
end

function StateCriterion(bits...; ability_estimator = nothing, ability_tracker = nothing)
    @returnsome find1_instance(StateCriterion, bits)
    @returnsome find1_type(StateCriterion, bits) typ->typ()
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
        rule::ItemStrategyNextItemRule{StrategyT, ItemCriterionT},
        responses,
        items
) where {StrategyT, ItemCriterionT <: ItemCriterion}
    compute_criteria(rule.criterion, responses, items)
end

function compute_pointwise_criterion(
        ppic::PurePointwiseItemCriterion, tracked_responses, item_idx)
    compute_pointwise_criterion(ppic, ItemResponse(tracked_responses.item_bank, item_idx))
end

struct PurePointwiseItemCriterionFunction{PointwiseItemCriterionT <: PointwiseItemCriterion}
    item_response::ItemResponse
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
