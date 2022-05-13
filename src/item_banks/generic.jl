abstract type LikelihoodFunction end

using ..MathTraits
using ..Integrators

struct ItemResponse{ItemBankT <: AbstractItemBank, IntT <: Integer} <: LikelihoodFunction 
    item_bank::ItemBankT
    index::IntT
end

function log_response(ir::ItemResponse, θ)
    log(ir(θ))
end

struct AbilityLikelihood{ItemBankT} <: LikelihoodFunction where {ItemBankT <: AbstractItemBank}
    item_bank::ItemBankT
    responses::BareResponses
end

DomainType(lhf::Union{ItemResponse, AbilityLikelihood}) = DomainType(lhf.item_bank)

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
        pick_outcome(
            ItemResponse(
                ability_lh.item_bank,
                ability_lh.responses.indices[resp_idx]
            )(θ),
            ability_lh.responses.values[resp_idx] > 0
        )
        for resp_idx in axes(ability_lh.responses.indices, 1);
        init=1.0
    )
    #exp(log_response(ContinuousDomain(), ability_lh, θ))
end

function log_likelihood(ability_lh::AbilityLikelihood, θ)
    log_likelihood(DomainType(ability_lh), θ)
end

function log_likelihood(::ContinuousDomain, ability_lh::AbilityLikelihood, θ)
    # TODO: Might have to do log-sum-exp trick here
    sum(
        pick_outcome(
            log_response(
                ItemResponse(
                    ability_lh.item_bank,
                    ability_lh.responses.indices[resp_idx]
                ),
                θ
            ),
            ability_lh.responses.values[resp_idx] > 0
        )
        for resp_idx in axes(ability_lh.responses.indices, 1)
    )
end

function item_information(ir::ItemResponse, θ)
    # TODO: Which response models is this valid for?
    irθ_prime = ForwardDiff.derivative(ir, θ)
    irθ = ir(θ)
    (irθ_prime * irθ_prime) / (irθ * (1 - irθ))
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
        mass = integrator(ir; lo=lim_lower, hi=pivot)
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
        if integrator(ir; lo=integrator.lo, hi=lo) > tol1
            lo = _search(integrator, ir, integrator.lo, lo, tol1, eff_precis; denom=denom)
        end
        inv_denom = integrator.hi - integrator.lo - denom
        # XXX
        if integrator(inv_ir; lo=-integrator.hi, hi=hi) > tol1
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