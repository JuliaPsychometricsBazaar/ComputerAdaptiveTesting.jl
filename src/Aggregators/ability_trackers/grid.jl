const EqualWeightGridIntegrator = Union{FixedGridIntegrator,
    PreallocatedFixedGridIntegrator, Integrators.IterativeFixedGridIntegrator}
const TabulatedDichotomousBank = Union{FittedItemBanks.DichotomousPointsItemBank,
    FittedItemBanks.DichotomousPointsWithLogsItemBank}

grid_linear_values(density, grid) = density.(grid)
function grid_linear_values(density::AbilityLikelihood{<:TabulatedDichotomousBank}, grid)
    grid == function_xs(density) ||
        throw(ArgumentError("The integration grid must match the tabulated item bank grid"))
    function_ys(density)
end
function grid_linear_values(density::IntegralCoeffs.PriorApply, grid)
    grid_linear_values(density.func, grid) .* pdf.(Ref(density.prior.dist), grid)
end

# Both calculation spaces use the same history checks. Snapshots also detect
# edits made directly to BareResponses, outside the tracked mutation hooks.
struct GridHistoryCache{BankT, ResponsesT}
    item_bank::BankT
    responses::ResponsesT
end

function history_snapshot(history::BareResponses)
    BareResponses(history.rt, copy(history.indices), copy(history.values))
end

function cache_prefix_matches(cache, responses::TrackedResponses, prefix_length)::Bool
    history = responses.responses
    snapshot = cache.responses
    0 <= prefix_length <= length(responses) &&
        cache.item_bank === responses.item_bank &&
        length(snapshot) == prefix_length && snapshot.rt == history.rt || return false
    # Compare the prefix directly, without constructing views on every moment.
    for i in 1:prefix_length
        snapshot.indices[i] == history.indices[i] &&
            isequal(snapshot.values[i], history.values[i]) || return false
    end
    true
end

"""
$(TYPEDEF)

Cache an unnormalized density on an equal-weight fixed grid. The estimator
must declare `MultiplicativeResponseDelta()` through [`response_delta_style`](@ref).
Appending responses multiplies only their probabilities into `cur_ability`;
`track!`, rollback and clearing rebuild the density, including its prior.

The cache starts uninitialized. Integration then evaluates temporary densities.
Speculation multiplies its [`unsynced_responses`](@ref) into the committed
weights without changing the cache. Keep grid coordinates, bank parameters and
estimator configuration fixed between explicit `track!` calls. Concurrent reads
are supported, but must not overlap committed updates to the same tracker.
"""
mutable struct GriddedAbilityTracker{
    AbilityEstimatorT <: DistributionAbilityEstimator,
    IntegratorT <: EqualWeightGridIntegrator
} <: AbilityTracker
    ability_estimator::AbilityEstimatorT
    integrator::IntegratorT
    cur_ability::Vector{Float64}
    cache::Union{Nothing, GridHistoryCache}

    function GriddedAbilityTracker(est::E, integrator::I, values::Vector{Float64},
            cache::Union{Nothing, GridHistoryCache}) where {
            E <: DistributionAbilityEstimator, I <: EqualWeightGridIntegrator}
        require_response_deltas(est)
        length(values) == length(Integrators.get_grid(integrator)) ||
            throw(DimensionMismatch("Tracker and grid differ in length"))
        new{E, I}(est, integrator, values, cache)
    end
end

function GriddedAbilityTracker(bits...)
    @returnsome find1_instance(GriddedAbilityTracker, bits)
    @requiresome est = DistributionAbilityEstimator(bits...)
    @requiresome integrator = Integrator(bits...)
    GriddedAbilityTracker(est, integrator)
end

function GriddedAbilityTracker(est::DistributionAbilityEstimator, integrator::EqualWeightGridIntegrator)
    GriddedAbilityTracker(est, integrator, zeros(length(Integrators.get_grid(integrator))), nothing)
end
function GriddedAbilityTracker(
        est::DistributionAbilityEstimator, integrator::EqualWeightGridIntegrator,
        values::Vector{Float64})
    GriddedAbilityTracker(est, integrator, values, nothing)
end

function track!(responses::TrackedResponses, tracker::GriddedAbilityTracker)
    responses.speculation_start == 0 || return tracker
    tracker.cache = nothing
    tracker.cur_ability .= grid_linear_values(pdf(tracker.ability_estimator, responses),
        Integrators.get_grid(tracker.integrator))
    tracker.cache = GridHistoryCache(responses.item_bank, history_snapshot(responses.responses))
    tracker
end

function track_append!(responses::TrackedResponses, tracker::GriddedAbilityTracker)
    responses.speculation_start == 0 || return tracker
    cache = tracker.cache
    if cache === nothing || length(cache.responses) > length(responses) ||
       !cache_prefix_matches(cache, responses, length(cache.responses))
        return track!(responses, tracker)
    end
    tracker.cache = nothing
    delta = response_view(responses.responses, (length(cache.responses) + 1):length(responses))
    likelihood = AbilityLikelihood(responses.item_bank, delta)
    tracker.cur_ability .*= grid_linear_values(likelihood, Integrators.get_grid(tracker.integrator))
    tracker.cache = GridHistoryCache(responses.item_bank, history_snapshot(responses.responses))
    tracker
end

function refresh_after_history_edit!(responses, tracker::GriddedAbilityTracker)
    track!(responses, tracker)
end
