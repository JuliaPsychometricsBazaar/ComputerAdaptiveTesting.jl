"""
This module implements the next item selection rules, which form the main part
of CAT.

## Bibliography

[1] Linden, W. J., & Pashley, P. J. (2009). Item selection and ability
estimation in adaptive testing. In Elements of adaptive testing (pp. 3-30).
Springer, New York, NY.
"""
module NextItemRules

using Accessors
using Reexport
using PsychometricsBazaarBase.Parameters
using LinearAlgebra
using Random

using ..Responses: Response, BareResponses
using ..ConfigBase
using PsychometricsBazaarBase.ConfigTools
using PsychometricsBazaarBase.Integrators: Integrator
using PsychometricsBazaarBase: Integrators
import PsychometricsBazaarBase.IntegralCoeffs
using FittedItemBanks
using FittedItemBanks: item_params
using ..Aggregators

using QuadGK, Distributions, Optim, Base.Threads, Base.Order, FLoops, StaticArrays
import ForwardDiff

export ExpectationBasedItemCriterion, AbilityVarianceStateCriterion, init_thread
export NextItemRule, ItemStrategyNextItemRule
export UrryItemCriterion, InformationItemCriterion, DRuleItemCriterion, TRuleItemCriterion
export RandomNextItemRule
export catr_next_item_aliases

abstract type NextItemRule <: CatConfigBase end

function NextItemRule(bits...; ability_estimator=nothing, parallel=true)
    @returnsome find1_instance(NextItemRule, bits)
    @returnsome ItemStrategyNextItemRule(bits..., ability_estimator=ability_estimator, parallel=parallel)
end

include("./random.jl")
include("./information.jl")
include("./objective_function.jl")

const default_prior = IntegralCoeffs.Prior(Cauchy(5, 2))

function preallocate(objective::ItemCriterion)::ItemCriterion
    # TODO: Is it possible to generate this as a generate/specialised function
    # depending on the particular ItemCriterion?
    preallocatables = IdDict()
    walk(objective) do item, lens
        if isa(item, Integrator)
            if !haskey(preallocatables, item)
                preallocatables[item] = []
            end
            push!(preallocatables[item], lens)
        end
    end
    for (preallocatable, lenses) in preallocatables
        preallocated = Integrators.preallocate(preallocatable)
        for lens in lenses
            objective = set(objective, lens, preallocated)
        end
    end
    return objective
end

function choose_item_1ply(
    objective::ItemCriterionT,
    responses::TrackedResponseT,
    items::AbstractItemBank
)::Tuple{Int, Float64} where {ItemCriterionT <: ItemCriterion, TrackedResponseT <: TrackedResponses}
    #pre_next_item(expectation_tracker, items)
    objective_state = init_thread(objective, responses)
    min_obj_idx::Int = -1
    min_obj_val::Float64 = Inf
    for item_idx in eachindex(items)
        # TODO: Add these back in
        #@init irf_states_storage = zeros(Int, length(responses) + 1)
        if (findfirst(idx -> idx == item_idx, responses.responses.indices) !== nothing)
            continue
        end

        obj_val = objective(objective_state, responses, item_idx)

        if obj_val < min_obj_val
            min_obj_val = obj_val
            min_obj_idx = item_idx
        end
    end
    (min_obj_idx, min_obj_val)
end

function init_thread(::ItemCriterion, ::TrackedResponses)
    nothing
end

abstract type NextItemStrategy <: CatConfigBase end

function NextItemStrategy(; parallel=true)
    ExhaustiveSearch1Ply(parallel)
end

function NextItemStrategy(bits...; parallel=true)
    @returnsome find1_instance(NextItemStrategy, bits)
    @returnsome find1_type(NextItemStrategy, bits) typ -> typ(; parallel=parallel)
    @returnsome NextItemStrategy(; parallel=parallel)
end

@with_kw struct ExhaustiveSearch1Ply <: NextItemStrategy
    parallel::Bool
end

struct ItemStrategyNextItemRule{NextItemStrategyT <: NextItemStrategy, ItemCriterionT <: ItemCriterion} <: NextItemRule
    strategy::NextItemStrategyT 
    criterion::ItemCriterionT
end

function ItemStrategyNextItemRule(bits...; parallel=true, ability_estimator=nothing)
    strategy = NextItemStrategy(bits...; parallel=parallel)
    criterion = ItemCriterion(bits...; ability_estimator=ability_estimator)
    if strategy !== nothing && criterion !== nothing
        return ItemStrategyNextItemRule(strategy, criterion)
    end
end

function (rule::ItemStrategyNextItemRule{ExhaustiveSearch1Ply, ItemCriterionT})(responses, items) where {ItemCriterionT <: ItemCriterion}
    #, rule.strategy.parallel
    criterion = preallocate(rule.criterion)
    choose_item_1ply(criterion, responses, items)[1]
end

function (item_criterion::ItemCriterion)(::Nothing, tracked_responses, item_idx)
    item_criterion(tracked_responses, item_idx)
end

function (item_criterion::ItemCriterion)(tracked_responses, item_idx)
    criterion_state = init_thread(item_criterion, tracked_responses)
    if criterion_state === nothing
        error("Tried to run an state-requiring item criterion $(typeof(item_criterion)), but init_thread(...) returned nothing")
    end
    item_criterion(criterion_state, tracked_responses, item_idx)
end

include("./aliases.jl")

end
