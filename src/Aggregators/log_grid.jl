const EqualWeightGridIntegrator = Union{FixedGridIntegrator,
    PreallocatedFixedGridIntegrator, Integrators.IterativeFixedGridIntegrator}

struct LogGridCache{WeightsT, BankT, ResponsesT}
    density::WeightsT
    item_bank::BankT
    responses::ResponsesT
end

"""
$(TYPEDEF)

Cache log densities, normalized weights and their normalization scale on an
equal-weight fixed grid. Construct with `LogGridAbilityTracker(estimator, grid)`
(config bits may be supplied in either order), then use
`LogGridIntegrator(tracker)` for means, variances, covariance and predictions.

`track!(responses, tracker)` evaluates `logpdf(estimator, responses)` on the grid.
`tracker.cache.density` contains `log_values`, normalized `weights`, `log_scale`
and `scaled_sum`; the unnormalized grid mass is `exp(log_scale) * scaled_sum`.
An all-zero density raises `DomainError` rather than manufacturing a posterior.

The cache records a copy of the response history. Integrations for different
histories (including speculation), banks or estimators use temporary weights
without modifying this cache. An uninitialized tracker also works this way.
Treat the grid, bank parameters and estimator as fixed; call `track!` after
changing their contents. Concurrent integrations may read a tracker, but must
not run concurrently with `track!` on that same tracker.
"""
mutable struct LogGridAbilityTracker{EstimatorT <: DistributionAbilityEstimator,
        IntegratorT <: EqualWeightGridIntegrator} <: AbilityTracker
    ability_estimator::EstimatorT
    integrator::IntegratorT
    cache::Union{Nothing, LogGridCache}
end

function LogGridAbilityTracker(bits...)
    @returnsome find1_instance(LogGridAbilityTracker, bits)
    @requiresome estimator = DistributionAbilityEstimator(bits...)
    @requiresome integrator = Integrator(bits...)
    LogGridAbilityTracker(estimator, integrator, nothing)
end

grid_log_values(density, grid) = density.(grid)

const TabulatedDichotomousBank = Union{FittedItemBanks.DichotomousPointsItemBank,
    FittedItemBanks.DichotomousPointsWithLogsItemBank}

function grid_log_values(density::AbilityLogLikelihood{<:AbilityLikelihood{<:TabulatedDichotomousBank}}, grid)
    grid == function_xs(density) ||
        throw(ArgumentError("The integration grid must match the tabulated item bank grid"))
    function_ys(density)
end

function grid_log_values(density::LogPosteriorDensity, grid)
    grid_log_values(density.likelihood, grid) .+ logpdf.(Ref(density.prior), grid)
end

function grid_density(est, responses, integrator)
    LogGridWeights(grid_log_values(logpdf(est, responses), Integrators.get_grid(integrator)))
end

function track!(responses::TrackedResponses, tracker::LogGridAbilityTracker)
    # Clear first so an unsuccessful refresh cannot leave a stale usable cache.
    tracker.cache = nothing
    density = grid_density(tracker.ability_estimator, responses, tracker.integrator)
    history = responses.responses
    snapshot = BareResponses(history.rt, copy(history.indices), copy(history.values))
    tracker.cache = LogGridCache(density, responses.item_bank, snapshot)
    tracker
end

refresh_after_history_edit!(responses, tracker::LogGridAbilityTracker) = track!(responses, tracker)

"""
$(TYPEDEF)

Integrate ability densities using normalized log weights on an equal-weight
fixed grid. Construct with `LogGridIntegrator(grid)` or
`LogGridIntegrator(tracker::LogGridAbilityTracker)`. Accepts `FixedGridIntegrator`,
its preallocated form, and `IterativeFixedGridIntegrator`. Like those integrators,
raw integrals are sums without a grid-spacing factor.

Expectations return ordinary scalars, vectors or matrices. Raw integration and
`normdenom` preserve the absolute scale using logarithmic numbers: use `log` to
inspect tiny masses, and explicitly convert to floating point only if desired.
An explicit denominator passed to `expectation` retains its usual meaning.

Requires the estimator's native `logpdf` interface. Tabulated dichotomous banks
are supported when their grid exactly matches the integration grid. The grid
must be nonempty and have nonzero density somewhere. `NaN` and `+Inf` log
densities are rejected. No adaptive-quadrature error estimate is provided.
"""
struct LogGridIntegrator{IntegratorT <: EqualWeightGridIntegrator,
        TrackerT <: Union{Nothing, LogGridAbilityTracker}} <: AbilityIntegrator
    integrator::IntegratorT
    tracker::TrackerT

    function LogGridIntegrator(integrator::I, tracker::T) where {
            I <: EqualWeightGridIntegrator, T <: Union{Nothing, LogGridAbilityTracker}}
        check_log_grid(integrator, tracker)
        new{I, T}(integrator, tracker)
    end
end

check_log_grid(integrator, ::Nothing) = nothing
function check_log_grid(integrator, tracker::LogGridAbilityTracker)
    Integrators.get_grid(integrator) == Integrators.get_grid(tracker.integrator) ||
        throw(ArgumentError("Tracker and integrator grids must match"))
end

function LogGridIntegrator(bits...)
    @returnsome find1_instance(LogGridIntegrator, bits)
    tracker = find1_instance(LogGridAbilityTracker, bits)
    integrator = Integrator(bits...)
    if integrator === nothing
        tracker === nothing && throw(ArgumentError("Supply an equal-weight grid or a LogGridAbilityTracker"))
        integrator = tracker.integrator
    end
    LogGridIntegrator(integrator, tracker)
end

get_integrator(integrator::LogGridIntegrator) = integrator.integrator

cached_grid_density(::Nothing, est, responses, integrator) = grid_density(est, responses, integrator)

function cached_grid_density(tracker::LogGridAbilityTracker, est, responses, integrator)
    cache = tracker.cache
    if cache !== nothing && est === tracker.ability_estimator &&
            responses.item_bank === cache.item_bank &&
            responses.responses == cache.responses
        return cache.density
    end
    grid_density(est, responses, integrator)
end

function grid_density(est, responses, integrator::LogGridIntegrator)
    cached_grid_density(integrator.tracker, est, responses, integrator.integrator)
end

function (integrator::LogGridIntegrator)(f::F, ncomp,
        est::DistributionAbilityEstimator, responses::TrackedResponses) where {F}
    density = grid_density(est, responses, integrator)
    value = weighted_grid_mean(f, Integrators.get_grid(integrator.integrator), density)
    BareIntegrationResult(scale_grid_value(value, density))
end

function Integrators.normdenom(rett::IntReturnType, integrator::LogGridIntegrator,
        est::DistributionAbilityEstimator, responses::TrackedResponses)
    rett(BareIntegrationResult(grid_mass(grid_density(est, responses, integrator))))
end

function expectation(rett::IntReturnType, f::F, ncomp, integrator::LogGridIntegrator,
        est::DistributionAbilityEstimator, responses::TrackedResponses, denom = nothing) where {F}
    density = grid_density(est, responses, integrator)
    value = weighted_grid_mean(f, Integrators.get_grid(integrator.integrator), density)
    # Cancel the mass before multiplying by the moment. This also avoids loss of
    # precision from adding a moment's logarithm to a huge log normalization scale.
    correction = denom === nothing ? 1.0 : unlog(grid_mass(density) / denom)
    rett(BareIntegrationResult(value * correction))
end

function (est::MeanAbilityEstimator{E, I})(::DiscreteIndexableDomain,
        rett::IntReturnType, responses::TrackedResponses) where {E, I <: LogGridIntegrator}
    expectation(rett, IntegralCoeffs.id, 0, est.integrator, est.dist_est, responses)
end

grid_response_logs(ir, category, grid) = [FittedItemBanks.log_resp(ir, category, x) for x in grid]

function grid_response_logs(ir::ItemResponse{<:TabulatedDichotomousBank}, category, grid)
    grid == FittedItemBanks.item_xs(ir) ||
        throw(ArgumentError("The integration grid must match the tabulated item bank grid"))
    FittedItemBanks.item_log_ys(ir, category)
end

function grid_response_logs(ir::ItemResponse{<:FittedItemBanks.DichotomousPointsItemBank}, category, grid)
    bank = FittedItemBanks.DichotomousPointsWithLogsItemBank(ir.item_bank)
    grid_response_logs(ItemResponse(bank, ir.index), category, grid)
end

function response_expectation(est::DistributionAbilityEstimator, integrator::LogGridIntegrator,
        tracked_responses::TrackedResponses, item_idx)
    density = grid_density(est, tracked_responses, integrator)
    grid = Integrators.get_grid(integrator.integrator)
    ir = ItemResponse(tracked_responses.item_bank, item_idx)
    # Evaluate every category directly: 1 - E[p] loses rare false responses.
    map(FittedItemBanks.responses(ir)) do category
        logs = grid_response_logs(ir, category, grid)
        weighted_grid_mean(i -> exp(logs[i]), eachindex(grid), density)
    end
end

function power_summary(io::IO, integrator::LogGridIntegrator)
    println(io, "Fixed-grid integration with normalized log densities")
    power_summary(indent(io, 2), integrator.integrator)
end
