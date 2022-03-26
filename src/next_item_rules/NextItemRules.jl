"""
This module implements the next item selection rules, which form the main part
of CAT.

## Bibliography

[1] Linden, W. J., & Pashley, P. J. (2009). Item selection and ability
estimation in adaptive testing. In Elements of adaptive testing (pp. 3-30).
Springer, New York, NY.
"""
module NextItemRules

using Reexport, FromFile

@from "../Responses.jl" using Responses: Response
@from "../ConfigBase.jl" using ConfigBase: CatConfigBase
@from "../maths/IntegralCoeffs.jl" import IntegralCoeffs
@from "../item_banks/ItemBanks.jl" using ItemBanks: AbstractItemBank
@from "../aggregators/Aggregators.jl" using Aggregators: AbilityEstimator, TrackedResponses, AbilityTracker

include("./objective_function.jl")

using QuadGK, Distributions, Optim, Base.Threads, Base.Order, ResumableFunctions, FLoops

abstract type NextItemRule <: CatConfigBase end

const OPTIM_TOL = 1e-12
const INT_TOL = 1e-8
const DEFAULT_PRIOR = IntegralCoeffs.Prior(Cauchy(5, 2))

@inline function pick_outcome(p::Float64, outcome::Bool)::Float64
    outcome ? p : 1.0 - p
end

#=

function lh_abil_given_resps(responses::AbstractVector{Response}, items::AbstractItemBank, θ::Float64)
    prod((resp -> pick_outcome(irf(items, resp.index, θ), resp.value)), responses; init=1.0)
end

function int_lh_g_abil_given_resps{F}(f::F, responses::AbstractVector{Response}, items::AbstractItemBank; lo=0.0, hi=10.0, irf_states_storage=nothing)::Float64 where {F}
    int_lh_abil_given_resps(IntegralCoeffs.PriorApply(DEFAULT_PRIOR, f), responses, items; lo=lo, hi=hi, irf_states_storage=irf_states_storage)
end

function max_lh_g_abil_given_resps{F}(f::F, responses::AbstractVector{Response}, items::AbstractItemBank; lo=0.0, hi=10.0) where {F}
    max_lh_abil_given_resps(IntegralCoeffs.PriorApply(DEFAULT_PRIOR, f), responses, items; lo=lo, hi=hi)
end

"""
Unnormalised version of equation (1.8) from [1]
"""
function g_abil_given_resps(responses::AbstractVector{Response}, items::AbstractItemBank, θ::Float64)
    IntegralCoeffs.PriorApply(DEFAULT_PRIOR, θ -> lh_abil_given_resps(responses, items, θ))
end
=#

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

#=
function (obj_func::ObjectiveFunction)()
    purity
end
=#

function init_thread(_::ItemCriterion, expected_num_responses)
    nothing
end
#[responses; Response(0, 0)]

#ability_estimator::AbilityEstimatorT, AbilityEstimatorT, 
function choose_item_1ply(
    objective::ItemCriterionT,
    responses,::TrackedResponses{ItemBankT, AbilityTrackerT, AbilityEstimatorT},
    items::AbstractItemBank
) where {ItemBankT <: AbstractItemBank, AbilityTrackerT <: AbilityTracker, AbilityEstimatorT <: AbilityEstimator, ItemCriterionT <: ItemCriterion}
    #pre_next_item(expectation_tracker, items)
    @floop for item_idx in iter_item_idxs(items)
        # TODO: Add these back in
        #@init item_criterion_thread_state = init_thread(item_criterion)
        #@init irf_states_storage = zeros(Int, length(responses) + 1)
        if (findfirst(resp -> resp.index == item_idx, responses) !== nothing)
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
        obj_val = objective(responses, item_idx)
        
        @reduce() do (min_obj_idx = -1; item_idx), (min_obj_val = Inf; obj_val)
            if obj_val < min_obj_val
                min_obj_val = obj_val
                min_obj_idx = item_idx
            end
        end
    end
    (min_obj_idx, min_obj_val)
end

abstract type NextItemStrategy <: CatConfigBase end

struct ExhaustiveSearch1Ply <: NextItemStrategy end

struct ItemStrategyNextItemRule{NextItemStrategyT <: NextItemStrategy, ItemCriterionT <: ItemCriterion} <: NextItemRule
    strategy::NextItemStrategyT 
    criterion::ItemCriterionT
end

function (rule::ItemStrategyNextItemRule{ExhaustiveSearch1Ply, ItemCriterion})(
    responses,::TrackedResponses{ItemBankT, AbilityTrackerT, AbilityEstimatorT},
    items::AbstractItemBank
) where {ItemBankT <: AbstractItemBank, AbilityTrackerT <: AbilityTracker, AbilityEstimatorT <: AbilityEstimator, ItemCriterionT <: ItemCriterion}
    choose_item_1ply(rule.criterion, responses, items)
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
available through in the `mirt` R package.
"""
NEXT_ITEM_ALIASES = Dict(
    #"MFI",
    #"bOpt",
    #"thOpt",
    #"MLWI",
    #"MPWI",
    #"MEI",
    "MEPV" => ability_estimator -> ItemStrategyNextItemRule(ExhaustiveSearch1Ply(), ExpectationBasedItemCriterion(ability_estimator, AbilityVarianceStateCriterion())),
    #"progressive",
    #"proportional",
    #"KL",
    #"KLP",
    #"GDI",
    #"GDIP",
    #"random"
)

end