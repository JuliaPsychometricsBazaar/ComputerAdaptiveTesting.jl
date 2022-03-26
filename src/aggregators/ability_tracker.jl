function sizehint!(bare_responses::BareResponses, n)
    sizehint!(bare_responses.indices, n)
    sizehint!(bare_responses.values, n)
end

struct NullAbilityTracker <: AbilityTracker end

struct GriddedAbilityTracker <: AbilityTracker
    cur_ability::Vector{Float64}
end

function add_response!(responses::BareResponses, response::Response)::Responses
    push!(responses.indices, response.index)
    push!(responses.values, response.value)
    responses
end

function add_response!(tracked_responses::TrackedResponses, response::Response)
    add_response!(tracked_responses.responses, response)
end

function response_expectation(
    ability_estimator::DistributionAbilityEstimator,
    tracked_responses::TrackedResponses,
    item_idx
)::Float64
    ability_estimator
end

function response_expectation(
    ability_estimator::PointAbilityEstimator,
    tracked_responses::TrackedResponses,
    item_idx
)::Float64
    # TODO: use existing θ when a compatible θ tracker is used
    θ_estimate = ability_estimator()
    irf(tracked_responses.item_bank, item_idx, θ_estimate)
end