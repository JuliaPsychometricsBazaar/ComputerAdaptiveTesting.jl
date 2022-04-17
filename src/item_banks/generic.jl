abstract type LikelihoodFunction end

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