abstract type LikelihoodFunction end

using ..Integrators

struct ItemResponse{ItemBankT <: AbstractItemBank}
    item_bank::ItemBankT
    index::Int
end

function responses(ir::ItemResponse)
    responses(ResponseType(ir), ir)
end

function responses(::BooleanResponse, ir::ItemResponse)
    SVector(false, true)
end

function responses(::MultinomialResponse, ir::ItemResponse)
    1:num_response_categories(ir)
end

#=
struct ItemResponse{ItemBankT <: AbstractItemBank} <: ItemResponse
    item_handle::ItemResponse{ItemBankT}
    response::response_type(ResponseType(ItemBankT))
end
=#

function p_lt(ir::ItemResponse, θ)
    1 - p_gte(ir, θ)
end

function logp_gte(ir::ItemResponse, θ)
    log(p_gte(ir, θ))
end

function logp_lt(ir::ItemResponse, θ)
    log(p_lt(ir, θ))
end

#=
# These defaults (cresp,logresp,logcresp) could have poor numerical stability.
# Should possibly issue a warning when used to poke for more stable ones from
# the item bank type
function cresp(ir::ItemResponse, θ)
    #@info "cresp" ir θ
    1 - resp(ir, θ)
end

function logresp(ir::ItemResponse, θ)
    log(resp(ir, θ))
end

function logcresp(ir::ItemResponse, θ)
    log(cresp(ir, θ))
end
=#

struct AbilityLikelihood{ItemBankT} <: LikelihoodFunction where {ItemBankT <: AbstractItemBank}
    item_bank::ItemBankT
    responses::BareResponses
end

MathTraits.DomainType(lhf::AbilityLikelihood) = DomainType(lhf.item_bank)
Responses.ResponseType(lhf::AbilityLikelihood) = ResponseType(lhf.item_bank)
MathTraits.DomainType(lhf::ItemResponse) = DomainType(lhf.item_bank)
Responses.ResponseType(lhf::ItemResponse) = ResponseType(lhf.item_bank)

function (ability_lh::LikelihoodFunction)(θ)
    ability_lh(DomainType(ability_lh), θ)
end

#=
function (ability_lh::LikelihoodFunction)(::DiscreteDomain, θ)
    error(
        "Tried to get continuous value of discrete domain function "
        * typeof(ability_lh)
    )
end
=#

function (ability_lh::AbilityLikelihood)(::ContinuousDomain, θ)
    prod(
        resp(
            ItemResponse(
                ability_lh.item_bank,
                ability_lh.responses.indices[resp_idx]
            ),
            ability_lh.responses.values[resp_idx],
            θ
        )
        for resp_idx in axes(ability_lh.responses.indices, 1);
        init=1.0
    )
    #exp(logresp(OneDimContinuousDomain(), ability_lh, θ))
end

function log_likelihood(ability_lh::AbilityLikelihood, θ)
    log_likelihood(DomainType(ability_lh), θ)
end

function log_likelihood(::ContinuousDomain, ability_lh::AbilityLikelihood, θ)
    # TODO: Might have to do log-sum-exp trick here
    sum(
        pick_logresp(ability_lh.responses.values[resp_idx] > 0)(
            ItemResponse(
                ability_lh.item_bank,
                ability_lh.responses.indices[resp_idx]
            ),
            θ,
        )
        for resp_idx in axes(ability_lh.responses.indices, 1)
    )
end

# How does this compare with expected_item_information. Speeds/accuracies?
# TODO: Which response models is this valid for?
# TODO: Citation/source for this equation
# TODO: Do it in log space?
function item_information(ir::ItemResponse, θ)
    irθ_prime = ForwardDiff.derivative(ir, θ)
    irθ = ir(θ)
    if irθ_prime == 0.0
        return 0.0
    else
        return (irθ_prime * irθ_prime) / (irθ * (1 - irθ))
    end
end

# TODO: Unclear whether this should be implemented with ExpectationBasedItemCriterion
function expected_item_information(ir::ItemResponse, θ::Vector{Float64})
    exp_resp = ir(θ)
    corr_hess = ForwardDiff.hessian(θ -> logresp(ir, θ), θ)
    incorr_hess = ForwardDiff.hessian(θ -> logcresp(ir, θ), θ)
    -(exp_resp .* corr_hess + (1.0 - exp_resp) .* incorr_hess)
end

function known_item_information(ir::ItemResponse, resp_value, θ)
    -ForwardDiff.hessian(θ -> pick_logresp(resp_value)(ir, θ), θ)
end

function responses_information(item_bank::AbstractItemBank, responses::BareResponses, θ)
    d = ndims(item_bank)
    reduce(
        .+,
        (
            known_item_information(ItemResponse(item_bank, resp_idx), resp_value > 0, θ)
            for (resp_idx, resp_value)
            in zip(responses.indices, responses.values)
        ); init=zeros(d, d)
    )
end

#=
function (ability_lh::AbilityLikelihood)(::DiscreteDomain, θ_idx::Int)
    error("Not implemented")
end

function (ability_lh::LikelihoodFunction)(::ContinuousDomain, θ_idx::Int)
    error(
        "Tried to get discrete value of continuous domain function "
        * typeof(ability_lh)
    )
end
=#

function item_idxs(item_bank::AbstractItemBank)
    Base.OneTo(length(item_bank))
end

function labels(item_bank::AbstractItemBank)
    item_bank.labels
end

@inline function pick_outcome(p::Float64, outcome::Bool)
    outcome ? p : 1.0 - p
end

@inline function pick_resp(outcome)
    outcome ? resp : cresp
end

@inline function pick_logresp(outcome)
    outcome ? logresp : logcresp
end

"""
Binary search for the point x where the integral from -inf...x is target += precis
"""
function _search(
    integrator::Integrator,
    ir::F,
    lim_lower,
    lim_upper,
    target,
    precis;
    max_iters=50,
    denom=normdenom(integrator)
) where {F}
    lower = lim_lower
    upper = lim_upper
    @info "max_iters" max_iters
    for _ in 1:max_iters
        pivot = lower + (upper - lower) / 2
        @info "limits" lo=lim_lower hi=pivot
        mass = intval(integrator(ir; lo=lim_lower, hi=pivot))
        ratio = mass / denom
        @info "mass" mass denom ratio target precis
        if target - precis <= ratio <= target
            return pivot
        elseif ratio < target
            lower = pivot
        else
            upper = pivot
        end
    end
    error("Could not find point after $max_iters iterations")
end

function item_bank_domain(
    integrator::Integrator,
    item_bank::AbstractItemBank;
    tol=1e-3,
    precis=1e-2,
    zero_symmetric=false
)
    tol1 = tol / 2.0
    eff_precis = tol1 * precis
    if length(item_bank) == 0
        (integrator.lo, integrator.hi)
    end
    lo = integrator.hi
    hi = integrator.lo
    for item_idx in item_idxs(item_bank)
        ir = ItemResponse(item_bank, item_idx)
        # XXX: denom should be the denom of the item response
        denom = normdenom(integrator)
        inv_ir(x) = 1.0 - ir(-x)
        if intval(integrator(ir; lo=integrator.lo, hi=lo)) > tol1
            lo = _search(integrator, ir, integrator.lo, lo, tol1, eff_precis; denom=denom)
        end
        inv_denom = integrator.hi - integrator.lo - denom
        # XXX
        if intval(integrator(inv_ir; lo=-integrator.hi, hi=hi)) > tol1
            hi = -_search(integrator, inv_ir, -integrator.hi, -hi, tol1, eff_precis; denom=inv_denom)
        end
    end
    if zero_symmetric
        dist = max(abs(lo), abs(hi))
        (-dist, dist)
    else
        (lo, hi)
    end
end