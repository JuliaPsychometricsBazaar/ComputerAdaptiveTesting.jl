module Responses

export Response, BareResponses

struct Response
    index::Int32
    value::Int8
end

struct BareResponses
    indices::Vector{Int32}
    values::Vector{Int8}
end

BareResponses() = BareResponses([], [])

end