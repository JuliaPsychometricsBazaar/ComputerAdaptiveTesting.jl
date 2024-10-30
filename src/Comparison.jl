module Comparison

# TODO: We are overlapping a bit with CatRecorder here
# Should be kept in mind and kept distinct or code reuse

using StatsBase
using FittedItemBanks: AbstractItemBank, ResponseType
using ..Responses
using ..CatConfig: CatLoopConfig, CatRules
using ..Aggregators: TrackedResponses, add_response!, Speculator, Aggregators, track!,
                     pop_response!
using ..DecisionTree: TreePosition, next!
using Base: Iterators

using HypothesisTests
using EffectSizes
using DataFrames
using ComputerAdaptiveTesting: Stateful

export run_random_comparison, run_comparison
export CatComparisonExecutionStrategy#, IncreaseItemBankSizeExecutionStrategy
#export FollowOneExecutionStrategy, RunIndependentlyExecutionStrategy
#export DecisionTreeExecutionStrategy
export ReplayResponsesExecutionStrategy
export CatComparisonConfig

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

abstract type CatComparisonExecutionStrategy end

Base.@kwdef struct CatComparisonConfig{StrategyT <: CatComparisonExecutionStrategy}
    """
    A named tuple with the (named) CatRules (or compatable) to be compared
    """
    rules::NamedTuple
    """
    The comparison and execution strategy to use
    """
    strategy::StrategyT
    #=
    """
    The measurements applied at given phases
    """
    measurements::Vector{}
    =#
    """
    Which phases to run and/or call the callback on
    """
    phases::Set{Symbol} = Set((:before_next_item, :after_next_item))
    """
    The callback which should take a named tuple with information at different phases
    """
    callback::Any
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

#phase_func=nothing;
function measure_all(comparison, system, cat, phase; kwargs...)
    if !(phase in comparison.phases)
        return
    end
    strategy = comparison.strategy
    #=measurement_results = []
    for measurement in comparison.measurements
        #if phase_func === nothing
            #continue
        #end
        #result = phase_func(measurement; kwargs...)
        result = measurement
        #if result === nothing
            #continue
        #end
        push!(measurement_results, result)
    end=#
    comparison.callback((;
        phase,
        system,
        cat,
        #measurement_results,
        kwargs...
    ))
end

struct IncreaseItemBankSizeExecutionStrategy <: CatComparisonExecutionStrategy
    item_bank::AbstractItemBank
    sizes::AbstractVector{Int}
    starting_responses::Int
end

function IncreaseItemBankSizeExecutionStrategy(item_bank, sizes)
    return IncreaseItemBankSizeExecutionStrategy(item_bank, sizes, 0)
end

function run_comparison(strategy::IncreaseItemBankSizeExecutionStrategy, config)
    for size in strategy.sizes
        subsetted_item_bank = subset(strategy.item_bank, size)
        responses = TrackedResponses(
            BareResponses(ResponseType(strategy.item_bank)),
            subsetted_item_bank,
            config.ability_tracker
        )
        for _ in 1:(strategy.starting_responses)
            next_item = config.next_item(responses, subsetted_item_bank)
            add_response!(responses,
                Response(ResponseType(subsetted_item_bank), next_item, rand(Bool)))
        end
        measure_all(config, :before_next_item, before_next_item; responses = responses)
        timed_next_item = @timed config.next_item(responses, item_bank)
        next_item = timed_next_item.value
        measure_all(config, :after_next_item, after_next_item;
            responses = responses, next_item = next_item)
    end
end

# Which questions to ask
#   * Random
#   * Specified
#   * Follow one CAT
#   * Follow multiple CATs indepdently
#   * Follow multiple CATs and combine them resampling style
# Which answer to use
#   * Random
#   * Random from a specified ability
#   * From response memory
#   * All (generate decision tree)

struct ReplayResponsesExecutionStrategy <: CatComparisonExecutionStrategy
    responses::BareResponses
end

# Which questions to ask: Specified
# Which answer to use: From response memory
function run_comparison(comparison::CatComparisonConfig{ReplayResponsesExecutionStrategy})
    strategy = comparison.strategy
    for (items_answered, response) in zip(
        Iterators.countfrom(0), Iterators.flatten((strategy.responses, [nothing])))
        for (name, cat) in pairs(comparison.rules)
            if :before_item_criteria in comparison.phases
                timed_item_criteria = @timed Stateful.item_criteria(cat)
                measure_all(
                    comparison,
                    name,
                    cat,
                    :before_item_criteria,
                    items_answered = items_answered,
                    item_criteria = timed_item_criteria.value,
                    timing = timed_item_criteria
                )
            end
            if :before_ranked_items in comparison.phases
                timed_ranked_items = @timed Stateful.ranked_items(cat)
                measure_all(
                    comparison,
                    name,
                    cat,
                    :before_ranked_items,
                    items_answered = items_answered,
                    ranked_items = timed_ranked_items.value,
                    timing = timed_ranked_items
                )
            end
            if :before_ability in comparison.phases
                timed_get_ability = @timed Stateful.get_ability(cat)
                measure_all(
                    comparison,
                    name,
                    cat,
                    :before_ability,
                    items_answered = items_answered,
                    ability = timed_get_ability.value,
                    timing = timed_get_ability
                )
            end
            measure_all(
                comparison,
                name,
                cat,
                :before_next_item,
                items_answered = items_answered
            )
            timed_next_item = @timed Stateful.next_item(cat)
            next_item = timed_next_item.value
            measure_all(
                comparison,
                name,
                cat,
                :after_next_item,
                next_item = next_item,
                timing = timed_next_item,
                items_answered = items_answered
            )
            if :after_item_criteria in comparison.phases
                # TOOD: Combine with next_item if possible and requested?
                timed_item_criteria = @timed Stateful.item_criteria(cat)
                measure_all(
                    comparison,
                    name,
                    cat,
                    :after_item_criteria,
                    items_answered = items_answered,
                    item_criteria = timed_item_criteria.value,
                    timing = timed_item_criteria
                )
            end
            if :after_ranked_items in comparison.phases
                timed_ranked_items = @timed Stateful.ranked_items(cat)
                measure_all(
                    comparison,
                    name,
                    cat,
                    :after_ranked_items,
                    items_answered = items_answered,
                    ranked_items = timed_ranked_items.value,
                    timing = timed_ranked_items
                )
            end
            if :after_ability in comparison.phases
                timed_get_ability = @timed Stateful.get_ability(cat)
                measure_all(
                    comparison,
                    name,
                    cat,
                    :after_ability,
                    items_answered = items_answered,
                    ability = timed_get_ability.value,
                    timing = timed_get_ability
                )
            end
            if response !== nothing
                Stateful.add_response!(cat, response.index, response.value)
            end
        end
    end
end

#=
struct FollowOneExecutionStrategy <: CatComparisonExecutionStrategy
    item_bank::AbstractItemBank
    gold::Symbol
end

function run_comparison(strategy::FollowOneExecutionStrategy, configs)
    configs[strategy.gold]
end

struct RunIndependentlyExecutionStrategy <: CatComparisonExecutionStrategy
    item_bank::AbstractItemBank
end

function run_comparison(strategy::RunIndependentlyExecutionStrategy, config)
    error("Not implemented")
end

struct DecisionTreeExecutionStrategy{F, G} <: CatComparisonExecutionStrategy
    item_bank::AbstractItemBank
    max_depth::UInt
    before_next_item::F
    after_next_item::G
end

function DecisionTreeExecutionStrategy(
    item_bank,
    max_depth,
    before_next_item=(measurement; kwargs...) -> nothing,
    after_next_item=(measurement; kwargs...) -> nothing
)
    return DecisionTreeExecutionStrategy(item_bank, max_depth, before_next_item, after_next_item)
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
    for ability_tracker in tracked_responses.ability_trackers
        track!(tracked_responses, ability_tracker)
    end
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
        next_item = nothing
        for (responses, config) in zip(
            iter_tracked_responses(multi_tracked_reponses), configs)
            if hasfield(config, :ability_tracker)
                track!(responses, config.ability_tracker)
            end
            measure_all(config, :before_next_item, strategy.before_next_item; responses = responses)
            timed_next_item = @timed config.next_item(responses, strategy.item_bank)
            next_item = timed_next_item.value
            measure_all(config, :after_next_item, strategy.after_next_item;
                responses = responses, next_item = next_item)
        end

        if state_tree.cur_depth == state_tree.max_depth
            # Final ability estimates
            for resp in (false, true)
                for (responses, config) in zip(
                    iter_tracked_responses(multi_tracked_reponses), configs)
                    add_response!(
                        responses, Response(ResponseType(strategy.item_bank), next_item, resp))
                    # TODO: figure out what we're doing here
                    #=measure_all(
                        config, :final_ability, final_ability; responses = responses)=#
                    pop_response!(responses)
                end
            end
        end

        ability = 0 # TODO...
        if next!(state_tree, multi_tracked_reponses, strategy.item_bank, next_item, ability)
            break
        end
    end
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
