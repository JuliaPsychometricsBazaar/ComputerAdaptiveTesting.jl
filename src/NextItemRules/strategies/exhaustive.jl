function exhaustive_search(
        callback,
        answered_items::AbstractVector{Int},
        items::AbstractItemBank
)::Tuple{Int, Float64}
    min_obj_idx::Int = -1
    min_obj_val::Float64 = Inf
    for item_idx in eachindex(items)
        # TODO: Add these back in
        #@init irf_states_storage = zeros(Int, length(responses) + 1)
        if (findfirst(idx -> idx == item_idx, answered_items) !== nothing)
            continue
        end

        obj_val = callback(item_idx)

        if obj_val <= min_obj_val
            min_obj_val = obj_val
            min_obj_idx = item_idx
        end
    end
    return (min_obj_idx, min_obj_val)
end

function exhaustive_search(objective::ItemCriterionT,
        responses::TrackedResponseT,
        items::AbstractItemBank)::Tuple{
        Int,
        Float64
} where {ItemCriterionT <: ItemCriterion, TrackedResponseT <: TrackedResponses}
    objective_state = init_thread(objective, responses)
    return exhaustive_search(responses.responses.indices, items) do item_idx
        return compute_criterion(objective, objective_state, responses, item_idx)
    end
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

"""
struct ExhaustiveSearch <: NextItemStrategy end

function best_item(
        rule::ItemCriterionRule{ExhaustiveSearch, ItemCriterionT},
        responses::TrackedResponses,
        items
) where {ItemCriterionT <: ItemCriterion}
    exhaustive_search(rule.criterion, responses, items)[1]
end