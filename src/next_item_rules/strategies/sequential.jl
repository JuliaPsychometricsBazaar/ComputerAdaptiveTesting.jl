"""
$(TYPEDEF)
$(TYPEDFIELDS)

This is the most basic rule for choosing the next item in a CAT. It simply
picks a random item from the set of items that have not yet been
administered.
"""
@kwdef struct PiecewiseNextItemRule{RulesT} <: NextItemRule
    # Tuple of Ints
    breaks::Tuple{Int}
    # Tuple of NextItemRules
    rules::RulesT
end

#tuple_len(::NTuple{N, Any}) where {N} = Val{N}()

function current_rule(rule::PiecewiseNextItemRule, responses::TrackedResponses)
    for brk in 1:length(rule.breaks)
        if length(responses) < rule.breaks[brk]
            return rule.rules[brk]
        end
    end
    return rule.rules[end]
end

function best_item(rule::PiecewiseNextItemRule, responses::TrackedResponses, items)
    return best_item(current_rule(rule, responses), responses, items)
end

function compute_criteria(rule::PiecewiseNextItemRule, responses::TrackedResponses)
    return compute_criteria(current_rule(rule, responses), responses)
end

"""
"""
@kwdef struct MemoryNextItemRule{MemoryT} <: NextItemRule
    item_idxs::MemoryT
end

function best_item(rule::MemoryNextItemRule, responses::TrackedResponses, _items)
    return rule.item_idxs[length(responses) + 1]
    # XXX: A few problems with this:
    # 1. Could run out of `item_idxs`
    # 2. Could return an item not in `items`
    # TODO: Add some basic error checking -- can only panic
end

function FixedFirstItemNextItemRule(item_idx::Int, rule::NextItemRule)
    PiecewiseNextItemRule((1,), (MemoryNextItemRule((item_idx,)), rule))
end