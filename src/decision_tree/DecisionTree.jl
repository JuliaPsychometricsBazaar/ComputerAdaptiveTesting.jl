module DecisionTree

using Mmap: mmap

using ComputerAdaptiveTesting.ConfigBase: CatConfigBase
using ComputerAdaptiveTesting.PushVectors
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.Responses: BareResponses, Response, add_response!, pop_response!
using FittedItemBanks: AbstractItemBank, BooleanResponse, ResponseType

# TODO: Remove ability tracking from here?
Base.@kwdef struct AgendaItem
    depth::UInt32
    ability::Float64
end

Base.@kwdef mutable struct TreePosition
    max_depth::UInt
    cur_depth::UInt
    todo::PushVector{AgendaItem, Vector{AgendaItem}}
    parent_ability::Float64
end

function TreePosition(max_depth)
    TreePosition(max_depth = max_depth,
        cur_depth = 0,
        todo = PushVector{AgendaItem}(max_depth),
        parent_ability = 0.0)
end

function next!(state::TreePosition, responses, item_bank, question, ability)
    # Try to go deeper
    if state.cur_depth < state.max_depth
        state.parent_ability = ability
        state.cur_depth += 1
        push!(state.todo, AgendaItem(depth = state.cur_depth, ability = ability))
        add_response!(responses, Response(ResponseType(item_bank), question, false))
    else
        # Try to back track
        if !isempty(state.todo)
            todo = pop!(state.todo)
            state.parent_ability = todo.ability
            state.cur_depth = todo.depth
            while length(responses) > state.cur_depth
                pop_response!(responses)
            end
            question = responses.responses.indices[end]
            pop_response!(responses)
            add_response!(responses, Response(ResponseType(item_bank), question, true))
        else
            # Done: break
            return true
        end
    end
    return false
end

Base.@kwdef struct MaterializedDecisionTree{QT <: AbstractVector, AT <: AbstractVector}
    questions::QT # e.g. Vector{UInt32}
    ability_estimates::AT # e.g. Vector{Float64}
end

const DefaultMaterializedDecisionTree = MaterializedDecisionTree{
    Vector{UInt32},
    Vector{Float64}
}

function tree_size(max_depth)
    2^(max_depth + 1) - 1
end

function max_depth(tree_size)
    floor(Int, log2(tree_size + 1)) - 1
end

function MaterializedDecisionTree(max_depth)
    MaterializedDecisionTree(questions = Vector{UInt32}(undef, tree_size(max_depth)),
        ability_estimates = Vector{Float64}(undef, tree_size(max_depth + 1)))
end

function responses_idx(responses)
    (length(responses.indices) > 0 ? evalpoly(2, responses.values) : 0) +
    2^length(responses.indices)
end

function Base.insert!(dt::MaterializedDecisionTree, responses, ability, next_item)
    idx = responses_idx(responses)
    dt.questions[idx] = next_item
    dt.ability_estimates[idx] = ability
end

function Base.insert!(dt::MaterializedDecisionTree, responses, ability)
    idx = responses_idx(responses)
    dt.ability_estimates[idx] = ability
end

Base.@kwdef struct DecisionTreeGenerationConfig{
    NextItemRuleT <: NextItemRule,
    AbilityEstimatorT <: AbilityEstimator,
    AbilityTrackerT <: AbilityTracker
} <: CatConfigBase
    """
    The maximum depth of the decision tree
    """
    max_depth::UInt
    """
    The rule to choose the next item in the CAT given the current state.
    """
    next_item::NextItemRuleT
    """
    The ability estimator, which estimates the testee's current ability.
    """
    ability_estimator::AbilityEstimatorT
    """
    The ability tracker, which tracks the testee's current ability level.
    """
    ability_tracker::AbilityTrackerT = NullAbilityTracker()
end

function generate_dt_cat(config::DecisionTreeGenerationConfig, item_bank)
    state_tree = TreePosition(config.max_depth)
    decision_tree_result = MaterializedDecisionTree(config.max_depth)
    responses = TrackedResponses(BareResponses(ResponseType(item_bank)),
        item_bank,
        config.ability_tracker)
    while true
        track!(responses, config.ability_tracker)
        ability = config.ability_estimator(responses)
        next_item = best_item(config.next_item, responses, item_bank)

        insert!(decision_tree_result, responses.responses, ability, next_item)
        if state_tree.cur_depth == state_tree.max_depth
            # Final ability estimates
            for resp in (false, true)
                add_response!(responses, Response(ResponseType(item_bank), next_item, resp))
                ability = config.ability_estimator(responses)
                insert!(decision_tree_result, responses.responses, ability)
                pop_response!(responses)
            end
        end

        if next!(state_tree, responses, item_bank, next_item, ability)
            break
        end
    end
    decision_tree_result
end

function next_item(dt::MaterializedDecisionTree, responses::BareResponses)
    return dt.questions[responses_idx(responses)]
end

function termination_condition(dt::MaterializedDecisionTree, responses::BareResponses)
    return length(responses.indices) >= max_depth(length(dt.ability_estimates))
end

function ability_estimate(dt::MaterializedDecisionTree, responses::BareResponses)
    return dt.ability_estimates[responses_idx(responses)]
end

include("./mmap.jl")
include("./sim.jl")

export generate_dt_cat,
       MaterializedDecisionTree, DecisionTreeGenerationConfig, next_item, ability_estimate
export save_mmap, load_mmap

end
