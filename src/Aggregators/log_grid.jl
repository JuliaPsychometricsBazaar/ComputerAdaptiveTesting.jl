"""
$(TYPEDEF)

Cache log densities, normalized weights and their normalization scale on an
equal-weight fixed grid. Construct with `LogGridAbilityTracker(estimator, grid)`
(config bits may be supplied in either order), then use
`LogGridIntegrator(tracker)` for means, variances, covariance and predictions.

`track!(responses, tracker)` evaluates `logpdf(estimator, responses)` on the grid.
`tracker.density` contains `log_values`, normalized `weights`, `log_scale`
and `scaled_sum`; the unnormalized grid mass is `exp(log_scale) * scaled_sum`.
An all-zero density raises `DomainError` rather than manufacturing a posterior.
Float32 coordinates, prior parameters and native Float32 log responses keep
the cached log densities and weights in Float32. Wider inputs promote them.

The estimator must declare `MultiplicativeResponseDelta()` through
[`response_delta_style`](@ref). Appends add only new response log probabilities
to the cached unnormalized log density. Rollback and clearing rebuild it.
Speculation uses a private stacked density. Call `track!` after editing a bare
response history or changing the bank, grid, or estimator. An uninitialized
tracker evaluates a temporary density. Concurrent integrations may read a
tracker, but must not overlap committed updates to it.
"""
mutable struct LogGridAbilityTracker{EstimatorT <: DistributionAbilityEstimator,
    IntegratorT <: EqualWeightGridIntegrator} <: AbilityTracker
    ability_estimator::EstimatorT
    integrator::IntegratorT
    density::Union{Nothing, LogGridWeights}

    function LogGridAbilityTracker(est::E, integrator::I,
            density::Union{Nothing, LogGridWeights}) where {
            E <: DistributionAbilityEstimator, I <: EqualWeightGridIntegrator}
        require_response_deltas(est)
        new{E, I}(est, integrator, density)
    end
end

function LogGridAbilityTracker(bits...)
    @returnsome find1_instance(LogGridAbilityTracker, bits)
    @requiresome estimator = DistributionAbilityEstimator(bits...)
    @requiresome integrator = Integrator(bits...)
    LogGridAbilityTracker(estimator, integrator, nothing)
end

grid_log_values(density, grid) = density.(grid)

function grid_log_values(density::AbilityLogLikelihood{<:AbilityLikelihood{<:TabulatedDichotomousBank}}, grid)
    grid == function_xs(density) ||
        throw(ArgumentError("The integration grid must match the tabulated item bank grid"))
    function_ys(density)
end

function grid_log_values(density::LogPosteriorDensity, grid)
    grid_log_values(density.likelihood, grid) .+ logpdf.(Ref(density.prior), grid)
end

grid_delta_values(likelihood::AbilityLogLikelihood{<:AbilityLikelihood{<:TabulatedDichotomousBank}}, grid) =
    grid_log_values(likelihood, grid)

function grid_density(est, responses, integrator)
    LogGridWeights(grid_log_values(logpdf(est, responses), Integrators.get_grid(integrator)))
end

function track!(responses::TrackedResponses, tracker::LogGridAbilityTracker)
    responses.speculation_start == 0 || return tracker
    # Clear first so an unsuccessful refresh cannot leave a stale usable density.
    tracker.density = nothing
    density = grid_density(tracker.ability_estimator, responses, tracker.integrator)
    tracker.density = density
    tracker
end

function track_append!(responses::TrackedResponses, tracker::LogGridAbilityTracker)
    responses.speculation_start == 0 || return tracker
    density = tracker.density
    density === nothing && return track!(responses, tracker)
    tracker.density = nothing
    delta = response_view(responses.responses, length(responses):length(responses))
    logs = density.log_values .+ grid_log_values(
        AbilityLogLikelihood(responses.item_bank, delta), Integrators.get_grid(tracker.integrator))
    tracker.density = LogGridWeights(logs)
    tracker
end

function refresh_after_history_edit!(responses, tracker::LogGridAbilityTracker)
    track!(responses, tracker)
end

initialize_grid_tracker!(responses, tracker::LogGridAbilityTracker) = track!(responses, tracker)

function grid_delta_density!(scratch::LogGridWeights, tracker::LogGridAbilityTracker,
        density, responses, start)
    if start > length(responses)
        logs = copy_grid_buffer!(scratch.log_values, density.log_values)
        weights = copy_grid_buffer!(scratch.weights, density.weights)
        return LogGridWeights(logs, weights, density.log_scale, density.scaled_sum)
    end
    delta = response_view(responses.responses, start:length(responses))
    factors = grid_delta_values(AbilityLogLikelihood(responses.item_bank, delta),
        Integrators.get_grid(tracker.integrator))
    logs = update_grid_buffer!(scratch.log_values, +, density.log_values, factors)
    weights = eltype(logs) === eltype(scratch.weights) ? scratch.weights : similar(logs)
    normalize_grid_weights!(logs, weights)
end

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

    function LogGridIntegrator(integrator::I,
            tracker::T) where {
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
        tracker === nothing &&
            throw(ArgumentError("Supply an equal-weight grid or a LogGridAbilityTracker"))
        integrator = tracker.integrator
    end
    LogGridIntegrator(integrator, tracker)
end

get_integrator(integrator::LogGridIntegrator) = integrator.integrator

function cached_grid_density(::Nothing, est, responses, integrator)
    grid_density(est, responses, integrator)
end

function cached_grid_density(tracker::LogGridAbilityTracker, est, responses, integrator)
    density = speculative_density(tracker, responses.ability_tracker)
    density !== nothing && est === tracker.ability_estimator && return density
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
    denom === nothing && return rett(BareIntegrationResult(value))
    correction = unlog(grid_mass(density) / denom)
    rett(BareIntegrationResult(value * correction))
end

function variance(integrator::LogGridIntegrator{<:ScalarGridIntegrator},
        est::DistributionAbilityEstimator, responses::TrackedResponses, denom = nothing)
    density = grid_density(est, responses, integrator)
    # The public denominator is an absolute mass; the upstream log-state
    # summary accepts a divisor in normalized-weight units.
    divisor = denom === nothing ? nothing : unlog(denom / grid_mass(density))
    if divisor !== nothing && (iszero(divisor) || !isfinite(divisor))
        # A valid absolute denominator can have an unrepresentable ratio to
        # the mass. Preserve the generic log-space expectation scaling then.
        return invoke(variance,
            Tuple{AbilityIntegrator, DistributionAbilityEstimator, TrackedResponses, Any},
            integrator, est, responses, denom)
    end
    weighted_grid_moments(Integrators.get_grid(integrator.integrator), density;
        denominator = divisor).variance
end

function (est::MeanAbilityEstimator{E, I})(::DiscreteIndexableDomain,
        rett::IntReturnType, responses::TrackedResponses) where {E, I <: LogGridIntegrator}
    expectation(rett, IntegralCoeffs.id, 0, est.integrator, est.dist_est, responses)
end

function grid_response_logs(ir, category, grid)
    [FittedItemBanks.log_resp(ir, category, x) for x in grid]
end

function grid_response_logs(ir::ItemResponse{<:TabulatedDichotomousBank}, category, grid)
    grid == FittedItemBanks.item_xs(ir) ||
        throw(ArgumentError("The integration grid must match the tabulated item bank grid"))
    FittedItemBanks.item_log_ys(ir, category)
end

function grid_response_logs(ir::ItemResponse{<:FittedItemBanks.DichotomousPointsItemBank}, category, grid)
    bank = FittedItemBanks.DichotomousPointsWithLogsItemBank(ir.item_bank)
    grid_response_logs(ItemResponse(bank, ir.index), category, grid)
end

function response_expectation(
        est::DistributionAbilityEstimator, integrator::LogGridIntegrator,
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
