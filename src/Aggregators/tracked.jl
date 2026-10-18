struct FunctionProduct{F, LHF}
    f::F
    lh_function::LHF
end

function (product::FunctionProduct)(x::T) where {T}
    return product.f(x) * product.lh_function(x)
end

struct FunctionArgProduct{F}
    f::F
end

function (product::FunctionArgProduct)(x::A, y::B) where {A, B}
    product.f(x) * y
end

struct TrackedLikelihoodIntegrator{IntegratorT <: EqualWeightGridIntegrator,
    TrackerT <: GriddedAbilityTracker} <: AbilityIntegrator
    integrator::IntegratorT
    tracker::TrackerT

    function TrackedLikelihoodIntegrator(integrator::I,
            tracker::T) where {
            I <: EqualWeightGridIntegrator, T <: GriddedAbilityTracker}
        Integrators.get_grid(integrator) == Integrators.get_grid(tracker.integrator) ||
            throw(ArgumentError("Tracker and integrator grids must match"))
        new{I, T}(integrator, tracker)
    end
end

function get_integrator(integrator::TrackedLikelihoodIntegrator)
    return integrator.integrator
end

function power_summary(io::IO, integrator::TrackedLikelihoodIntegrator)
    println(io, "Tracked ordinary density integration (linear space)")
    power_summary(indent(io, 2), integrator.integrator)
end

# The backend's weighted preallocated overload works for scalar grids/results.
# Other shapes reuse the same grid reduction as log-space integration.
function integrate_grid_weights(backend, f::F, weights, ncomp) where {F}
    BareIntegrationResult(weighted_grid_sum(f, Integrators.get_grid(backend), weights))
end

@inline function integrate_grid_weights(
        backend::Union{FixedGridIntegrator{Vector{Float64}},
            PreallocatedFixedGridIntegrator{Vector{Float64}}},
        f::F,
        weights,
        ncomp) where {F}
    if ncomp == 0
        # The backend also has an array-valued branch for positive ncomp.
        # Pin its scalar result here so that branch cannot widen all moments.
        result = @inline backend(FunctionArgProduct(f), weights, 0)
        result::BareIntegrationResult{Float64}
    else
        BareIntegrationResult(weighted_grid_sum(f, Integrators.get_grid(backend), weights))
    end
end

function (integrator::TrackedLikelihoodIntegrator)(f::F, ncomp) where {F}
    integrator.tracker.cache === nothing &&
        throw(ArgumentError("Call track! before integrating a cache without a response history"))
    integrate_grid_weights(integrator.integrator, f, integrator.tracker.cur_ability, ncomp)
end

@inline function integrate_grid_delta(backend, f::F, weights, likelihood, ncomp) where {F}
    integrate_grid_weights(backend, FunctionProduct(f, likelihood), weights, ncomp)
end
function integrate_grid_delta(backend, f::F, weights,
        likelihood::AbilityLikelihood{<:TabulatedDichotomousBank}, ncomp) where {F}
    effective = weights .* grid_linear_values(likelihood, Integrators.get_grid(backend))
    integrate_grid_weights(backend, f, effective, ncomp)
end

function (integrator::TrackedLikelihoodIntegrator)(f::F,
        ncomp,
        est,
        tracked_responses::TrackedResponses;
        kwargs...) where {F}
    tracker = integrator.tracker
    cache = tracker.cache
    if cache !== nothing && est === tracker.ability_estimator &&
       cache_prefix_matches(cache, tracked_responses, pending_start(tracked_responses) - 1)
        delta = unsynced_responses(tracked_responses)
        isempty(delta.indices) && return integrator(f, ncomp)
        likelihood = AbilityLikelihood(tracked_responses.item_bank, delta)
        return integrate_grid_delta(
            integrator.integrator, f, tracker.cur_ability, likelihood, ncomp)
    end
    # An uninitialized, mismatched or edited history must not use stale weights.
    weights = grid_linear_values(pdf(est, tracked_responses), Integrators.get_grid(integrator.integrator))
    integrate_grid_weights(integrator.integrator, f, weights, ncomp)
end

function (est::MeanAbilityEstimator{E, I})(::DiscreteIndexableDomain,
        rett::IntReturnType, responses::TrackedResponses) where {
        E, I <: TrackedLikelihoodIntegrator}
    expectation(rett, IntegralCoeffs.id, 0, est.integrator, est.dist_est, responses)
end

function response_expectation(est::DistributionAbilityEstimator,
        integral::TrackedLikelihoodIntegrator, tracked_responses::TrackedResponses, item_idx)
    ir = ItemResponse(tracked_responses.item_bank, item_idx)
    denom = normdenom(integral, est, tracked_responses)
    map(FittedItemBanks.responses(ir)) do category
        expectation(x -> resp(ir, category, x), 0, integral, est, tracked_responses, denom)
    end
end

function response_expectation(est::DistributionAbilityEstimator,
        integral::TrackedLikelihoodIntegrator,
        responses::TrackedResponses{<:BareResponses, <:TabulatedDichotomousBank}, item_idx)
    grid = Integrators.get_grid(integral.integrator)
    ir = ItemResponse(responses.item_bank, item_idx)
    grid == FittedItemBanks.item_xs(ir) ||
        throw(ArgumentError("The integration grid must match the tabulated item bank grid"))
    cache = integral.tracker.cache
    weights = if cache !== nothing && est === integral.tracker.ability_estimator &&
                 cache_prefix_matches(cache, responses, pending_start(responses) - 1)
        integral.tracker.cur_ability .* grid_linear_values(
            AbilityLikelihood(responses.item_bank, unsynced_responses(responses)), grid)
    else
        grid_linear_values(pdf(est, responses), grid)
    end
    mass = sum(weights)
    map(FittedItemBanks.responses(ir)) do category
        sum(weights .* FittedItemBanks.item_ys(ir, category)) / mass
    end
end
