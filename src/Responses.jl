module Responses

using FittedItemBanks: AbstractItemBank, BooleanResponse, MultinomialResponse, ResponseType, ItemResponse, resp

export Response, BareResponses, AbilityLikelihood

concrete_response_type(::BooleanResponse) = Bool
concrete_response_type(::MultinomialResponse) = Int

struct Response{ResponseTypeT <: ResponseType, ConcreteResponseTypeT}
    index::Int
    value::ConcreteResponseTypeT

    Response(rt, index, value) = new{typeof(rt), concrete_response_type(rt)}(index, value)
end

struct BareResponses{
    ResponseTypeT <: ResponseType,
    ConcreteResponseTypeT,
    IndicesVecT <: AbstractVector{Int},
    ValuesVecT <: AbstractVector{ConcreteResponseTypeT}
}
    rt::ResponseTypeT
    indices::IndicesVecT
    values::ValuesVecT

    function BareResponses(
        rt::ResponseTypeT,
        indices::IndicesVecT,
        values::ValuesVecT
    ) where {
        ResponseTypeT,
        IndicesVecT,
        ValuesVecT
    }
        concrete_rt = concrete_response_type(rt)
        @assert concrete_rt <: eltype(values) "values must be a container of $(concrete_rt) for $(rt)"
        new{
            ResponseTypeT,
            concrete_rt,
            IndicesVecT,
            ValuesVecT
        }(
            rt,
            indices,
            values
        )
    end
end

BareResponses(rt::ResponseType) = BareResponses(rt, Int[], concrete_response_type(rt)[])

struct AbilityLikelihood{ItemBankT <: AbstractItemBank, BareResponsesT <: BareResponses}
    item_bank::ItemBankT
    responses::BareResponsesT
end

function (ability_lh::AbilityLikelihood)(θ::Float64)::Float64
    res = 1.0
    for resp_idx in axes(ability_lh.responses.indices, 1)
        res *= resp(
            ItemResponse(
                ability_lh.item_bank,
                ability_lh.responses.indices[resp_idx]
            ),
            ability_lh.responses.values[resp_idx],
            θ
        )
    end
    return res
end

end
