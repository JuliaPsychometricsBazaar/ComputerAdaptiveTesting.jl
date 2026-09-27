"""
Types and functions for recording examinee responses and evaluating the
resulting ability likelihood function.
"""
module Responses

using FittedItemBanks: AbstractItemBank,
                       BooleanResponse, MultinomialResponse, ResponseType, ItemResponse,
                       resp, log_resp,
                       DichotomousPointsItemBank, DichotomousPointsWithLogsItemBank,
                       item_ys, item_log_ys, item_bank_xs
using AutoHashEquals: @auto_hash_equals
using DocStringExtensions

export Response, BareResponses, AbilityLikelihood, function_xs, function_ys
export AbilityLogLikelihood, function_log_ys
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

function Base.length(responses::BareResponses)
    return length(responses.indices)
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
See [`AbilityLogLikelihood`](@ref) for evaluation without multiplying probabilities.
"""
struct AbilityLikelihood{ItemBankT <: AbstractItemBank, BareResponsesT <: BareResponses}
    item_bank::ItemBankT
    responses::BareResponsesT
end

"""
$(TYPEDEF)

The log likelihood of ability given a response history. Construct with
`AbilityLogLikelihood(item_bank, responses)`, `AbilityLogLikelihood(likelihood)`,
or `AbilityLogLikelihood(tracked_responses)`.

Callable as `log_likelihood(θ)`: sums `FittedItemBanks.log_resp` for the observed
responses, rather than taking the logarithm of a probability product. An empty
history has log likelihood zero; an impossible response has log likelihood
`-Inf`. Pointwise evaluation requires the item bank to implement `log_resp`.

For supported tabulated banks, [`function_xs`](@ref) returns the grid and
[`function_ys`](@ref) returns **log** likelihoods. The wrapped response history
is shared, not copied, so later changes to it affect subsequent evaluations.
"""
struct AbilityLogLikelihood{LikelihoodT <: AbilityLikelihood}
    likelihood::LikelihoodT
end

function AbilityLogLikelihood(item_bank::AbstractItemBank, responses::BareResponses)
    AbilityLogLikelihood(AbilityLikelihood(item_bank, responses))
end

function (log_likelihood::AbilityLogLikelihood)(θ)
    likelihood = log_likelihood.likelihood
    sum((log_resp(ItemResponse(likelihood.item_bank, response.index), response.value, θ)
         for response in likelihood.responses); init = 0.0)
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
function function_xs(ability_lh::AbilityLikelihood{<:Union{
        DichotomousPointsItemBank, DichotomousPointsWithLogsItemBank}})
    return item_bank_xs(ability_lh.item_bank)
end

function_xs(log_likelihood::AbilityLogLikelihood) = function_xs(log_likelihood.likelihood)

"""
$(TYPEDSIGNATURES)

The likelihood of `ability_lh`'s responses evaluated at each point in
[`function_xs`](@ref), i.e. the product over responses of the tabulated
response probability at each grid point.

For an [`AbilityLogLikelihood`](@ref), returns log likelihoods instead.
"""
function function_ys(ability_lh::AbilityLikelihood{<:Union{
        DichotomousPointsItemBank, DichotomousPointsWithLogsItemBank}})
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
        init = ones(length(function_xs(ability_lh)))
    )
end

function_ys(log_likelihood::AbilityLogLikelihood) = function_log_ys(log_likelihood.likelihood)

"""
$(TYPEDSIGNATURES)

Return the response log likelihood at each point in [`function_xs`](@ref),
without exponentiating the accumulated log probabilities. Supports
`DichotomousPointsItemBank` and `DichotomousPointsWithLogsItemBank`.

For repeated evaluations, use `FittedItemBanks.DichotomousPointsWithLogsItemBank`
to reuse its item log-probability cache. An ordinary points bank constructs
that cache on each call. These logs retain the precision of the tabulated
probabilities; they cannot recover probabilities already rounded to zero or one.
An empty history returns zeros and impossible responses yield `-Inf`.
"""
function function_log_ys(ability_lh::AbilityLikelihood{<:DichotomousPointsWithLogsItemBank})
    reduce(.+,
        (item_log_ys(ItemResponse(ability_lh.item_bank, response.index), response.value)
         for response in ability_lh.responses);
        init = zeros(length(function_xs(ability_lh))))
end

function function_log_ys(ability_lh::AbilityLikelihood{<:DichotomousPointsItemBank})
    function_log_ys(AbilityLikelihood(
        DichotomousPointsWithLogsItemBank(ability_lh.item_bank), ability_lh.responses))
end

end
