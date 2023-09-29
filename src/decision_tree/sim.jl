import ComputerAdaptiveTesting: Sim


"""
Run a given CatLoopConfig with a MaterializedDecisionTree
"""
function Sim.run_cat(cat_config::Sim.CatLoopConfig{RulesT}, item_bank::AbstractItemBank; ib_labels=nothing) where {RulesT <: MaterializedDecisionTree}
    (; rules, get_response, new_response_callback) = cat_config

    response_type = ResponseType(item_bank)
    if !isa(response_type, BooleanResponse)
        error("Decision trees are only supported for boolean responses")
    end
    responses = BareResponses(response_type)
    while true
        next_index = next_item(rules, responses)
        next_label = Sim.item_label(ib_labels, next_index)
        @debug "Querying" next_label
        response = get_response(next_index, next_label)
        @debug "Got response" response
        add_response!(responses, Response(ResponseType(item_bank), next_index, response))
        terminating = termination_condition(rules, responses)
        if new_response_callback !== nothing
            new_response_callback(responses, terminating)
        end
        if terminating
            @debug "Met termination condition"
            break
        end
    end
    (responses, ability_estimate(rules, responses))
end