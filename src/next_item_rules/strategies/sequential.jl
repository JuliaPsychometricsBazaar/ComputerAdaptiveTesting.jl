"""
$(TYPEDEF)
$(TYPEDFIELDS)

"""
@kwdef struct FixedRuleSequencer{RulesT} <: NextItemRule
    # Tuple of Ints
    breaks::Tuple{Int}
    # Tuple of NextItemRules
    rules::RulesT
end

#tuple_len(::NTuple{N, Any}) where {N} = Val{N}()

function current_rule(rule::FixedRuleSequencer, responses::TrackedResponses)
    for brk in 1:length(rule.breaks)
        if length(responses) < rule.breaks[brk]
            return rule.rules[brk]
        end
    end
    return rule.rules[end]
end

function best_item(rule::FixedRuleSequencer, responses::TrackedResponses, items)
    return best_item(current_rule(rule, responses), responses, items)
end

function compute_criteria(rule::FixedRuleSequencer, responses::TrackedResponses)
    return compute_criteria(current_rule(rule, responses), responses)
end

function show(io::IO, ::MIME"text/plain", rule::FixedRuleSequencer)
    indent_io = indent(io, 2)
    println(io, "Fixed rule sequencing:")
    print(indent_io, "Firstly: ")
    show(indent_io, MIME("text/plain"), rule.rules[1])
    for (responses, rule) in zip(rule.breaks, rule.rules[2:end])
        print(indent_io, "After $responses responses: ")
        show(indent_io, MIME("text/plain"), rule)
    end
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

function show(io::IO, ::MIME"text/plain", rule::MemoryNextItemRule)
    item_list = join(rule.item_idxs, ", ")
    println(io, "Present the items indexed: $item_list")
end

function FixedFirstItemNextItemRule(item_idx::Int, rule::NextItemRule)
    FixedRuleSequencer((1,), (MemoryNextItemRule((item_idx,)), rule))
end