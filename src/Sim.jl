module Sim

using StatsBase
using ..Responses
using ..CatConfig: CatLoopConfig
using ..ItemBanks: AbstractItemBank, labels
using ..Aggregators: TrackedResponses, add_response!, Speculator

export run_cat, prompt_response, auto_responder

"""
This response callback simply prompts 
"""
function prompt_response(index_, label)
    println("Response for $label > ")
    parse(Int8, readline())
end

"""
This function constructs a next item function which automatically responds
according to `responses`.
"""
function auto_responder(responses)
    function(index, label_)
        responses[index]
    end
end

abstract type NextItemError <: Exception end

"""
Run a given CatLoopConfig
"""
function run_cat(cat_config::CatLoopConfig, item_bank::AbstractItemBank)
    (; rules, get_response, new_response_callback) = cat_config
    (; next_item, termination_condition, ability_estimator, ability_tracker) = rules
    responses = TrackedResponses(
        BareResponses(ResponseType(item_bank)),
        item_bank,
        ability_tracker
    )
    ib_labels = labels(item_bank)
    while true
        local next_index
        try
            next_index = next_item(responses, item_bank)
        catch exc
            if isa(exc, NextItemError)
                @warn "Terminating early due to error getting next item" err=sprint(showerror, e)
                break
            else
                rethrow()
            end
        end
        default_next_label(next_index) = "<<item #$next_index>>"
        if ib_labels === nothing
            next_label = default_next_label(next_index)
        else
            next_label = get(default_next_label, ib_labels, next_index)
        end
        @debug "Querying" next_label
        response = get_response(next_index, next_label)
        @debug "Got response" response
        add_response!(responses, Response(ResponseType(item_bank), next_index, response))
        terminating = termination_condition(responses, item_bank)
        if new_response_callback !== nothing
            new_response_callback(responses, terminating)
        end
        if terminating
            @debug "Met termination condition"
            break
        end
    end
    (responses, ability_estimator(responses))
end

end