module Responses

using FittedItemBanks: AbstractItemBank,
                       BooleanResponse, MultinomialResponse, ResponseType, ItemResponse,
                       resp,
                       DichotomousPointsItemBank, item_ys
using AutoHashEquals: @auto_hash_equals

export Response, BareResponses, AbilityLikelihood, function_xs, function_ys

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

    function BareResponses(rt::ResponseTypeT,
            indices::IndicesVecT,
            values::ValuesVecT) where {
            ResponseTypeT,
            IndicesVecT,
            ValuesVecT
    }
        concrete_rt = concrete_response_type(rt)
        @assert concrete_rt<:eltype(values) "values must be a container of $(concrete_rt) for $(rt)"
        new{
            ResponseTypeT,
            concrete_rt,
            IndicesVecT,
            ValuesVecT
        }(rt,
            indices,
            values)
    end
end

BareResponses(rt::ResponseType) = BareResponses(rt, Int[], concrete_response_type(rt)[])

function _iter_helper(gen, result)
    if result === nothing
        return nothing
    end
    (item, gen_state) = result
    return (item, (gen, gen_state))
end

function Base.iterate(responses::BareResponses)
    gen = (Response(responses.rt, index, value) for (index, value) in zip(
        responses.indices, responses.values))
    return _iter_helper(gen, iterate(gen))
end

function Base.iterate(::BareResponses, gen_gen_state)
    (gen, gen_state) = gen_gen_state
    return _iter_helper(gen, iterate(gen, gen_state))
end

struct AbilityLikelihood{ItemBankT <: AbstractItemBank, BareResponsesT <: BareResponses}
    item_bank::ItemBankT
    responses::BareResponsesT
end

function (ability_lh::AbilityLikelihood)(θ)
    return prod(
        resp(
            ItemResponse(
                ability_lh.item_bank,
                ability_lh.responses.indices[resp_idx]
            ),
            ability_lh.responses.values[resp_idx],
            θ
        )
        for resp_idx in axes(ability_lh.responses.indices, 1);
        init = 1.0
    )
end

function function_xs(ability_lh::AbilityLikelihood{DichotomousPointsItemBank})
    return ability_lh.item_bank.xs
end

function function_ys(ability_lh::AbilityLikelihood{DichotomousPointsItemBank})
    return reduce(
        .*,
        (
            item_ys(
                ItemResponse(
                    ability_lh.item_bank,
                    ability_lh.responses.indices[resp_idx]
                ),
                ability_lh.responses.values[resp_idx]
            )
        for resp_idx in axes(ability_lh.responses.indices, 1)
        );
        init = ones(length(ability_lh.item_bank.xs))
    )
end

end
