module Sim

using DocStringExtensions
using StatsBase
using FittedItemBanks: AbstractItemBank, ResponseType
using ..Responses
using ..CatConfig: CatLoopConfig, CatRules
using ..Aggregators: TrackedResponses,
                     add_response!,
                     Aggregators,
                     AbilityIntegrator,
                     AbilityEstimator,
                     LikelihoodAbilityEstimator,
                     PriorAbilityEstimator,
                     ModeAbilityEstimator,
                     MeanAbilityEstimator,
                     LikelihoodAbilityEstimator,
                     RiemannEnumerationIntegrator
using ..NextItemRules: compute_criteria, best_item

export run_cat, prompt_response, auto_responder

"""
$(TYPEDSIGNATURES)

This response callback simply prompts the user for the response using the console
"""
function prompt_response(index_, label)
    println("Response for $label > ")
    parse(Int8, readline())
end

"""
$(TYPEDSIGNATURES)

This function constructs a next item function which automatically responds
according to `responses`.
"""
function auto_responder(responses)
    function (index, label_)
        responses[index]
    end
end

abstract type NextItemError <: Exception end

function item_label(ib_labels, next_index)
    default_next_label(next_index) = "<<item #$next_index>>"
    if ib_labels === nothing
        return default_next_label(next_index)
    else
        return get(default_next_label, ib_labels, next_index)
    end
end

"""
```julia
$(FUNCTIONNAME)(cat_config::CatLoopConfig, item_bank::AbstractItemBank; ib_labels=nothing)
```

Run a given [CatLoopConfig](@ref) `cat_config` on the given `item_bank`.
If `ib_labels` is not given, default labels of the form
`<<item #\$index>>` are passed to the callback.
"""
function run_cat(cat_config::CatLoopConfig{RulesT},
        item_bank::AbstractItemBank;
        ib_labels = nothing) where {RulesT <: CatRules}
    (; rules, get_response, new_response_callback) = cat_config
    (; next_item, termination_condition, ability_estimator, ability_tracker) = rules
    responses = TrackedResponses(BareResponses(ResponseType(item_bank)),
        item_bank,
        ability_tracker)
    while true
        local next_index
        @debug begin
            criteria = compute_criteria(next_item, responses, item_bank)
            "Best items"
        end criteria
        try
            next_index = best_item(next_item, responses, item_bank)
        catch exc
            if isa(exc, NextItemError)
                @warn "Terminating early due to error getting next item" err=sprint(
                    showerror,
                    exc)
                break
            else
                rethrow()
            end
        end
        next_label = item_label(ib_labels, next_index)
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
    (responses.responses, ability_estimator(responses))
end

end
