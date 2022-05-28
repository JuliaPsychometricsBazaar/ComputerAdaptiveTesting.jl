function sizehint!(bare_responses::BareResponses, n)
    sizehint!(bare_responses.indices, n)
    sizehint!(bare_responses.values, n)
end

struct NullAbilityTracker <: AbilityTracker end

mutable struct PointAbilityTracker{AbilityEstimatorT <: PointAbilityEstimator, AbilityT} <: AbilityTracker
    ability_estimator::AbilityEstimatorT 
    cur_ability::AbilityT
end

function track!(responses)
    track!(responses, responses.ability_tracker)
end

function track!(_, ::NullAbilityTracker) end

function track!(responses, ability_tracker::PointAbilityTracker)
    ability_tracker.cur_ability = ability_tracker.ability_estimator(responses)
end

struct GriddedAbilityTracker{AbilityEstimatorT <: DistributionAbilityEstimator, GridT <: AbstractVector{Float64}} <: AbilityTracker
    ability_estimator::AbilityEstimatorT 
    grid::GridT
    cur_ability::Vector{Float64}
end

GriddedAbilityTracker(ability_estimator, grid) = GriddedAbilityTracker(ability_estimator, grid, fill(NaN, length(grid)))

function track!(responses, ability_tracker::GriddedAbilityTracker)
    ability_pdf = pdf(ability_tracker.ability_estimator, responses)
    ability_tracker.cur_ability = ability_pdf.(ability_tracker.grid)
end

#struct LaplaceAbilityTracker <: AbilityTracker
    #cur_approx::Normal
#end

function add_response!(responses::BareResponses, response::Response)::BareResponses
    push!(responses.indices, response.index)
    push!(responses.values, response.value)
    responses
end

function add_response!(tracked_responses::TrackedResponses, response::Response)
    add_response!(tracked_responses.responses, response)
    track!(tracked_responses)
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

"""
This method returns a tracked point estimate if it is has the given ability
estimator, otherwise it computes it using the given ability estimator.
"""
function maybe_tracked_ability_estimate(
    tracked_responses::TrackedResponses,
    ability_estimator
)
    if (
        (tracked_responses.ability_tracker isa PointAbilityTracker) &&
        (tracked_responses.ability_tracker.ability_estimator === ability_estimator)
    )
        tracked_responses.ability_tracker.cur_ability
    else
        ability_estimator(tracked_responses)
    end
end