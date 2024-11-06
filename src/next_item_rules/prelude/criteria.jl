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

function init_thread(::ItemCriterion, ::TrackedResponses)
    nothing
end

function StateCriterion(bits...; ability_estimator = nothing, ability_tracker = nothing)
    @returnsome find1_instance(StateCriterion, bits)
    @returnsome find1_type(StateCriterion, bits) typ->typ()
end

function (item_criterion::ItemCriterion)(::Nothing, tracked_responses, item_idx)
    item_criterion(tracked_responses, item_idx)
end

function (item_criterion::ItemCriterion)(tracked_responses, item_idx)
    criterion_state = init_thread(item_criterion, tracked_responses)
    if criterion_state === nothing
        error("Tried to run an state-requiring item criterion $(typeof(item_criterion)), but init_thread(...) returned nothing")
    end
    item_criterion(criterion_state, tracked_responses, item_idx)
end

function compute_criteria(
        criterion::ItemCriterionT,
        responses::TrackedResponseT,
        items::AbstractItemBank
) where {ItemCriterionT <: ItemCriterion, TrackedResponseT <: TrackedResponses}
    objective_state = init_thread(criterion, responses)
    return [criterion(objective_state, responses, item_idx)
            for item_idx in eachindex(items)]
end

function compute_criteria(
        rule::ItemStrategyNextItemRule{StrategyT, ItemCriterionT},
        responses,
        items
) where {StrategyT, ItemCriterionT <: ItemCriterion}
    compute_criteria(rule.criterion, responses, items)
end
