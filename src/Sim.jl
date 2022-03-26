module Sim

using Reexport, FromFile

@from "./CatConfig.jl" using CatConfig: CatLoopConfig
@from "./item_banks/ItemBanks.jl" using ItemBanks: AbstractItemBank

export run_cat

"""
This response callback simply prompts 
"""
function prompt_response(index_, label)
    println("Response for $label > ")
    parse(Int8, readline())
end

"""
This function constructs 
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
    responses = []
    # TrackedResponses()
    while true
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
        next_label = get(item_bank.labels, next_index) do 
            "<<item #$next_index>>"
        end
        @debug "Querying" next_label
        response = cat_config.get_response(next_index, next_label)
        @debug "Got response" response
        add_response(responses, Response(next_index, response))
        if cat_config.termination_condition(responses, item_bank)
            @debug "Met termination condition"
            break
        end
    end
    cat_config.ability_estimator(responses)
end

end