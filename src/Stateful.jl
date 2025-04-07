module Stateful

using FittedItemBanks: AbstractItemBank, ResponseType
using ..Aggregators: TrackedResponses, Aggregators
using ..CatConfig: CatLoopConfig, CatRules
using ..Responses: BareResponses, Response
using ..NextItemRules: compute_criteria, best_item

export StatefulCat, StatefulCatConfig, run_cat
public next_item, ranked_items, item_criteria
public add_response!, rollback!, reset!, get_responses, get_ability

## StatefulCat interface
abstract type StatefulCat end

function next_item end

function ranked_items end

function item_criteria end

function add_response! end

#function add_responses! end

function rollback! end

function reset! end

function get_responses end

function get_ability end

## Running the CAT
function run_cat(cat_config::CatLoopConfig{RulesT},
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

## Implementation for CatConfig
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
    Aggregators.add_response!(
        tracked_responses, Response(
            ResponseType(tracked_responses.item_bank), index, response))
end

function rollback!(config::StatefulCatConfig)
    pop_response!(config.tracked_responses[])
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

## TODO: Implementation for MaterializedDecisionTree

end
