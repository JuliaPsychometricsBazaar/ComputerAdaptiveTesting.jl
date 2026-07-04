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
    new_response_callback::Any
    """
    A callback called each time a CAT is run
    If provided, it is passed `(loop::CatLoop, responses::TrackedResponses)`.
    """
    init_callback::Any
end

function power_summary(io::IO, rules::CatLoop)
    print(io, "Computer-Adaptive Test Loop based on ")
    power_summary(io, rules.rules)
end

function collate_cat_callbacks(callbacks...)
    callbacks = filter(!isnothing, callbacks)
    function all_callbacks(args...)
        for callback in callbacks
            callback(args...)
        end
        nothing
    end
    all_callbacks
end

function CatLoop(;
    rules,
    get_response,
    new_response_callback = nothing,
    new_response_callbacks = Any[],
    init_callback = nothing,
    init_callbacks = Any[],
    recorder = nothing
)
    new_response_callback = collate_cat_callbacks(
        new_response_callbacks...,
        new_response_callback,
        isnothing(recorder) ? nothing : recorder_response_callback(recorder)
    )
    init_callback = collate_cat_callbacks(
        init_callbacks...,
        init_callback,
        isnothing(recorder) ? nothing : recorder_init_callback(recorder)
    )
    CatLoop{typeof(rules)}(rules, get_response, new_response_callback, init_callback)
end
