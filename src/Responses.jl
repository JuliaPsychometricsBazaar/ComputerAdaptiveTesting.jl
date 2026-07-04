"""
Types and functions for recording examinee responses and evaluating the
resulting ability likelihood function.
"""
module Responses

using FittedItemBanks: AbstractItemBank,
                       BooleanResponse, MultinomialResponse, ResponseType, ItemResponse,
                       resp,
                       DichotomousPointsItemBank, item_ys
using AutoHashEquals: @auto_hash_equals
using DocStringExtensions

export Response, BareResponses, AbilityLikelihood, function_xs, function_ys
export add_response!, pop_response!

concrete_response_type(::BooleanResponse) = Bool
concrete_response_type(::MultinomialResponse) = Int

"""
$(TYPEDEF)

A single response of the given `ResponseType` to the item at `index`.
"""
@auto_hash_equals struct Response{ResponseTypeT <: ResponseType, ConcreteResponseTypeT}
    index::Int
    value::ConcreteResponseTypeT

    Response(rt, index, value) = new{typeof(rt), concrete_response_type(rt)}(index, value)
end

"""
$(TYPEDEF)

A bare (untracked) sequence of responses, stored as parallel vectors of item
`indices` and response `values`, sharing a common `rt` (response type).
See also `TrackedResponses`, which additionally tracks the item bank and
ability estimate.
"""
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

function Base.empty!(responses::BareResponses)
    Base.empty!(responses.indices)
    Base.empty!(responses.values)
end

"""
$(TYPEDSIGNATURES)

Append `response` to `responses` in-place.
"""
function add_response!(responses::BareResponses, response::Response)::BareResponses
    push!(responses.indices, response.index)
    push!(responses.values, response.value)
    responses
end

"""
$(TYPEDSIGNATURES)

Remove and discard the last response from `responses` in-place.
"""
function pop_response!(responses::BareResponses)::BareResponses
    pop!(responses.indices)
    pop!(responses.values)
    responses
end

function Base.sizehint!(bare_responses::BareResponses, n)
    sizehint!(bare_responses.indices, n)
    sizehint!(bare_responses.values, n)
end

"""
$(TYPEDEF)

The likelihood of ability `θ` given `responses` to items in `item_bank`, i.e.
`θ -> prod(P(response | θ) for response in responses)`. Callable as a function
of `θ`; also has [`function_xs`](@ref)/[`function_ys`](@ref) methods for item
banks that support evaluation at a fixed grid of `xs`.
"""
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

"""
$(TYPEDSIGNATURES)

The grid of ability values (`xs`) at which `ability_lh`'s item bank tabulates
response probabilities.
"""
function function_xs(ability_lh::AbilityLikelihood{DichotomousPointsItemBank})
    return ability_lh.item_bank.xs
end

"""
$(TYPEDSIGNATURES)

The likelihood of `ability_lh`'s responses evaluated at each point in
[`function_xs`](@ref), i.e. the product over responses of the tabulated
response probability at each grid point.
"""
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
