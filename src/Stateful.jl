"""
This module defines the interface for a stateful CAT as well as an implementation in terms
of [CatRules](@ref).
The interface is meant to enable polymorphic use of different CAT implementations.
"""
module Stateful

using DocStringExtensions

using FittedItemBanks: AbstractItemBank, ResponseType, ItemResponse, resp_vec
using ..Aggregators: TrackedResponses, Aggregators
using ..CatConfig: CatLoopConfig, CatRules
using ..Responses: BareResponses, Response, Responses
using ..NextItemRules: compute_criteria, best_item
using ..Sim: Sim, item_label

export StatefulCat, StatefulCatConfig
public next_item, ranked_items, item_criteria
public add_response!, rollback!, reset!, get_responses, get_ability

"""
$(TYPEDEF)

Abstract supertype for implementation of the stateful CAT interface.
"""
abstract type StatefulCat end

"""
```julia
$(FUNCTIONNAME)(config::StatefulCat) -> IndexT
```

Returns the index of the best next item according to the CAT.

Ideally `IndexT` will be an integer and the return type a 1-based index, however it
should at least be the same type as accepted by [add_response!](@ref).
"""
function next_item end

"""
```julia
$(FUNCTIONNAME)(config::StatefulCat) -> AbstractVector{IndexT}
```

Return a vector of indices of the sorted from best to worst item according to the CAT.
"""
function ranked_items end

"""
```julia
$(FUNCTIONNAME)(config::StatefulCat) -> AbstractVector{CriteriaT}
```

Returns a vector of criteria values for each item in the item bank.

The criteria can vary, but should attempt to interoperate with ComputerAdaptiveTesting.jl.
"""
function item_criteria end

"""
```julia
$(FUNCTIONNAME)(config::StatefulCat, index::IndexT, response::ResponseT)
````

The exact response type `ResponseT` depends on the item bank.
It should be chosen to interoperate with any equivalent item bank according to the
implementation in `ComputerAdaptiveTesting.jl`.
"""
function add_response! end

"""
```julia
$(FUNCTIONNAME)(config::StatefulCat)
```

Rollback the last response added with [add_response!](@ref).

Some CAT implementations may not support this operation in which case they will
throw an error.
"""
function rollback! end


"""
```julia
$(FUNCTIONNAME)(config::StatefulCat)
```

Reset the CAT to its initial state, removing all responses.
"""
function reset! end

"""
```julia
$(FUNCTIONNAME)(config::StatefulCat, item_bank::AbstractItemBank)
```

Set the current item bank of the CAT.
This will also reset the CAT to its initial state, removing all responses.

Some CAT implementations may not support this operation in which case they will
throw an error.
"""
function set_item_bank! end

"""
```julia
$(FUNCTIONNAME)(config::StatefulCat) -> Tuple{AbstractVector{IndexT}, AbstractVector{ResponseT}}
```

Returns a tuple of the indices and responses of the items that have been
added to the CAT with [add_response!](@ref) so far.
"""
function get_responses end

"""
```julia
$(FUNCTIONNAME)(config::StatefulCat) -> AbilityT
```

Return the current ability estimate according to the CAT.
The type of the ability estimate `AbilityT` depends on the CAT implementation
but should attempt to interoperate with ComputerAdaptiveTesting.jl.
"""
function get_ability end

"""
```julia
$(FUNCTIONNAME)(config::StatefulCat)
````

Return number of items in the current item bank.
"""
function item_bank_size end

"""
```julia
$(FUNCTIONNAME)(config::StatefulCat, index::IndexT, ability::AbilityT) -> AbstractVector{Float}
````

Return the vector of probability of different responses to item at
`index` for someone with a certain `ability` according to the IRT
model backing the CAT.
"""
function item_response_functions end

## Running the CAT
function Sim.run_cat(cat_config::CatLoopConfig{RulesT},
        ib_labels = nothing) where {RulesT <: StatefulCat}
    (; stateful_cat, get_response, new_response_callback) = cat_config
    while true
        next_index = next_item(stateful_cat)
        next_label = item_label(ib_labels, next_index)
        @debug "Querying" next_index next_label
        response = get_response(next_index, next_label)
        @debug "Got response" response
        add_response!(stateful_cat, next_index, response)
        terminating = termination_condition(responses, item_bank)
        if new_response_callback !== nothing
            new_response_callback(get_responses(responses), terminating)
        end
        if terminating
            @debug "Met termination condition"
            break
        end
    end
    return (
        get_responses(stateful_cat),
        get_ability(stateful_cat)
    )
end

## TODO: Materialise the cat into a decsision tree

"""
$(TYPEDEF)
$(TYPEDSIGNATURES)

This is a the `StatefulCat` implementation in terms of `CatRules`.
It is also the de-facto standard for the behavior of the interface.
"""
struct StatefulCatConfig{TrackedResponsesT <: TrackedResponses} <: StatefulCat
    rules::CatRules
    tracked_responses::Ref{TrackedResponsesT}
end

function StatefulCatConfig(rules::CatRules, item_bank::AbstractItemBank)
    bare_responses = BareResponses(ResponseType(item_bank))
    tracked_responses = TrackedResponses(
        bare_responses,
        item_bank,
        rules.ability_tracker
    )
    return StatefulCatConfig(rules, Ref(tracked_responses))
end

function next_item(config::StatefulCatConfig)
    return best_item(config.rules.next_item, config.tracked_responses[])
end

function ranked_items(config::StatefulCatConfig)
    return sortperm(compute_criteria(
        config.rules.next_item, config.tracked_responses[]))
end

function item_criteria(config::StatefulCatConfig)
    return compute_criteria(
        config.rules.next_item, config.tracked_responses[])
end

function add_response!(config::StatefulCatConfig, index, response)
    tracked_responses = config.tracked_responses[]
    Responses.add_response!(
        tracked_responses, Response(
            ResponseType(tracked_responses.item_bank), index, response))
end

function rollback!(config::StatefulCatConfig)
    Responses.pop_response!(config.tracked_responses[])
end

function reset!(config::StatefulCatConfig)
    empty!(config.tracked_responses[])
end

function set_item_bank!(config::StatefulCatConfig, item_bank)
    bare_responses = BareResponses(ResponseType(item_bank))
    config.tracked_responses[] = TrackedResponses(
        bare_responses,
        item_bank,
        config.rules.ability_tracker
    )
end

function get_responses(config::StatefulCatConfig)
    return config.tracked_responses[].responses
end

function get_ability(config::StatefulCatConfig)
    return (config.rules.ability_estimator(config.tracked_responses[]), nothing)
end

function item_bank_size(config::StatefulCatConfig)
    return length(config.tracked_responses[].item_bank)
end

function item_response_functions(config::StatefulCatConfig, index, ability)
    item_bank = config.tracked_responses[].item_bank
    item_response = ItemResponse(item_bank, index)
    return resp_vec(item_response, ability)
end

## TODO: Implementation for MaterializedDecisionTree

end
