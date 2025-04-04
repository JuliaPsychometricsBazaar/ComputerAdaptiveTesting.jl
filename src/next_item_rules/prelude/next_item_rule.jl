function NextItemRule(bits...;
        ability_estimator = nothing,
        ability_tracker = nothing,
        parallel = true)
    @returnsome find1_instance(NextItemRule, bits)
    @returnsome ItemStrategyNextItemRule(bits...,
        ability_estimator = ability_estimator,
        ability_tracker = ability_tracker,
        parallel = parallel)
end

function NextItemStrategy(; parallel = true)
    ExhaustiveSearch(parallel)
end

function NextItemStrategy(bits...; parallel = true)
    @returnsome find1_instance(NextItemStrategy, bits)
    @returnsome find1_type(NextItemStrategy, bits) typ->typ(; parallel = parallel)
    @returnsome NextItemStrategy(; parallel = parallel)
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

`ItemStrategyNextItemRule` which together with a `NextItemStrategy` acts as an
adapter by which an `ItemCriterion` can serve as a `NextItemRule`.

    $(FUNCTIONNAME)(bits...; ability_estimator=nothing, parallel=true)

Implicit constructor for $(FUNCTIONNAME). Will default to
`ExhaustiveSearch` when no `NextItemStrategy` is given.
"""
struct ItemStrategyNextItemRule{
    NextItemStrategyT <: NextItemStrategy,
    ItemCriterionT <: ItemCriterion
} <: NextItemRule
    strategy::NextItemStrategyT
    criterion::ItemCriterionT
end

function ItemStrategyNextItemRule(bits...;
        parallel = true,
        ability_estimator = nothing,
        ability_tracker = nothing)
    strategy = NextItemStrategy(bits...; parallel = parallel)
    criterion = ItemCriterion(bits...;
        ability_estimator = ability_estimator,
        ability_tracker = ability_tracker)
    if strategy !== nothing && criterion !== nothing
        return ItemStrategyNextItemRule(strategy, criterion)
    end
end

function best_item(rule::NextItemRule, tracked_responses::TrackedResponses)
    best_item(rule, tracked_responses, tracked_responses.item_bank)
end