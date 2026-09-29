"""
$(TYPEDEF)
$(TYPEDFIELDS)

This is the most basic rule for choosing the next item in a CAT. It simply
picks a random item from the set of items that have not yet been
administered.
"""
@with_kw struct RandomNextItemRule{RandomT <: AbstractRNG} <: NextItemRule
    rng::RandomT = Xoshiro()
end

function power_summary(io::IO, rule::RandomNextItemRule)
    println(io, "Select a random unanswered item")
    println(indent(io, 2), "Random number generator: ", nameof(typeof(rule.rng)))
end

function best_item(rule::RandomNextItemRule, responses::TrackedResponses, items)
    # TODO: This is not efficient
    item_idxes = Set(1:length(items))
    available = setdiff(item_idxes, Set(responses.responses.indices))
    rand(rule.rng, available)
end
