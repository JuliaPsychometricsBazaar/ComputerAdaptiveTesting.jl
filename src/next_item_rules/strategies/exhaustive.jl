function exhaustive_search(objective::ItemCriterionT,
        responses::TrackedResponseT,
        items::AbstractItemBank)::Tuple{
        Int,
        Float64
} where {ItemCriterionT <: ItemCriterion, TrackedResponseT <: TrackedResponses}
    #pre_next_item(expectation_tracker, items)
    objective_state = init_thread(objective, responses)
    min_obj_idx::Int = -1
    min_obj_val::Float64 = Inf
    for item_idx in eachindex(items)
        # TODO: Add these back in
        #@init irf_states_storage = zeros(Int, length(responses) + 1)
        if (findfirst(idx -> idx == item_idx, responses.responses.indices) !== nothing)
            continue
        end

        obj_val = compute_criterion(objective, objective_state, responses, item_idx)

        if obj_val <= min_obj_val
            min_obj_val = obj_val
            min_obj_idx = item_idx
        end
    end
    return (min_obj_idx, min_obj_val)
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

"""
@with_kw struct ExhaustiveSearch <: NextItemStrategy
    parallel::Bool = false
end

function best_item(
        rule::ItemStrategyNextItemRule{ExhaustiveSearch, ItemCriterionT},
        responses::TrackedResponses,
        items
) where {ItemCriterionT <: ItemCriterion}
    exhaustive_search(rule.criterion, responses, items)[1]
end

function best_item(
        rule::ItemStrategyNextItemRule{ExhaustiveSearch, ItemCriterionT},
        responses::TrackedResponses
) where {ItemCriterionT <: ItemCriterion}
    best_item(rule, responses, responses.item_bank)
end
