abstract type LikelihoodFunction end

using ..Integrators: ContinuousDomain, DiscreteDomain, DomainType

struct ItemResponse{ItemBankT <: AbstractItemBank, IntT <: Integer} <: LikelihoodFunction 
    item_bank::ItemBankT
    index::IntT
end

struct AbilityLikelihood{ItemBankT, ResponsesT} <: LikelihoodFunction where {ItemBankT <: AbstractItemBank, ResponsesT <: AbstractVector{<: Response}}
    item_bank::ItemBankT
    responses::ResponsesT
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
                ability_lh.responses.index
            )(θ),
            resp.value > 0
        )
        for resp in responses;
        init=1.0
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