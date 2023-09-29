module Responses

using FittedItemBanks: AbstractItemBank, BooleanResponse, MultinomialResponse, ResponseType, ItemResponse, resp
using AutoHashEquals

export Response, BareResponses, AbilityLikelihood

concrete_response_type(::BooleanResponse) = Bool
concrete_response_type(::MultinomialResponse) = Int

@auto_hash_equals struct Response{ResponseTypeT <: ResponseType, ConcreteResponseTypeT}
    index::Int
    value::ConcreteResponseTypeT

    Response(rt, index, value) = new{typeof(rt), concrete_response_type(rt)}(index, value)
end

@auto_hash_equals struct BareResponses{
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

function (ability_lh::AbilityLikelihood)(θ)
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
end

end
