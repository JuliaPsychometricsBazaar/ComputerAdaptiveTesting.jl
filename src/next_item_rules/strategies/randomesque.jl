using QuickHeaps: BinaryHeap, FastMax, Node, get_val
using StatsBase: sample


function randomesque(
    rng::AbstractRNG,
    objective::ItemCriterion,
    responses::TrackedResponses,
    items::AbstractItemBank,
    k::Int
)
    objective_state = init_thread(objective, responses)
    heap = BinaryHeap{Node{Int, Float64}}(o = FastMax)
    sizehint!(heap, k)
    for item_idx in eachindex(items)
        if (findfirst(idx -> idx == item_idx, responses.responses.indices) !== nothing)
            continue
        end

        obj_val = compute_criterion(objective, objective_state, responses, item_idx)

        if length(heap) < k
            push!(heap, Node(item_idx, obj_val))
        elseif obj_val < get_val(peek(heap))
            heap[1] = Node(item_idx, obj_val)
        end
    end
    if length(heap) >= 1
        Tuple(sample(rng, heap))
    else
        return (-1, Inf)
    end
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

"""
struct RandomesqueStrategy <: NextItemStrategy
    rng::AbstractRNG
    k::Int
end

RandomesqueStrategy(k::Int) = RandomesqueStrategy(Xoshiro(), k)

function best_item(
    rule::ItemStrategyNextItemRule{RandomesqueStrategy, ItemCriterionT},
    responses::TrackedResponses,
    items
) where {ItemCriterionT <: ItemCriterion}
    randomesque(rule.rng, rule.criterion, responses, items, rule.k)[1]
end