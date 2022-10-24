module Responses

export ResponseType, Response, BareResponses, BooleanResponse, MultinomialResponse

abstract type ResponseType end

struct BooleanResponse <: ResponseType end
struct MultinomialResponse <: ResponseType end

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

end