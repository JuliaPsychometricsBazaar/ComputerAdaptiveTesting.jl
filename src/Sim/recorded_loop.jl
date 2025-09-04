struct RecordedCatLoop
    cat_loop::CatLoop{<: CatRules}
    recorder::CatRecorder
    item_bank::Union{AbstractItemBank, Nothing}
end

function _prepare_get_response!(kwargs)
    has_responses = haskey(kwargs, :responses)
    has_get_response = haskey(kwargs, :get_response)
    if has_responses && has_get_response
        error("Cannot provide both `responses` and `get_response`.")
    elseif !has_responses && !has_get_response
        error("Must provide either `responses` or `get_response`.")
    elseif has_get_response
        return nothing, pop!(kwargs, :get_response)
    else
        responses = pop!(kwargs, :responses)
        return responses, Sim.auto_responder(responses)
    end
end

function _walk_find_type(obj, typ, out=[])
    if obj isa typ
        push!(out, obj)
    end
    for fieldname in propertynames(obj)
        _walk_find_type(getfield(obj, fieldname), typ, out)
    end
    return out
end

function _find_mean_ability(rules)
    if rules.ability_estimator isa MeanAbilityEstimator
        return rules.ability_estimator
    end
    result = _walk_find_type(rules.next_item, MeanAbilityEstimator)
    if !isempty(result)
        return result[1]
    end
    result = _walk_find_type(rules.termination_condition, MeanAbilityEstimator)
    if !isempty(result)
        return result[1]
    end
    return nothing
end

function _find_ability_variance(rules)
    result = _walk_find_type(rules.next_item, AbilityVariance)
    if !isempty(result)
        return result[1]
    end
    return nothing
end

struct StdDevEstimator
    ability_variance::AbilityVariance
end

function (est::StdDevEstimator)(tracked_responses::TrackedResponses)
    sqrt(compute_criterion(est.ability_variance, tracked_responses))
end

function power_summary(io::IO, est::StdDevEstimator)
    println(io, "Standard deviation based on variance estimate")
    power_summary(io, est.ability_variance; skip_first_line=true)
end

show(io::IO, ::MIME"text/html", est::StdDevEstimator) = power_summary(io, est)

function enrich_recorder_requests(old_requests, rules)
    requests = Dict()
    for (k, v) in pairs(old_requests)
        new_v = Dict{Symbol, Any}(pairs(v))
        type = get(new_v, :type, nothing)
        if type in (:ability, :ability_distribution, :ability_stddev)
            if haskey(new_v, :estimator) && haskey(new_v, :source)
                error("Cannot provide both `estimator` and `source` for request `$k`.")
            elseif !haskey(new_v, :estimator)
                if !haskey(new_v, :source)
                    error("Must provide either `estimator` or `source` for request `$k`.")
                end
                source = new_v[:source]
                if source != :any
                    error("Not implemented yet: `source = $source` for request `$k`.")
                end
                if type == :ability
                    new_v[:estimator] = rules.ability_estimator
                elseif type == :ability_stddev
                    ability_variance = _find_ability_variance(rules)
                    if ability_variance === nothing
                        error("Cannot find a `AbilityVariance` in the rules for request `$k`.")
                    end
                    new_v[:estimator] = StdDevEstimator(ability_variance)
                elseif type == :ability_distribution
                    estimator = nothing
                    integrator = nothing
                    mean_ability = _find_mean_ability(rules)
                    if mean_ability === nothing
                        ability_variance = _find_ability_variance(rules)
                        if ability_variance === nothing
                            error("Cannot find a `MeanAbilityEstimator` or `AbilityVariance` in the rules for request `$k`.")
                        end
                        estimator = ability_variance.dist_est
                        integrator = ability_variance.integrator
                    else
                        estimator = distribution_estimator(mean_ability)
                        integrator = mean_ability.integrator
                    end
                    new_v[:estimator] = estimator
                    if !haskey(new_v, :integrator)
                        new_v[:integrator] = integrator
                    end
                    if !haskey(new_v, :points)
                        integrator = get_integrator(new_v[:integrator])
                        if !(integrator isa AnyGridIntegrator)
                            error("Must provide `points` for request `$k` when `integrator` is not an `AnyGridIntegrator`.")
                        end
                        new_v[:points] = get_grid(integrator)
                    end
                end
            end
        end
        requests[k] = NamedTuple(new_v)
    end
    return requests
end

"""
```julia
RecordedCatLoop(;
    rules::CatRules,
    item_bank::AbstractItemBank = nothing,
    responses::Union{Nothing, Vector{ResponseType}} = nothing,
    dims::Union{Nothing, Tuple{Int, Int}} = nothing,
    expected_responses::Int = 0,
    get_response::Function = nothing,
    new_response_callback::Function = nothing,
    new_response_callbacks::Vector{Function} = Any[]
    requests...
)
```

This `RecordedCatLoop` is a simplified construction of a `[CatRules](@ref)`-based `[CatLoop](@ref)` and `[CatRecorder](@ref)`.

It can be constructed with just some cat `rules`, an `item_bank`, and a response memory `responses`, as well as usually one or more `requests` for the `[CatRecorder](@ref).
In this case `dims` are provided by the `item_bank`, and `expected_responses` is set to the length of `responses` as well as used to provide responses using `get_responses`, otherwise the respective arguments must be provided.
The arguments `get_response`, `new_response_callback`, and `new_response_callbacks` are passed to the underlying `CatLoop`.

The resulting `RecordedCatLoop` can be run directly with run_cat.
"""
function RecordedCatLoop(; kwargs...)
    kwargs = Dict(kwargs)
    responses, get_response = _prepare_get_response!(kwargs)
    local expected_responses, rules
    if responses !== nothing
        expected_responses = length(responses)
    else
        expected_responses = pop!(kwargs, :expected_responses, 0)
    end
    if haskey(kwargs, :rules)
        rules = pop!(kwargs, :rules)
    else
        error("Must provide `rules`.")
    end
    new_response_callback = pop!(kwargs, :new_response_callback, nothing)
    new_response_callbacks = pop!(kwargs, :new_response_callbacks, Any[])
    local dims
    item_bank = nothing
    if !haskey(kwargs, :item_bank) && !haskey(kwargs, :dims)
        error("Must provide either `item_bank` or `dims`.")
    end
    if haskey(kwargs, :item_bank)
        item_bank = pop!(kwargs, :item_bank)
        dims = domdims(item_bank)
    end
    if haskey(kwargs, :dims)
        dims = pop!(kwargs, :dims)
    end
    requests = enrich_recorder_requests(kwargs, rules)
    cat_recorder = CatRecorder(dims, expected_responses; requests...)
    RecordedCatLoop(
        CatLoop(;
            rules,
            get_response,
            new_response_callback,
            new_response_callbacks,
            recorder=cat_recorder
        ),
        cat_recorder,
        item_bank
    )
end

"""
$TYPEDSIGNATURES

Run a given [RecordedCatLoop](@ref) by delegating the call to the wrapped [CatLoop](@ref).

In case `item_bank` is not provided, the item bank provided during the construction of `RecordedCatLoop` is used.
"""
function run_cat(loop::RecordedCatLoop,
        item_bank::AbstractItemBank;
        ib_labels = nothing)
    run_cat(loop.cat_loop, item_bank; ib_labels=ib_labels)
end

function run_cat(loop::RecordedCatLoop; ib_labels = nothing)
    if loop.item_bank === nothing
        error("Trying to run a RecordedCatLoop without an item bank when no item bank was provided at construction time.")
    end
    run_cat(loop, loop.item_bank; ib_labels=ib_labels)
end

function power_summary(io::IO, loop::RecordedCatLoop)
    println(io, "Recorded Computer-Adaptive Test:")
    power_summary(io, loop.recorder.recording; skip_first_line=true, recorder=loop.recorder)
end
