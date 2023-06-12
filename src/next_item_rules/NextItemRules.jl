"""
This module implements the next item selection rules, which form the main part
of CAT.

## Bibliography

[1] Linden, W. J., & Pashley, P. J. (2009). Item selection and ability
estimation in adaptive testing. In Elements of adaptive testing (pp. 3-30).
Springer, New York, NY.
"""
module NextItemRules

using Reexport
using ComputerAdaptiveTesting.Parameters
using LinearAlgebra

using ..Responses: Response, BareResponses
using ..ConfigBase
using PsychometricsBazaarBase.ConfigTools
import PsychometricsBazaarBase.IntegralCoeffs
using FittedItemBanks
using FittedItemBanks: item_params
using ..Aggregators

using QuadGK, Distributions, Optim, Base.Threads, Base.Order, FLoops, StaticArrays
import ForwardDiff

export ExpectationBasedItemCriterion, AbilityVarianceStateCriterion, init_thread
export NextItemRule, ItemStrategyNextItemRule
export UrryItemCriterion, InformationItemCriterion, DRuleItemCriterion, TRuleItemCriterion
export catr_next_item_aliases

include("./information.jl")
include("./objective_function.jl")

abstract type NextItemRule <: CatConfigBase end

function NextItemRule(bits...; ability_estimator=nothing, parallel=true)
    @returnsome find1_instance(NextItemRule, bits)
    @returnsome ItemStrategyNextItemRule(bits..., ability_estimator=ability_estimator, parallel=parallel)
end

const default_prior = IntegralCoeffs.Prior(Cauchy(5, 2))

#=

function lh_abil_given_resps(responses::AbstractVector{Response}, items::AbstractItemBank, θ)
    prod((resp -> pick_outcome(irf(items, resp.index, θ), resp.value)), responses; init=1.0)
end

function int_lh_g_abil_given_resps{F}(f::F, responses::AbstractVector{Response}, items::AbstractItemBank; lo=0.0, hi=10.0, irf_states_storage=nothing)::Float64 where {F}
    int_lh_abil_given_resps(IntegralCoeffs.PriorApply(default_prior, f), responses, items; lo=lo, hi=hi, irf_states_storage=irf_states_storage)
end

function max_lh_g_abil_given_resps{F}(f::F, responses::AbstractVector{Response}, items::AbstractItemBank; lo=0.0, hi=10.0) where {F}
    max_lh_abil_given_resps(IntegralCoeffs.PriorApply(default_prior, f), responses, items; lo=lo, hi=hi)
end

"""
Unnormalised version of equation (1.8) from [1]
"""
function g_abil_given_resps(responses::AbstractVector{Response}, items::AbstractItemBank, θ)
    IntegralCoeffs.PriorApply(default_prior, θ -> lh_abil_given_resps(responses, items, θ))
end
=#

#=
function var_abil(responses::AbstractVector{Response}, items::AbstractItemBank; mean::Union{Float64, Nothing}=nothing, denom::Union{Float64, Nothing}=nothing, irf_states_storage=nothing)::Float64
    # XXX: Profiling suggests many allocations here but not sure why
    # OTT type annotations are mainly a workaround for https://github.com/JuliaLang/julia/issues/15276
    if denom === nothing
        final_denom::Float64 = int_abil_posterior_given_resps(one, responses, items; irf_states_storage=irf_states_storage)
    else
        final_denom = denom::Float64
    end
    if mean === nothing
        final_mean::Float64 = mean_θ(responses, items; denom = final_denom, irf_states_storage=irf_states_storage)
    else
        final_mean = mean::Float64
    end
    int_abil_posterior_given_resps(SqDev(final_mean), responses, items; irf_states_storage=irf_states_storage) / final_denom
end

function mode_abil(responses::AbstractVector{Response}, items::AbstractItemBank)::Float64
    max_abil_posterior_given_resps(IntegralCoeffs.one, responses, items)
end

function mean_abil(responses::AbstractVector{Response}, items::AbstractItemBank; denom::Union{Float64, Nothing}=nothing, irf_states_storage=nothing)::Float64
    if denom === nothing
        final_denom::Float64 = int_abil_posterior_given_resps(IntegralCoeffs.one, responses, items, irf_states_storage=irf_states_storage)
    else
        final_denom = denom::Float64
    end
    int_abil_posterior_given_resps(IntegralCoeffs.id, responses, items, irf_states_storage=irf_states_storage) / final_denom
end

function expected_variance!(responses::AbstractVector{Response}, items::AbstractItemBank, item_idx::Int, exp_resp::Float64; irf_states_storage=nothing)::Float64
    responses[end] = Response(item_idx, 0)
    neg_var = var_abil(responses, items; irf_states_storage=irf_states_storage)
    responses[end] = Response(item_idx, 1)
    pos_var = var_abil(responses, items; irf_states_storage=irf_states_storage)
    pick_outcome(exp_resp, false) * neg_var + pick_outcome(exp_resp, true) * pos_var
end

function expected_variance(responses::AbstractVector{Response}, items::AbstractItemBank, item_idx::Int, exp_resp::Float64; irf_states_storage=nothing)::Float64
    expected_variance!([responses; Response(0, 0)], items, item_idx, exp_resp; irf_states_storage=irf_states_storage)
end

function expected_variance_one(responses::AbstractVector{Response}, items::AbstractItemBank, item_idx::Int; irf_states_storage=nothing)::Float64
    # TODO: Marginalise over θ here
    θ_mean = mean_θ(responses, items; irf_states_storage=irf_states_storage)
    exp_resp = irf(items, item_idx, θ_mean)
    expected_variance!([responses; Response(0, 0)], items, item_idx, exp_resp; irf_states_storage=irf_states_storage)
end
=#

#=
function (obj_func::ObjectiveFunction)()
    purity
end
=#

#function init_thread(_::ItemCriterion, expected_num_responses)
    #nothing
#end
#[responses; Response(0, 0)]

#ability_estimator::AbilityEstimatorT, AbilityEstimatorT, 
function choose_item_1ply(
    objective::ItemCriterion,
    responses::TrackedResponses,
    items::AbstractItemBank,
    parallel=true
)
    #pre_next_item(expectation_tracker, items)
    if parallel
        ex = ThreadedEx()
    else
        ex = SequentialEx()
    end
    @floop ex for item_idx in eachindex(items)
        # TODO: Add these back in
        @init objective_state = init_thread(objective, responses)
        #@init irf_states_storage = zeros(Int, length(responses) + 1)
        if (findfirst(idx -> idx == item_idx, responses.responses.indices) !== nothing)
            continue
        end

        #=
        exp_resp = response_expectation(
            ability_estimator,
            responses,
            item_idx
        )
        var = expected_variance!(working_responses, items, item_idx, exp_resp, irf_states_storage=irf_states_storage)
        =#
        obj_val = objective(objective_state, responses, item_idx)
        
        @reduce() do (min_obj_idx = -1; item_idx), (min_obj_val = Inf; obj_val)
            if obj_val < min_obj_val
                min_obj_val = obj_val
                min_obj_idx = item_idx
            end
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
    choose_item_1ply(rule.criterion, responses, items, rule.strategy.parallel)[1]
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

#=
struct MinExpectedVariance{} <: NextItemRule end
ConfigPurity(::MinExpectedVariance) = ImpureConfig

function (ability_estimator::MinExpectedVariance{<:AbilityEstimator})(responses::TrackedResponses, items::AbstractItemBank)
    min_expected_variance(ability_estimator, responses, items)[1]
end
=#

#=
struct SimpleFunctionNextItemRule{} <: NextItemRule end
ConfigPurity(::MinExpectedVariance) = PureConfig

struct FunctionFactoryNextItemRule{} <: NextItemRule end
ConfigPurity(::MinExpectedVariance) = ImpureConfig
=#

"""
This mapping provides next item rules through the same names that they are
available through in the `catR` R package. TODO compability with `mirtcat`
"""
const catr_next_item_aliases = Dict(
    "MFI" => (ability_estimator; parallel=true) -> ItemStrategyNextItemRule(ExhaustiveSearch1Ply(parallel), InformationItemCriterion(ability_estimator)),
    "bOpt" => (ability_estimator; parallel=true) -> ItemStrategyNextItemRule(ExhaustiveSearch1Ply(parallel), UrryItemCriterion(ability_estimator)),
    #"thOpt",
    #"MLWI",
    #"MPWI",
    #"MEI",
    "MEPV" => (ability_estimator; parallel=true) -> ItemStrategyNextItemRule(ExhaustiveSearch1Ply(parallel), ExpectationBasedItemCriterion(ability_estimator, AbilityVarianceStateCriterion())),
    #"progressive",
    #"proportional",
    #"KL",
    #"KLP",
    #"GDI",
    #"GDIP",
    #"random"
)

end
