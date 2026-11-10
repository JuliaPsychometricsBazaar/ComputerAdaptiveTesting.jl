struct FunctionProduct{F, LHF}
    f::F
    lh_function::LHF
end

function (product::FunctionProduct)(x::T) where {T}
    return product.f(x) * product.lh_function(x)
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

# Reduce the cached weights directly, using the same weighted reducer as
# log-space integration. The backend's broadcast path can box scalar coefficient
# evaluations even with a preallocated buffer (notably nested broadcasts in SqDev).
function integrate_grid_weights(backend, f::F, weights, ncomp) where {F}
    BareIntegrationResult(weighted_grid_sum(f, Integrators.get_grid(backend), weights))
end

function (integrator::TrackedLikelihoodIntegrator)(f::F, ncomp) where {F}
    integrator.tracker.density === nothing &&
        throw(ArgumentError("Call track! before integrating a cache without a response history"))
    integrate_grid_weights(integrator.integrator, f, integrator.tracker.density, ncomp)
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
    density = grid_density(est, tracked_responses, integrator)
    integrate_grid_weights(integrator.integrator, f, density, ncomp)
end

function grid_density(est, tracked_responses, integrator::TrackedLikelihoodIntegrator)
    tracker = integrator.tracker
    density = speculative_density(tracker, tracked_responses.ability_tracker)
    if density !== nothing && est === tracker.ability_estimator
        return density
    end
    # Uninitialized or mismatched estimators use a temporary full density.
    grid_linear_values(pdf(est, tracked_responses), Integrators.get_grid(integrator.integrator))
end

function variance(integrator::TrackedLikelihoodIntegrator{<:ScalarGridIntegrator},
        est::DistributionAbilityEstimator, responses::TrackedResponses, denom = nothing)
    density = grid_density(est, responses, integrator)
    weighted_grid_moments(Integrators.get_grid(integrator.integrator), density;
        denominator = denom).variance
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
    density = speculative_density(integral.tracker, responses.ability_tracker)
    weights = density !== nothing && est === integral.tracker.ability_estimator ?
        density : grid_linear_values(pdf(est, responses), grid)
    mass = sum(weights)
    map(FittedItemBanks.responses(ir)) do category
        sum(weights .* FittedItemBanks.item_ys(ir, category)) / mass
    end
end
