"""
$(TYPEDEF)
$(TYPEDFIELDS)

This content balancing procedure takes target proportions for each group of items.
At each step the group with the lowest ratio of seen items to target is selected.

http://dx.doi.org/10.1207/s15324818ame0403_4
"""
struct GreedyForcedContentBalancer{InnerRuleT <: NextItemRule} <: NextItemRule
    targets::Vector{Float64}
    groups::Vector{Int}
    inner_rule::InnerRuleT
end

function GreedyForcedContentBalancer(targets::Dict, groups, bits...)
    targets_vec = zeros(Float64, length(targets))
    groups_idxs = zeros(Int, length(groups))
    group_lookup = Dict{Any, Int}()
    for (idx, group) in enumerate(groups)
        if haskey(group_lookup, group)
            group_idx = group_lookup[group]
        else
            group_idx = length(group_lookup) + 1
            group_lookup[group] = group_idx
        end
        groups_idxs[idx] = group_idx
    end
    if length(group_lookup) != length(targets)
        error("Number of groups $(length(group_lookup)) does not match number of targets $(length(targets))")
    end
    for (group, group_idx) in pairs(group_lookup)
        targets_vec[group_idx] = get(targets, group, 0.0)
    end
    GreedyForcedContentBalancer(targets_vec, groups_idxs, bits...)
end

function GreedyForcedContentBalancer(targets::AbstractVector, groups, bits...)
    GreedyForcedContentBalancer(targets, groups, NextItemRule(bits...))
end

function show(io::IO, ::MIME"text/plain", rule::GreedyForcedContentBalancer)
    indent_io = indent(io, 2)
    println(io, "Greedy + forced content balancing")
    println(indent_io, "Target ratio: " * join(rule.targets, ", "))
    show(indent_io, MIME("text/plain"), rule.inner_rule)
end

function next_item_bank(targets, groups, responses, items)
    seen = zeros(UInt, size(targets))
    indices = responses.responses.indices
    for group_idx in groups[indices]
        seen[group_idx] += 1
    end
    next_group_idx = argmin(seen ./ targets)
    matching_indicator = groups .== next_group_idx
    next_items = subset_view(items, matching_indicator)
    return (next_items, matching_indicator)
end

function best_item(
    rule::GreedyForcedContentBalancer,
    responses::TrackedResponses,
    items
)
    next_items, matching_indicator = next_item_bank(rule.targets, rule.groups, responses, items)
    inner_idx = best_item(rule.inner_rule, responses, next_items)
    for (outer_idx, in_group) in enumerate(matching_indicator)
        if in_group
            inner_idx -= 1
            if inner_idx <= 0
                return outer_idx
            end
        end
    end
    error("No item found in group length $(length(next_items)) with inner index $inner_idx")
end

function compute_criteria(
    rule::GreedyForcedContentBalancer,
    responses::TrackedResponses,
    items
)
    next_items, matching_indicator = next_item_bank(rule.targets, rule.groups, responses, items)
    criteria = compute_criteria(rule.inner_rule, responses, next_items)
    expanded = fill(Inf, length(items))
    expanded[matching_indicator] .= criteria
    return expanded
end