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

function _walk_find_type_first(args...)
    result = _walk_find_type(args...)
    if !isempty(result)
        return result[1]
    end
    return nothing
end

#=
function _find_mean_ability(rules_source)
    if rules.ability_estimator isa MeanAbilityEstimator
        return rules.ability_estimator
    end
    @returnsome _walk_find_type_first(rules.next_item, MeanAbilityEstimator)
    @returnsome _walk_find_type_first(rules.termination_condition, MeanAbilityEstimator)
    return nothing
end

function _find_ability_variance(rules)
    @returnsome _walk_find_type(rules.next_item, AbilityVariance)
    return nothing
end
=#

MeanAbilityEstimator, ModeAbilityEstimator
const SOURCE_ORDER = (:ability_estimator, :termination_condition, :next_item)
const VALID_SOURCES = (:any, SOURCE_ORDER...)
const VALID_TYPES = (:ability, :ability_stddev, :ability_and_stddev, :ability_distribution)

function enrich_request_source(source, type, rules, request)
    if source == :any
        for source in SOURCE_ORDER
            @returnsome enrich_request_type(type, source, rules, request)
        end
        return nothing
    else
        return enrich_request_type(type, source, rules, request)
    end
end

enrich_request_type(type, source, rules, request) = enrich_request_type(Val(type), source, rules, request)

function enrich_request_type(::Val{:ability}, source, rules, request)
    @returnsome _walk_find_type_first(getproperty(rules, source), PointAbilityEstimator)
    return nothing
end

function enrich_request_type(::Val{:ability_stddev}, source, rules, request)
    ability_variance = enrich_request_type(Val(:ability_and_stddev), source, rules, request)
    return SpreadEstimator(ability_variance)
end

function enrich_request_type(::Val{:ability_and_stddev}, source, rules, request)
    rules_source = getproperty(rules, source)
    @returnsome _walk_find_type_first(rules_source, MeanAbilityEstimator) MeanAndStdDevEstimator
    @returnsome _walk_find_type_first(rules_source, AbilityVariance) MeanAndStdDevEstimator
    @returnsome _walk_find_type_first(rules_source, ModeAbilityEstimator) LaplaceApproxEstimator
end

function get_composite(rules, source)
    rules_source = getproperty(rules, source)
    @returnsome _walk_find_type_first(rules_source, MeanAbilityEstimator)
    @returnsome _walk_find_type_first(rules_source, AbilityVariance)
end

function enrich_request_type(::Val{:ability_distribution}, source, rules, request)
    if !(:integrator in keys(request))
        @info "ability_distribution" rules source
        @requiresome composite = get_composite(rules, source)
        @info "composite" composite
        return DistributionSampler(composite, get(request, :points, nothing))
    else
        rules_source = getproperty(rules, source)
        @info "ability_distribution" rules_source DistributionAbilityEstimator
        @requiresome dist_est = _walk_find_type_first(rules_source, DistributionAbilityEstimator)
        return DistributionSampler(dist_est, get(request, :integrator, nothing), get(request, :points, nothing))
    end
end

function enrich_recorder_request(name, request, rules)
    type = get(request, :type, nothing)
    if !(type in VALID_TYPES)
        return request
    end
    if haskey(request, :estimator) && haskey(request, :source)
        error("Cannot provide both `estimator` and `source` for request `$name`.")
    elseif haskey(request, :estimator)
        return request
    end
    if !haskey(request, :source)
        error("Must provide either `estimator` or `source` for request `$name`.")
    end
    source = request[:source]
    if !(source in VALID_SOURCES)
        error("Not implemented: `source = $source` for request `$name`; must be one of $VALID_SOURCES.")
    end
    result = enrich_request_source(source, type, rules, request)
    if isnothing(result)
        error("Could not find suitable estimator for request `$name` with `type = $type` and `source = $source`.")
    elseif result isa NamedTuple
        if !(:points in keys(request)) && !(:points in keys(result))
            error("Must provide `points` for request `$name` with `type = $type` and `source = $source` since found `integrator` not an `AnyGridIntegrator`.")
        end
        return (; request..., result...)
    else
        return (; request..., estimator=result)
    end
end

function enrich_recorder_requests(old_requests, rules)
    requests = Dict()
    for (k, v) in pairs(old_requests)
        requests[k] = enrich_recorder_request(k, v, rules)
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
    dims = 0
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
