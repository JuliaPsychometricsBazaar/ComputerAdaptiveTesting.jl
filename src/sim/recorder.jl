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
    item_responses::Vector{Float64}
    item_index::Vector{Int}
    item_correctness::Vector{Bool}
    rules_description::Union{Nothing, String} = nothing
end

Base.@kwdef struct CatRecorder{RequestsT <: NamedTuple, LikelihoodsT <: NamedTuple}
    recording::CatRecording{LikelihoodsT}
    requests::RequestsT
    #integrator::AbilityIntegrator
    #raw_estimator::LikelihoodAbilityEstimator
    #ability_estimator::AbilityEstimator
end

function CatRecording(
    data,
    expected_responses=0
)
    CatRecording(;
        data=data,
        item_responses=empty_capacity(Float64, expected_responses),
        item_index=empty_capacity(Int, expected_responses),
        item_correctness=empty_capacity(Bool, expected_responses)
    )
end

function show(io::IO, ::MIME"text/plain", recording::CatRecording)
    println(io, "Recording of a Computer-Adaptive Test")
    if recording.rules_description === nothing
        println(io, "  Unknown CAT configuration")
    else
        println(io, "  CAT configuration:")
        for line in split(recording.rules_description, "\n")
            println(io, "    ", line)
        end
    end
    println(io, "  item_responses: ", length(recording.item_responses))
    println(io, "  item_index: ", length(recording.item_index))
    println(io, "  item_correctness: ", length(recording.item_correctness))
    for (name, data) in pairs(recording.data)
        println(io, "  $name: ", size(data.data))
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
    #push_ability_est!(recording.ability_ests, recording.col_idx, ability_est)

    item_index = responses.indices[end]
    item_correct = responses.values[end] > 0
    push!(recording.item_index, item_index)
    push!(recording.item_correctness, item_correct)
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

function CatRecorder(dims::Int, expected_responses::Int; requests...)
    out = []
    sizehint!(out, length(requests))
    for (name, request) in pairs(requests)
        if request.type == :ability_value
            data = empty_capacity(Float64, expected_responses)
        elseif request.type == :ability_distribution
            if dims == 0
                data = empty_capacity(Float64, length(request.points), expected_responses)
            else
                data = empty_capacity(Float64, dims, length(request.points), expected_responses)
            end
        end
        push!(out, (name => (;
            type=request.type,
            data=data,
        )))
    end
    return CatRecorder(;
        recording=CatRecording(NamedTuple(out), expected_responses),
        requests=NamedTuple(requests),
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
        if request.type == :ability_value
            push!(out[name].data, request.estimator(tracked_responses))
        elseif request.type == :ability_distribution
            likelihood_sample = sample_likelihood(tracked_responses, request.points, request.estimator, request.integrator)
            @info "pushing" name size(out[name].data) size(likelihood_sample)
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
    item_index = tracked_responses.responses.indices[end]
    item_correct = tracked_responses.responses.values[end] > 0
    ir = ItemResponse(tracked_responses.item_bank, item_index)
    service_requests!(recorder, tracked_responses, ir, item_correct)
    record!(recorder.recording, tracked_responses.responses)
end

function catrecorder_callback(recoder::CatRecorder)
    return (tracked_responses, _) -> record!(recoder, tracked_responses)
end
