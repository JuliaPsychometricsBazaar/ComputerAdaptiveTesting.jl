"""
```julia
struct $(FUNCTIONNAME)
$(FUNCTIONNAME)(; rules=..., get_response=..., new_response_callback=...)
```
$(TYPEDFIELDS)

Configuration for a simulatable CAT.
"""
struct CatLoop{CatEngineT} <: CatConfigBase
    """
    An object which implements the CAT engine.
    Implementations exist for:
      * [CatRules](@ref)
      * [Stateful.StatefulCat](@ref ComputerAdaptiveTesting.Stateful.StatefulCat)
    """
    rules::CatEngineT # e.g. CatRules
    """
    The function `(index, label) -> Int8`` which obtains the testee's response for
    a given question, e.g. by prompting or simulation from data.
    """
    get_response::Any
    """
    A callback called each time there is a new responses.
    If provided, it is passed `(responses::TrackedResponses, terminating)`.
    """
    new_response_callback
end

function CatLoop(;
    rules,
    get_response,
    new_response_callback = nothing,
    new_response_callbacks = Any[],
    recorder = nothing
)
    new_response_callbacks = collect(new_response_callbacks)
    if new_response_callback !== nothing
        push!(new_response_callbacks, new_response_callback)
    end
    if recorder !== nothing && showable(MIME("text/plain"), rules)
        buf = IOBuffer()
        show(buf, MIME("text/plain"), rules)
        recorder.recording.rules_description = String(take!(buf))
        push!(new_response_callbacks, catrecorder_callback(recorder))
    end
    function all_callbacks(responses, terminating)
        for callback in new_response_callbacks
            callback(responses, terminating)
        end
        nothing
    end
    CatLoop{typeof(rules)}(rules, get_response, all_callbacks)
end