struct Speculator{TrackedResponsesT <: TrackedResponses}
    responses::TrackedResponsesT
    size::Int

    function Speculator(responses::TrackedResponsesT,
            size::Int) where {TrackedResponsesT}
        response_type = ResponseType(responses.item_bank)
        orig_len = length(responses.responses.indices)
        spec_len = orig_len + size
        indices = Array{Int}(undef, spec_len)
        values = Array{concrete_response_type(response_type)}(undef, spec_len)
        indices[1:orig_len] = responses.responses.indices
        values[1:orig_len] = responses.responses.values
        new{TrackedResponsesT}(
            TrackedResponses(BareResponses(response_type,
                    indices,
                    values),
                responses.item_bank,
                responses.ability_tracker),
            size)
    end
end

function replace_speculation!(speculator::Speculator, indices, values)
    @assert length(indices) == speculator.size && length(values) == speculator.size
    spec_len = length(speculator.responses.responses.indices)
    orig_len = spec_len - speculator.size
    speculator.responses.responses.indices[(orig_len + 1):spec_len] = indices
    speculator.responses.responses.values[(orig_len + 1):spec_len] = values
end
