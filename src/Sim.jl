module Sim

using ..Responses: BareResponses, Response
using ..CatConfig: CatLoopConfig
using ..ItemBanks: AbstractItemBank, labels
using ..Aggregators: TrackedResponses, add_response!, Speculator

export run_cat

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
function run_cat(cat_config::CatLoopConfig, item_bank::AbstractItemBank)::Float64
    responses = TrackedResponses(
        BareResponses(),
        item_bank,
        cat_config.ability_tracker,
        cat_config.ability_estimator
    )
    ib_labels = labels(item_bank)
    while true
        local next_index
        try
            next_index = cat_config.next_item(responses, item_bank)
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
        response = cat_config.get_response(next_index, next_label)
        @debug "Got response" response
        add_response!(responses, Response(next_index, response))
        terminating = cat_config.termination_condition(responses, item_bank)
        cat_config.new_response_callback(responses, terminating)
        if terminating
            @debug "Met termination condition"
            break
        end
    end
    cat_config.ability_estimator(responses)
end

end