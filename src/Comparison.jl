module Comparison

using StatsBase
using FittedItemBanks: AbstractItemBank, ResponseType
using ..Responses
using ..CatConfig: CatLoopConfig, CatRules
using ..Aggregators: TrackedResponses, add_response!, Speculator, Aggregators
using ..DecisionTree: TreePosition

using HypothesisTests
using EffectSizes

export run_random_comparison, run_comparison
export CatComparisonExecutionStrategy, IncreaseItemBankSizeExecutionStrategy
export FollowOneExecutionStrategy, RunIndependentlyExecutionStrategy
export DecisionTreeExecutionStrategy

struct RandomCatComparison
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
    RandomCatComparison(true_abilities, rand_abilities, cat_abilities, cat_idxs)
end

# Comparison scenarios:
#  * Want to benchmark:
#    * Perf: runtime/memory usage
#    * Accuracy and/or agreement of similar next item rules
#      * Is the same item chosen?
#      * If not, what rank is it
#      * What is the correlation between
#    * Convergence of ability estimates
#  * Inputs to benchmark:
#    * Random / specified item bank
#      * Increasing sample sizes of same item bank
#    * Previous responses:
#      * Random responses
#      * Specified/real responses
#      * Responses from a random or specified ability
#      * Single or many point in time / following single path randomly / most likely response responses from decision
#        * Following what: which rule gets to be ground truth
#  * Random vs. One

function measure_all(config, phase, phase_func; kwargs...)
    measurement_results = []
    responses = TrackedResponses(
        BareResponses(ResponseType(strategy.item_bank)),
        strategy.item_bank,
        config.ability_tracker
    )
    for measurement in config.measurements
        result = phase_func(measurement; kwargs...)
        if result === nothing
            continue
        end
        push!(measurement_results, result)
    end
    if !isempty(measurement_results)
        config.callback(phase, measurement_results)
    end
end

abstract type CatComparisonExecutionStrategy end

struct IncreaseItemBankSizeExecutionStrategy <: CatComparisonExecutionStrategy
    item_bank::AbstractItemBank
    sizes::AbstractVector{Int}
end

function run_comparison(strategy::IncreaseItemBankSizeExecutionStrategy, config)
    for size in sizes
        subsetted_item_bank = subset(item_bank, size)
        responses = TrackedResponses(
            BareResponses(ResponseType(strategy.item_bank)),
            subsetted_item_bank,
            config.ability_tracker
        )
        measure_all(config, :before_next_item, before_next_item; responses = responses)
        timed_next_item = @time config.next_item(responses, item_bank)
        next_item = timed_next_item.value
        measure_all(config, :after_next_item, after_next_item;
            responses = responses, next_item = next_item)
    end
end

struct FollowOneExecutionStrategy <: CatComparisonExecutionStrategy
    item_bank::AbstractItemBank
    gold::Symbol
end

function run_comparison(strategy::FollowOneExecutionStrategy, config)
    error("Not implemented")
end

struct RunIndependentlyExecutionStrategy <: CatComparisonExecutionStrategy
    item_bank::AbstractItemBank
end

function run_comparison(strategy::RunIndependentlyExecutionStrategy, config)
    error("Not implemented")
end

struct DecisionTreeExecutionStrategy <: CatComparisonExecutionStrategy
    item_bank::AbstractItemBank
    max_depth::UInt
end

@kwdef struct MultiTrackedResponses{
    BareResponsesT <: BareResponses,
    ItemBankT <: AbstractItemBank,
    AbilityTrackerNamedTupleT
}
    responses::BareResponsesT
    item_bank::ItemBankT
    ability_trackers::AbilityTrackerNamedTupleT
end

function Aggregators.add_response!(tracked_responses::MultiTrackedResponses, response)
    add_response!(tracked_responses.responses, response)
    track!(tracked_responses)
end

function Aggregators.pop_response!(tracked_responses::MultiTrackedResponses)
    pop_response!(tracked_responses.responses)
end

function iter_tracked_responses(mtr)
    return (
        TrackedResponses(mtr.responses, mtr.item_bank, ability_tracker)
    for ability_tracker in mtr.ability_trackers
    )
end

function run_comparison(strategy::DecisionTreeExecutionStrategy, configs)
    state_tree = TreePosition(strategy.max_depth)
    multi_tracked_reponses = MultiTrackedResponses(
        BareResponses(ResponseType(strategy.item_bank)),
        strategy.item_bank,
        [config.ability_tracker for config in configs]
    )
    while true
        for (responses, config) in zip(
            iter_tracked_responses(multi_tracked_reponses), configs)
            track!(responses, config.ability_tracker)
            measure_all(config, :before_next_item, before_next_item; responses = responses)
            timed_next_item = @time config.next_item(responses, item_bank)
            next_item = timed_next_item.value
            measure_all(config, :after_next_item, after_next_item;
                responses = responses, next_item = next_item)
        end

        if state_tree.cur_depth == state_tree.max_depth
            # Final ability estimates
            for resp in (false, true)
                for (responses, config) in zip(
                    iter_tracked_responses(multi_tracked_reponses), configs)
                    add_response!(
                        responses, Response(ResponseType(item_bank), next_item, resp))
                    measure_all(
                        config, :final_ability, final_ability; responses = responses)
                    pop_response!(responses)
                end
            end
        end

        if next!(state_tree, multi_tracked_reponses, item_bank, next_item, ability)
            break
        end
    end
end

#=
Base.@kwdef struct CatComparisonConfig
    """
    A named tuple with the (named) CatRules (or compatable) to be compared
    """
    rules
    """
    """
    execution_strategy::CatComparisonExecutionStrategy
    """
    """
    measurements::Vector{}
    """
    """
    callback
end

function run_comparison(cat_comparison::CatComparisonConfig)
    run_comparison(cat_comparison.execution_strategy)
end
=#

const tests = [
    UnequalVarianceTTest,
    ExactSignedRankTest,
    SignTest
]

name(typ) = string(Base.typename(typ).wrapper)

function compare(comparison::RandomCatComparison)
    (cat_iters, num_testees) = size(comparison.cat_idxs)
    cat_diffs = abs.(comparison.cat_abilites .- reshape(comparison.true_abilities, 1, :))
    # For now we just take the median of the random differences. There might be a better way of integrating the whole distribution(?)
    # Could we generate a pair for each random sample by duplicating the treatment difference?
    all_rand_diffs = abs.(comparison.rand_abilities .-
                          reshape(comparison.true_abilities, 1, 1, :))
    med_rand_diffs = dropdims(median(all_rand_diffs, dims = 1), dims = 1)
    @info "compare" size(cat_diffs) size(all_rand_diffs) size(med_rand_diffs)
    cols = Dict("iteration" => Array{Int}(undef, cat_iters),
        "cohens_d" => Array{Float64}(undef, cat_iters),
        [name(test) => Array{Float64}(undef, cat_iters) for test in tests]...)
    for iter in 1:cat_iters
        cols["iteration"][iter] = iter
        cols["cohens_d"][iter] = effectsize(CohenD(cat_diffs[iter, :],
            med_rand_diffs[iter, :]))
        for test in tests
            cols[name(test)][iter] = pvalue(test(cat_diffs[iter, :],
                med_rand_diffs[iter, :]))
        end
    end
    DataFrame(cols)
end

end
