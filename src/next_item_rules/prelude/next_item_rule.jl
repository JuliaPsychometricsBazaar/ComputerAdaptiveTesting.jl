function NextItemRule(bits...;
        ability_estimator = nothing,
        ability_tracker = nothing)
    @returnsome find1_instance(NextItemRule, bits)
    @returnsome ItemCriterionRule(bits...,
        ability_estimator = ability_estimator,
        ability_tracker = ability_tracker)
end

function NextItemStrategy()
    ExhaustiveSearch()
end

function NextItemStrategy(bits...)
    @returnsome find1_instance(NextItemStrategy, bits)
    @returnsome find1_type(NextItemStrategy, bits) typ->typ()
    @returnsome NextItemStrategy()
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

`ItemCriterionRule` which together with a `NextItemStrategy` acts as an
adapter by which an `ItemCriterion` can serve as a `NextItemRule`.

    $(FUNCTIONNAME)(bits...; ability_estimator=nothing

Implicit constructor for $(FUNCTIONNAME). Will default to
`ExhaustiveSearch` when no `NextItemStrategy` is given.
"""
struct ItemCriterionRule{
    NextItemStrategyT <: NextItemStrategy,
    ItemCriterionT <: ItemCriterion
} <: NextItemRule
    strategy::NextItemStrategyT
    criterion::ItemCriterionT
end

function ItemCriterionRule(bits...;
        ability_estimator = nothing,
        ability_tracker = nothing)
    strategy = NextItemStrategy(bits...)
    criterion = ItemCriterion(bits...;
        ability_estimator = ability_estimator,
        ability_tracker = ability_tracker)
    if strategy !== nothing && criterion !== nothing
        return ItemCriterionRule(strategy, criterion)
    end
end

function best_item(rule::NextItemRule, tracked_responses::TrackedResponses)
    best_item(rule, tracked_responses, tracked_responses.item_bank)
end

function Base.show(io::IO, ::MIME"text/plain", rule::ItemCriterionRule)
    println(io, "Pick optimal item criterion according to strategy")
    indent_io = indent(io, 2)
    show(indent_io, MIME"text/plain"(), rule.strategy)
    show(indent_io, MIME"text/plain"(), rule.criterion)
end

# Default implementation
function compute_criteria(::NextItemRule, ::TrackedResponses)
    nothing
end
