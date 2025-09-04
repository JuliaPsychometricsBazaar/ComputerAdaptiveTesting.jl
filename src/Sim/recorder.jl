function empty_capacity(typ, size)
    ret = typ[]
    sizehint!(ret, size)
    return ret
end

function empty_capacity(typ, dims...)
    ret = ElasticArray{typ}(undef, dims[1:end - 1]..., 0)
    sizehint_lastdim!(ret, dims[end])
    return ret
end

# Elastic arrays do not support `push!` directly, so we define our own
elastic_push!(xs::AbstractVector, value) = push!(xs, value)
elastic_push!(xs::ElasticArray, value) = append!(xs, value)

Base.@kwdef mutable struct CatRecording{LikelihoodsT <: NamedTuple}
    #ability_ests::AbilityVecT
    #xs::Union{Nothing, AbilityVecT}
    #likelihoods::Matrix{Float64}
    #raw_likelihoods::Matrix{Float64}
    data::LikelihoodsT
    item_index::Vector{Int}
    item_correctness::Vector{Bool}
    rules_description::Union{Nothing, IOBuffer} = nothing
    item_bank_description::Union{Nothing, IOBuffer} = nothing
    has_initial::Bool = false
    include_initial::Bool = true
end

function Base.getproperty(obj::CatRecording, sym::Symbol)
    if hasfield(CatRecording, sym)
        return getfield(obj, sym)
    else
        return getproperty(obj.data, sym)
    end
end

Base.@kwdef struct CatRecorder{RequestsT <: NamedTuple, LikelihoodsT <: NamedTuple}
    recording::CatRecording{LikelihoodsT}
    requests::RequestsT
    include_initial=true
    #integrator::AbilityIntegrator
    #raw_estimator::LikelihoodAbilityEstimator
    #ability_estimator::AbilityEstimator
end

"""
    consume!(dict, key) do value
        ...
    end

Execute the callback with the value at `key` in `dict` if it exists, and remove that key from the dictionary.
"""
function consume!(cb, dict, key)
    if haskey(dict, key)
        cb(dict[key])
        delete!(dict, key)
    end
end

function power_summary(io::IO, recorder::CatRecorder; include_recording = true, skip_first_line=false, kwargs...)
    if !skip_first_line
        println(io, "Recorder for Computer-Adaptive Tests:")
    end
    if include_recording
        power_summary(io, recorder.recording; skip_first_line=true, recorder=recorder, kwargs...)
    else
        for (name, config) in pairs(recorder.requests)
            println(io, "  \"" * string(name) * "\"")
            indent_io = indent(io, 4)
            config_dict = Dict{Symbol, Any}(pairs(config))
            for k in (:label, :type, :source)
                consume!(config_dict, k) do v
                    println(indent_io, uppercasefirst(string(k)) * ": ", v)
                end
            end
            consume!(config_dict, :estimator) do v
                power_summary(indent_io, v)
            end
            consume!(config_dict, :points) do v
                println(indent_io, "Points:")
                power_summary(indent(indent_io, 2), GridSummary(v))
            end
            consume!(config_dict, :integrator) do v
                power_summary(indent_io, v)
            end
            for (k, v) in pairs(config_dict)
                println(indent_io, "Unknown key $k:")
                println(indent(indent_io, 2), pprint(v))
            end
        end
    end
end

function CatRecording(
    data,
    expected_responses=0,
    include_initial=true
)
    CatRecording(;
        data=data,
        item_index=empty_capacity(Int, expected_responses),
        item_correctness=empty_capacity(Bool, expected_responses),
        include_initial
    )
end

function prepare_dataframe(recording::CatRecording)
    item_indices = convert(Vector{Union{Nothing, Int}}, recording.item_index)
    responses = convert(Vector{Union{Nothing, Bool}}, recording.item_correctness)
    if recording.include_initial && recording.has_initial
        pushfirst!(item_indices, nothing)
        pushfirst!(responses, nothing)
    end
    cols = (;
        Item = item_indices,
        Response = responses,
    )
    for (name, value) in pairs(recording.data)
        if value.data isa AbstractVector
            label = haskey(value, :label) ? Symbol(value.label) : name
            cols = (;
                cols...,
                label => copy(value.data)
            )
        end
    end
    return DataFrame(cols, copycols=false)
end

function power_summary(io::IO, recording::CatRecording; include_cat_config = :always, skip_first_line=false, recorder=nothing, toplevel=true, kwargs...)
    if !skip_first_line
        println(io, "Recording of a Computer-Adaptive Test")
    end
    is_empty = (
        isnothing(recording.rules_description) &&
        isnothing(recording.item_bank_description) &&
        isempty(recording)
    )
    indent_io = if toplevel
        println()
        io
    else
        indent(io, 2)
    end
    if !is_empty
        if recording.rules_description === nothing && include_cat_config == :always
            println(indent_io, "Unknown CAT configuration")
        elseif include_cat_config != :never # :available or :always
            println(indent_io, "CAT configuration:")
            write(indent(indent_io, 2), recording.rules_description)
            seekstart(recording.rules_description)
        end
        if toplevel
            println(io)
        end
        if recording.item_bank_description === nothing
            println(indent_io, "Unknown item bank")
        else
            println(indent_io, "Item bank:")
            write(indent(indent_io, 2), recording.item_bank_description)
            seekstart(recording.item_bank_description)
            if toplevel
                println(io)
            end
        end
    end
    if recorder !== nothing
        println(indent_io, "Requested information:")
        power_summary(indent_io, recorder; include_recording=false, skip_first_line=true, kwargs...)
        if toplevel
            println(io)
        end
    end
    if is_empty
        println(indent_io, "CAT has not yet been run; no recorded information")
    else
        println(indent_io, "Recorded information:")
        println(io)
        df = prepare_dataframe(recording)
        buf = show_into_buf(
            df;
            summary = false,
            eltypes = false,
            stubhead_label = "Administration",
            row_labels = 0:(nrow(df) - 1),
            compact_printing = false,
            formatters = [DataFrames._pretty_tables_general_formatter, fmt__printf("%5.3f", [3, 4])]
        )
        write(indent(indent_io, 2), buf)
    end
end

#=
function CatRecording(
        xs,
        points,
        ability_ests,
        num_questions,
        num_respondents,
        actual_abilities = nothing)
    num_values = num_questions * num_respondents
    if xs === nothing
        xs_vec = nothing
    else
        xs_vec = collect(xs)
    end

    CatRecorder(1,
        1,
        points,
        zeros(Int, num_values),
        ability_ests,
        zeros(Float64, num_values),
        zeros(Int, num_values),
        xs_vec,
        zeros(points, num_values),
        zeros(points, num_values),
        zeros(points, num_values),
        zeros(num_questions, num_respondents),
        zeros(Int, num_questions, num_respondents),
        zeros(Bool, num_questions, num_respondents),
        Dict{Tuple{Int, Int}, Int}(),
        actual_abilities)
end
=#

function record!(recording::CatRecording, responses; data...)
    if length(responses) == 0
        recording.has_initial = true
    else
        item_index = responses.indices[end]
        item_correct = responses.values[end] > 0
        push!(recording.item_index, item_index)
        push!(recording.item_correctness, item_correct)
    end
end

function Base.empty!(recording::CatRecording)
    recording.has_initial = false
    empty!(recording.item_index)
    empty!(recording.item_correctness)
    for (name, value) in pairs(recording.data)
        if value.data isa AbstractVector
            empty!(value.data)
        elseif value.data isa ElasticArray
            resize_lastdim!(value.data, 0)
        end
    end
end

function Base.isempty(recording::CatRecording)
    return length(recording.item_index) == 0 && !recording.has_initial
end

#=
"""
$(TYPEDSIGNATURES)
"""
function CatRecorder(
        xs,
        points,
        ability_ests,
        num_questions,
        num_respondents,
        integrator,
        raw_estimator,
        ability_estimator,
        actual_abilities = nothing)
    CatRecorder(
        CatRecording(
            xs,
            points,
            ability_ests,
            num_questions,
            num_respondents,
            actual_abilities
        ),
        AbilityIntegrator(integrator),
        raw_estimator,
        ability_estimator,
    )
end

function CatRecorder(
        xs::AbstractVector{Float64},
        responses,
        integrator,
        raw_estimator,
        ability_estimator,
        actual_abilities = nothing
    )
    points = size(xs, 1)
    num_questions = size(responses, 1)
    num_respondents = size(responses, 2)
    num_values = num_questions * num_respondents
    CatRecorder(
        xs,
        points,
        zeros(num_values),
        num_questions,
        num_respondents,
        integrator,
        raw_estimator,
        ability_estimator,
        actual_abilities)
end

function CatRecorder(
        xs::AbstractMatrix{Float64},
        responses,
        integrator,
        raw_estimator,
        ability_estimator,
        actual_abilities = nothing
    )
    dims = size(xs, 1)
    points = size(xs, 2)
    num_questions = size(responses, 1)
    num_respondents = size(responses, 2)
    num_values = num_questions * num_respondents
    CatRecorder(xs,
        points,
        zeros(dims, num_values),
        num_questions,
        num_respondents,
        integrator,
        raw_estimator,
        ability_estimator,
        actual_abilities)
end

function CatRecorder(
        xs::AbstractVector{Float64},
        max_responses::Int,
        integrator,
        raw_estimator,
        ability_estimator,
        actual_abilities = nothing
    )
    points = size(xs, 1)
    CatRecorder(xs,
        points,
        zeros(max_responses),
        max_responses,
        1,
        integrator,
        raw_estimator,
        ability_estimator,
        actual_abilities)
end

function CatRecorder(
        xs::AbstractMatrix{Float64},
        max_responses::Int,
        integrator,
        raw_estimator,
        ability_estimator,
        actual_abilities = nothing
    )
    dims = size(xs, 1)
    points = size(xs, 2)
    CatRecorder(xs,
        points,
        zeros(dims, max_responses),
        max_responses,
        1,
        integrator,
        raw_estimator,
        ability_estimator,
        actual_abilities)
end
=#

function name_to_label(name)
    titlecase(join(split(String(name), "_"), " "))
end

function hasallkeys(haystack, needles...)
    return all(n in keys(haystack) for n in needles)
end

function CatRecorder(dims::Int, expected_responses::Int; requests...)
    out = []
    sizehint!(out, length(requests))
    include_initial = true
    requests_dict = Dict{Symbol, Any}(pairs(requests))
    consume!(requests_dict, :include_initial) do v
        include_initial = v
    end
    for (name, request) in pairs(requests_dict)
        extra = (;)
        if !haskey(request, :type)
            error("Must provide `type` for $name.")
        end
        if request.type in (:ability, :ability_stddev)
            data = empty_capacity(Float64, expected_responses)
        elseif request.type == :ability_distribution
            if !hasallkeys(request, :points, :estimator, :integrator)
                error("Must provide `points`, `estimator`, and `integrator` for $name.")
            end
            if dims == 0
                data = empty_capacity(Float64, length(request.points), expected_responses)
            else
                data = empty_capacity(Float64, dims, length(request.points), expected_responses)
            end
            extra = (; points = request.points)
        else
            error("Unknown request type: $(request.type)")
        end
        push!(out, (name => (;
            label=haskey(request, :label) ? request.label : name_to_label(name),
            type=request.type,
            data,
            extra...
        )))
    end
    return CatRecorder(;
        recording=CatRecording(NamedTuple(out), expected_responses, include_initial),
        requests=NamedTuple(requests_dict),
        include_initial
    )
    #=
    CatRecording(
        xs,
        points,
        ability_ests,
        num_questions,
        num_respondents,
        actual_abilities
    ),
    AbilityIntegrator(integrator),
    raw_estimator,
    ability_estimator
    =#
end


function push_ability_est!(ability_ests::AbstractMatrix{Float64}, col_idx, ability_est)
    ability_ests[:, col_idx] = ability_est
end

function push_ability_est!(ability_ests::AbstractVector{Float64}, col_idx, ability_est)
    ability_ests[col_idx] = ability_est
end

function eachmatcol(xs::AbstractMatrix)
    eachcol(xs)
end

function eachmatcol(xs::AbstractVector)
    xs
end

#=
function save_sampled(xs::Nothing, integrator::RiemannEnumerationIntegrator,
        recorder::CatRecorder, tracked_responses, ir, item_correct)
    # In this case, the item bank is probably sampled so we can use that

    # Save likelihoods
    dist_est = distribution_estimator(recorder.ability_estimator)
    denom = normdenom(integrator, dist_est, tracked_responses)
    recorder.likelihoods[:, recorder.col_idx] = function_ys(
        Aggregators.pdf(
        dist_est,
        tracked_responses
    )
    ) ./ denom
    raw_denom = normdenom(integrator, recorder.raw_estimator, tracked_responses)
    recorder.raw_likelihoods[:, recorder.col_idx] = function_ys(
        Aggregators.pdf(
        recorder.raw_estimator,
        tracked_responses
    )
    ) ./ raw_denom

    # Save item responses
    recorder.item_responses[:, recorder.col_idx] = item_ys(ir, item_correct)
end
=#

function sample_likelihood(tracked_responses, xs, dist_est, integrator)
    # Save likelihoods
    num = Aggregators.pdf.(
        dist_est,
        tracked_responses,
        eachmatcol(xs)
    )
    denom = normdenom(integrator, dist_est, tracked_responses)
    return num ./ denom
end

#=
    raw_denom = normdenom(integrator, recorder.raw_estimator, tracked_responses)
    recorder.raw_likelihoods[:, recorder.col_idx] = Aggregators.pdf.(
        Ref(recorder.raw_estimator),
        Ref(tracked_responses),
        eachmatcol(xs)) ./ raw_denom
=#

function service_requests!(
        #xs, integrator, recorder::CatRecorder, tracked_responses, ir, item_correct)
    recorder::CatRecorder, tracked_responses, ir, item_correct
)
    out = recorder.recording.data
    for (name, request) in pairs(recorder.requests)
        if request.type in (:ability, :ability_stddev)
            push!(out[name].data, request.estimator(tracked_responses))
        elseif request.type == :ability_distribution
            likelihood_sample = sample_likelihood(tracked_responses, request.points, request.estimator, request.integrator)
            elastic_push!(out[name].data, likelihood_sample)
        end
    end

    #=
    # Save item responses
    recorder.item_responses[:, recorder.col_idx] = resp.(Ref(ir),
        item_correct,
        eachmatcol(xs))
    =#
end

"""
$(TYPEDSIGNATURES)
"""
function record!(recorder::CatRecorder, tracked_responses)
    local ir, item_correct
    if length(tracked_responses.responses) == 0
        ir = nothing
        item_correct = nothing
    else
        item_index = tracked_responses.responses.indices[end]
        item_correct = tracked_responses.responses.values[end] > 0
        ir = ItemResponse(tracked_responses.item_bank, item_index)
    end
    if ir !== nothing || recorder.include_initial
        service_requests!(recorder, tracked_responses, ir, item_correct)
    end
    record!(recorder.recording, tracked_responses.responses)
end

function recorder_response_callback(recorder::CatRecorder)
    return (tracked_responses, _) -> record!(recorder, tracked_responses)
end

function recorder_init_callback(recorder::CatRecorder)
    return function (cat_loop, tracked_responses)
        item_bank = tracked_responses.item_bank
        empty!(recorder.recording)
        if showable(MIME("text/plain"), cat_loop.rules)
            recorder.recording.rules_description = power_summary_into_buf(cat_loop.rules; toplevel=false)
        end
        if showable(MIME("text/plain"), item_bank)
            recorder.recording.item_bank_description = power_summary_into_buf(item_bank)
        end
        record!(recorder, tracked_responses)
    end
end

#=
function power_summary(io::IO, recorder::CatRecorder)
    indent_io = indent(io, 4)
    println(io, "Computer-Adaptive Test Recorder")
    println(io, "  Requests:")
    power_summary(indent_io, recorder.requests)
    println(io, "  Recording:")
    power_summary(indent_io, recorder.recording)
end
=#
