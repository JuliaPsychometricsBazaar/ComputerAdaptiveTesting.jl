# Using your CAT

```@meta
CurrentModule = ComputerAdaptiveTesting
```

Now you've created your cat according to [Creating a CAT](@ref), there are
a number of ways you can use it.
This section covers a few.
See also the [Examples](@ref demo-page).

When you've set up your CAT using [CatRules](@ref), you can wrap it in a [CatLoop](@ref) and run it with [run_cat](@ref).

```@docs; canonical=false
CatLoop
run_cat
```

## Simulating CATs

You might like to use a response memory or simulated responses to simulate your CAT using `auto_responder`:

```@docs; canonical=false
Sim.auto_responder
```

In case your data is different you might like to modify the implementation:

```@example
function auto_responder(responses)
    function (index, label_)
        responses[index]
    end
end
```

## Integrating into a user-facing applications

A simple interactive implementation of `get_response(...)` is `prompt_response`:

```@docs; canonical=false
Sim.prompt_response
```

For other types of interactivity you can modify the implementation:

```@example
function prompt_response(index_, label)
    println("Response for $label > ")
    parse(Int8, readline())
end
```
