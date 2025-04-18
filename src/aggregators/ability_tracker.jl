function track!(responses)
    track!(responses, responses.ability_tracker)
end

function Responses.add_response!(tracked_responses::TrackedResponses, response::Response)
    add_response!(tracked_responses.responses, response)
    track!(tracked_responses)
end

function Responses.pop_response!(tracked_responses::TrackedResponses)::TrackedResponses
    pop_response!(tracked_responses.responses)
    tracked_responses
end

function Base.empty!(tracked_responses::TrackedResponses)
    Base.empty!(tracked_responses.responses)
end

function response_expectation(ability_estimator::DistributionAbilityEstimator,
        integrator::AbilityIntegrator,
        tracked_responses::TrackedResponses,
        item_idx)
    # TODO: Remove lambdas
    # TODO: Support nominal responses
    exp1 = expectation(
        x -> resp(ItemResponse(tracked_responses.item_bank, item_idx), x),
        0,
        integrator,
        ability_estimator,
        tracked_responses)
    SVector(1.0 - exp1, exp1)
end

function response_expectation(ability_estimator::PointAbilityEstimator,
        tracked_responses::TrackedResponses,
        item_idx)
    # TODO: use existing θ when a compatible θ tracker is used
    θ_estimate = ability_estimator(tracked_responses)
    resp_vec(ItemResponse(tracked_responses.item_bank, item_idx), θ_estimate)
end

struct NullAbilityTracker <: AbilityTracker end

function track!(_, ::NullAbilityTracker) end

struct ConsAbilityTracker{H <: AbilityTracker, T <: AbilityTracker} <: AbilityTracker
    head::H
    tail::T
end

function track!(responses, cons::ConsAbilityTracker)
    track!(responses, cons.head)
    track!(responses, cons.tail)
end

struct VarNormal{T <: Real}
    mean::T
    var::T
end

include("./ability_trackers/grid.jl")
include("./ability_trackers/point.jl")
include("./ability_trackers/closed_form_normal.jl")
include("./ability_trackers/laplace.jl")

"""
This method returns a tracked point estimate if it is has the given ability
estimator, otherwise it computes it using the given ability estimator.
"""
function maybe_tracked_ability_estimate(tracked_responses::TrackedResponses,
        ability_estimator)
    if ((tracked_responses.ability_tracker isa PointAbilityTracker) &&
        (tracked_responses.ability_tracker.ability_estimator === ability_estimator))
        tracked_responses.ability_tracker.cur_ability
    else
        ability_estimator(tracked_responses)
    end
end
