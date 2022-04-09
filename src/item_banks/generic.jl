abstract type LikelihoodFunction end

using ..Integrators: ContinuousDomain, DiscreteDomain, DomainType

struct ItemResponse{ItemBankT <: AbstractItemBank, IntT <: Integer} <: LikelihoodFunction 
    item_bank::ItemBankT
    index::IntT
end

function log_response(ir::ItemResponse, θ::Float64)::Float64
    log(ir(θ))
end

struct AbilityLikelihood{ItemBankT} <: LikelihoodFunction where {ItemBankT <: AbstractItemBank}
    item_bank::ItemBankT
    responses::BareResponses
end

DomainType(lhf::Union{ItemResponse, AbilityLikelihood}) = DomainType(typeof(lhf.item_bank))

function (ability_lh::LikelihoodFunction)(θ)::Float64
    ability_lh(DomainType(ability_lh), θ)
end

#=
function (ability_lh::LikelihoodFunction)(::DiscreteDomain, θ::Float64)::Float64
    error(
        "Tried to get continuous value of discrete domain function "
        * typeof(ability_lh)
    )
end
=#

function (ability_lh::AbilityLikelihood)(::ContinuousDomain, θ::Float64)::Float64
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

function log_response(::ContinuousDomain, ability_lh::AbilityLikelihood, θ::Float64)::Float64
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

#=
function (ability_lh::AbilityLikelihood)(::DiscreteDomain, θ_idx::Int)::Float64
    error("Not implemented")
end

function (ability_lh::LikelihoodFunction)(::ContinuousDomain, θ_idx::Int)::Float64
    error(
        "Tried to get discrete value of continuous domain function "
        * typeof(ability_lh)
    )
end
=#

function iter_item_idxs(item_bank::AbstractItemBank)
    Base.OneTo(length(item_bank))
end

function labels(item_bank::AbstractItemBank)
    item_bank.labels
end

@inline function pick_outcome(p::Float64, outcome::Bool)::Float64
    outcome ? p : 1.0 - p
end