module Comparison

# TODO: We are overlapping a bit with CatRecorder here
# Should be kept in mind and kept distinct or code reuse

using FittedItemBanks: AbstractItemBank, ResponseType, subset
using ..Responses
using ..Aggregators: TrackedResponses, Aggregators
using Base: Iterators

using EffectSizes: CohenD, effectsize
using HypothesisTests: ExactSignedRankTest, SignTest, UnequalVarianceTTest,
                       pvalue
using StatsBase: median, sample!

using DataFrames: DataFrame
using ComputerAdaptiveTesting: Stateful

export run_random_comparison, run_comparison
export CatComparisonExecutionStrategy, IncreaseItemBankSizeExecutionStrategy
#export FollowOneExecutionStrategy, RunIndependentlyExecutionStrategy
#export DecisionTreeExecutionStrategy
export ReplayResponsesExecutionStrategy
export CatComparisonConfig

include("./watchdog.jl")

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

struct CatComparisonConfig{StrategyT <: CatComparisonExecutionStrategy, PhasesT <: NamedTuple}
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
    The phases to run, optionally paired with a callback
    """
    phases::PhasesT
    """
    Where to sample for likelihood
    """
    sample_points::Union{Vector{Float64}, Nothing}
    """
    Skips
    """
    skip_callback
    """
    Watchdog timeout
    """
    timeout::Float64
end

"""
    CatComparisonConfig(;
        rules::NamedTuple{Symbol, StatefulCat},
        strategy::CatComparisonExecutionStrategy,
        phases::Union{NamedTuple{Symbol, Callable}, Tuple{Symbol}},
        skips::Set{Tuple{Symbol, Symbol}},
        callback::Callable
    ) -> CatComparisonConfig

CatComparisonConfig sets up a evaluation-oriented comparison between different CAT systems.

Specify the comparison by listing: CAT systems in `rules`, a `NamedTuple` which gives
identifiers to implementations of the `StatefulCat` interface; the `strategy` to use,
an implementation of `CatComparisonExecutionStrategy`; the `phases` to run listed as
either as a `NamedTuple` with names of phases and corresponding callbacks or `nothing` a
`Tuple` of phases to run; and a `callback` which will be used as a fallback in cases where
no callback is provided.

The exact phases depend on the strategy used. See their individual documentation for more.
"""
function CatComparisonConfig(; rules, strategy, phases = nothing, skip_callback = ((_, _, _) -> false), sample_points = nothing, callback = nothing, timeout = Inf)
    if callback === nothing
        callback = (info; kwargs...) -> nothing
    end
    if phases === nothing
        phases = (:before_next_item, :after_next_item)
    end
    if !(phases isa NamedTuple)
        phases = NamedTuple((phase => callback for phase in phases))
    end
    CatComparisonConfig(
        rules,
        strategy,
        phases,
        sample_points,
        skip_callback,
        timeout
    )
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
    if !(phase in keys(comparison.phases))
        return
    end
    callback = comparison.phases[phase]
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
    callback((;
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
    responses::Vector # XXX: Type
    starting_responses::Int
    shuffle::Bool
    time_limit::Float64

    function IncreaseItemBankSizeExecutionStrategy(item_bank, sizes, args...)
        if any((size > length(item_bank) for size in sizes))
            error("IncreaseItemBankSizeExecutionStrategy: No subset size can be greater than the number of items available in the item bank")
        end
        new(item_bank, sizes, args...)
    end
end

function IncreaseItemBankSizeExecutionStrategy(item_bank, sizes)
    return IncreaseItemBankSizeExecutionStrategy(item_bank, sizes, 0, false, Inf)
end

function init_cat(cat::Stateful.StatefulCat, item_bank)
    Stateful.set_item_bank!(cat, item_bank)
    cat
end

function init_cat(cat, item_bank)
    cat(item_bank)
end

function run_warmup(comparison::CatComparisonConfig{IncreaseItemBankSizeExecutionStrategy})
    strategy = comparison.strategy
    size = strategy.sizes[1]
    subsetted_item_bank = subset(strategy.item_bank, 1:size)
    for (name, mk_cat) in pairs(comparison.rules)
        warmup_time = @timed begin
            cat = init_cat(mk_cat, subsetted_item_bank)
            for idx in 1:(strategy.starting_responses)
                Stateful.add_response!(cat, idx, strategy.responses[idx])
            end
            Stateful.next_item(cat)
        end
        total_compile_time = warmup_time.compile_time + warmup_time.recompile_time
        compile_frac = total_compile_time / warmup_time.time
        if compile_frac > 0.01
            @warn "Compilation during warmup" name compile_frac warmup_time
        end
    end
end

function run_comparison(comparison::CatComparisonConfig{IncreaseItemBankSizeExecutionStrategy})
    strategy = comparison.strategy
    current_cats = collect(pairs(comparison.rules))
    next_current_cats = []
    @info "sizes" strategy.sizes
    for size in strategy.sizes
        subsetted_item_bank = subset(strategy.item_bank, 1:size)
        for (name, mk_cat) in current_cats
            init_time = @timed begin
                cat = init_cat(mk_cat, subsetted_item_bank)
            end
            response_add_time = @timed begin
                for idx in 1:(strategy.starting_responses)
                    Stateful.add_response!(cat, idx, strategy.responses[idx])
                end
            end
            @info "responses" Stateful.get_responses(cat)
            measure_all(
                comparison,
                name,
                cat,
                :before_next_item,
                init_time = init_time.time,
                response_add_time = response_add_time.time,
                num_items=size,
                system_name=name
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
                num_items=size,
                system_name=name
            )
            if timed_next_item.time < strategy.time_limit
                push!(next_current_cats, name => cat)
            end
        end
        if length(next_current_cats) == 0
            break
        end
        current_cats = next_current_cats
        next_current_cats = []
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
    time_limit::Float64
end

ReplayResponsesExecutionStrategy(responses) = ReplayResponsesExecutionStrategy(responses, Inf)

function should_run(comparison, name, cat, phase)
    return phase in keys(comparison.phases) &&
        !comparison.skip_callback(name, cat, phase)
end

# Which questions to ask: Specified
# Which answer to use: From response memory
function run_comparison(comparison::CatComparisonConfig{ReplayResponsesExecutionStrategy})
    strategy = comparison.strategy
    current_cats = Dict(pairs(comparison.rules))
    function check_time(name, timer)
        if timer.time >= strategy.time_limit
            if name in keys(current_cats)
                @info "Time limit exceeded" name timer.time
                delete!(current_cats, name)
            end
        end
    end
    watchdog = WatchdogTask(comparison.timeout)
    start!(watchdog) do
        for (items_answered, response) in zip(
            Iterators.countfrom(0), Iterators.flatten((strategy.responses, [nothing])))
            for (name, cat) in pairs(current_cats)
                println("")
                println("Starting $name for $items_answered")
                flush(stdout)
                if should_run(comparison, name, cat, :before_item_criteria)
                    reset!(watchdog, "$name item_criteria")
                    timed_item_criteria = @timed Stateful.item_criteria(cat)
                    check_time(name, timed_item_criteria)
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
                if should_run(comparison, name, cat, :before_ranked_items)
                    reset!(watchdog, "$name ranked_items")
                    timed_ranked_items = @timed Stateful.ranked_items(cat)
                    check_time(name, timed_ranked_items)
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
                if should_run(comparison, name, cat, :before_ability)
                    reset!(watchdog, "$name get_ability")
                    timed_get_ability = @timed Stateful.get_ability(cat)
                    check_time(name, timed_get_ability)
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
                reset!(watchdog, "$name next_item")
                timed_next_item = @timed Stateful.next_item(cat)
                check_time(name, timed_next_item)
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
                if should_run(comparison, name, cat, :after_item_criteria)
                    # TOOD: Combine with next_item if possible and requested?
                    reset!(watchdog, "$name item_criteria")
                    timed_item_criteria = @timed Stateful.item_criteria(cat)
                    check_time(name, timed_item_criteria)
                    if timed_item_criteria.value !== nothing
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
                end
                if should_run(comparison, name, cat, :after_ranked_items)
                    reset!(watchdog, "$name ranked_items")
                    timed_ranked_items = @timed Stateful.ranked_items(cat)
                    check_time(name, timed_ranked_items)
                    if timed_ranked_items.value !== nothing
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
                end
                if should_run(comparison, name, cat, :after_likelihood)
                    reset!(watchdog, "$name likelihood")
                    timed_likelihood = @timed Stateful.likelihood.(Ref(cat), comparison.sample_points)
                    check_time(name, timed_likelihood)
                    measure_all(
                        comparison,
                        name,
                        cat,
                        :after_likelihood,
                        items_answered = items_answered,
                        sample_points = comparison.sample_points,
                        likelihood = timed_likelihood.value,
                        timing = timed_likelihood
                    )

                end
                if should_run(comparison, name, cat, :after_ability)
                    reset!(watchdog, "$name get_ability")
                    timed_get_ability = @timed Stateful.get_ability(cat)
                    check_time(name, timed_get_ability)
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
