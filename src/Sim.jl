module Sim

using StatsBase
using FittedItemBanks: AbstractItemBank, ResponseType
using ..Responses
using ..CatConfig: CatLoopConfig, CatRules
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
Run a given CatLoopConfig
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
        try
            next_index = next_item(responses, item_bank)
        catch exc
            if isa(exc, NextItemError)
                @warn "Terminating early due to error getting next item" err=sprint(showerror,
                    e)
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

struct CatComparison
    true_abilities::Array{Float64}
    rand_abilities::Array{Float64, 3}
    cat_abilites::Array{Float64, 2}
    cat_idxs::Array{Int, 2}
end

"""
This function compares a given CAT configuration with a CAT using a random next
item selection rule.
"""
function run_random_comparison(next_item,
        ability_estimator,
        item_bank::AbstractItemBank,
        responses,
        max_num_questions,
        rand_samples = 5)
    # XXX: termination_condition is ignored
    num_questions, num_testees = size(responses)
    rand_question_idxs = Array{Int}(undef, max_num_questions, rand_samples)
    for rand_samp_idx in 1:rand_samples
        sample!(1:num_questions,
            (@view rand_question_idxs[:, rand_samp_idx]);
            replace = false)
    end
    true_abilities = Array{Float64}(undef, num_testees)
    rand_abilities = Array{Float64, 3}(undef, rand_samples, max_num_questions, num_testees)
    cat_abilities = Array{Float64, 2}(undef, max_num_questions, num_testees)
    cat_idxs = Array{Int, 2}(undef, max_num_questions, num_testees)
    for testee_idx in 1:num_testees
        function testee_responses(idxs)
            BareResponses(ResponseType(item_bank),
                idxs,
                (@view responses[idxs, testee_idx]))
        end
        all_responses = testee_responses(1:num_questions)
        true_abilities[testee_idx] = ability_estimator(TrackedResponses(all_responses,
            item_bank))
        for cat_iter in 1:max_num_questions
            #rand_question_idx = rand_question_idxs[cat_iter, rand(1:rand_samples)]
            for rand_sample_idx in 1:rand_samples
                idxs = @view rand_question_idxs[1:cat_iter, rand_sample_idx]
                ability_est = ability_estimator(TrackedResponses(testee_responses(idxs),
                    item_bank))
                rand_abilities[rand_sample_idx, cat_iter, testee_idx] = ability_est
            end
            cur_cat_idxs = @view cat_idxs[1:(cat_iter - 1), testee_idx]
            cat_tracked_responses = TrackedResponses(testee_responses(cur_cat_idxs),
                item_bank)
            # TrackedResponses(@view responses[cat_idxs, testee_idx]
            cat_idxs[cat_iter, testee_idx] = next_item(cat_tracked_responses, item_bank)
            cat_abilities[cat_iter, testee_idx] = ability_estimator(cat_tracked_responses)
        end
    end
    CatComparison(true_abilities, rand_abilities, cat_abilities, cat_idxs)
end

end
