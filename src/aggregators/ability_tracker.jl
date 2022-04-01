function sizehint!(bare_responses::BareResponses, n)
    sizehint!(bare_responses.indices, n)
    sizehint!(bare_responses.values, n)
end

struct NullAbilityTracker <: AbilityTracker end

struct GriddedAbilityTracker <: AbilityTracker
    cur_ability::Vector{Float64}
end

function add_response!(responses::BareResponses, response::Response)::BareResponses
    push!(responses.indices, response.index)
    push!(responses.values, response.value)
    responses
end

function add_response!(tracked_responses::TrackedResponses, response::Response)
    add_response!(tracked_responses.responses, response)
end

function pop_response!(responses::BareResponses)::BareResponses
    pop!(responses.indices)
    pop!(responses.values)
    responses
end

function pop_response!(tracked_responses::TrackedResponses)::TrackedResponses
    pop_response!(tracked_responses.responses)
    tracked_responses
end

function response_expectation(
    ability_estimator::DistributionAbilityEstimator,
    tracked_responses::TrackedResponses,
    item_idx
)::Float64
    expectation(
        ItemResponse(tracked_responses.item_bank, item_idx),
        ability_estimator,
        tracked_responses,
    )
end

function response_expectation(
    ability_estimator::PointAbilityEstimator,
    tracked_responses::TrackedResponses,
    item_idx
)::Float64
    # TODO: use existing θ when a compatible θ tracker is used
    θ_estimate = ability_estimator(tracked_responses)
    ItemResponse(tracked_responses.item_bank, item_idx)(θ_estimate)
end