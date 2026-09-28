# Construction dispatch is kept separate from the numerical implementations.
function build_ability_integrator(::LogSpace, backend::EqualWeightGridIntegrator,
        est, bits; prefer_tracked = false)
    tracker = compatible_tracker(bits...; integrator = backend,
        ability_estimator = est, prefer_tracked, space = LogSpace())
    LogGridIntegrator(backend, tracker)
end

# Reuse the complete adapter, including its tracker, when inheriting an EAP
# configuration. A different density or explicit backend requests fresh assembly.
function inherited_integrator(bits, est, backend)
    point = find1_instance(MeanAbilityEstimator, bits)
    if point !== nothing && point.dist_est === est &&
            inherited_backend_matches(backend, point.integrator) &&
            inherited_options_match(bits, point.integrator)
        return point.integrator
    end
    nothing
end

function inherited_options_match(bits, integral)
    tracker = find1_instance(AbilityTracker, bits)
    tracker_matches(tracker, inherited_tracker(integral)) &&
        inherited_optimizer_matches(bits, integral)
end
tracker_matches(::Nothing, _) = true
tracker_matches(::NullAbilityTracker, tracker) = tracker === nothing
tracker_matches(::AbilityTracker, tracker) = true
tracker_matches(requested::Union{GriddedAbilityTracker, LogGridAbilityTracker}, tracker) =
    requested === tracker
inherited_optimizer_matches(bits, ::AbilityIntegrator) = true
function inherited_optimizer_matches(bits, integral::LogFunctionIntegrator)
    optimizer = Optimizer(bits...)
    optimizer === nothing || optimizer === integral.optimizer
end

inherited_backend_matches(::Nothing, ::AbilityIntegrator) = true
inherited_backend_matches(backend::Integrator, integral::AbilityIntegrator) =
    backend === get_integrator(integral)
inherited_backend_matches(::Integrator, ::RiemannEnumerationIntegrator) = false

tracked_integrator(backend, tracker::GriddedAbilityTracker) = TrackedLikelihoodIntegrator(backend, tracker)
tracked_integrator(backend, tracker::LogGridAbilityTracker) = LogGridIntegrator(backend, tracker)

function get_dist_est_and_integrator(bits...)
    @requiresome dist = DistributionAbilityEstimator(bits...)
    @requiresome integral = AbilityIntegrator(bits...; ability_estimator = dist)
    (dist, integral)
end

matching_tracker(::CalculationSpace, ::AbilityTracker, backend, est) = nothing
function matching_tracker(::LinSpace, tracker::GriddedAbilityTracker, backend, est)
    tracker.integrator === backend && tracker.ability_estimator === est ? tracker : nothing
end
function matching_tracker(::LogSpace, tracker::LogGridAbilityTracker, backend, est)
    tracker.integrator === backend && tracker.ability_estimator === est ? tracker : nothing
end

default_grid_tracker(::LinSpace, est, backend) = GriddedAbilityTracker(est, backend)
default_grid_tracker(::LogSpace, est, backend::EqualWeightGridIntegrator) =
    LogGridAbilityTracker(est, backend)
default_grid_tracker(::LogSpace, est, backend::Integrator) =
    throw(ArgumentError("Log-grid tracking requires a supported equal-weight grid"))

requested_grid_tracker(::Nothing, est, backend) = nothing
requested_grid_tracker(::Type{<:AbilityTracker}, est, backend) = nothing
requested_grid_tracker(::Type{<:GriddedAbilityTracker}, est, backend) =
    default_grid_tracker(calculation_space(est), est, backend)
requested_grid_tracker(::Type{<:LogGridAbilityTracker}, est, backend) =
    default_grid_tracker(LogSpace(), est, backend)

construct_tracker(typ, est, backend, bits) = typ(bits...)
construct_tracker(::Type{NullAbilityTracker}, est, backend, bits) = NullAbilityTracker()
construct_tracker(::Type{<:PointAbilityTracker}, est, backend, bits) = PointAbilityTracker(est)
construct_tracker(::Type{ClosedFormNormalAbilityTracker}, est, backend, bits) =
    ClosedFormNormalAbilityTracker(distribution_estimator(est))

function construct_tracker(typ::Union{Type{<:GriddedAbilityTracker}, Type{<:LogGridAbilityTracker}},
        est, backend, bits)
    dist = distribution_estimator(est)
    integral = inherited_integrator(with_estimator_default(bits, est), dist, backend)
    @returnsome inherited_tracker(integral)
    grid = backend === nothing ? Integrator(bits...) : backend
    grid === nothing && throw(ArgumentError("Grid tracking requires a numerical grid config bit"))
    requested_grid_tracker(typ, dist, grid)
end

inherited_tracker(_) = nothing
inherited_tracker(integral::LogGridIntegrator) = integral.tracker
inherited_tracker(integral::TrackedLikelihoodIntegrator) = integral.tracker

# Add inherited defaults without duplicating explicit instances in a config bag.
with_default_bit(bits, ::Type, ::Nothing) = bits
function with_default_bit(bits, typ::Type, value)
    find1_instance(typ, bits) === nothing ? (bits..., value) : bits
end
with_estimator_default(bits, ::Nothing) = bits
with_estimator_default(bits, est::PointAbilityEstimator) =
    with_default_bit(bits, PointAbilityEstimator, est)
with_estimator_default(bits, est::DistributionAbilityEstimator) =
    with_default_bit(bits, DistributionAbilityEstimator, est)
with_estimator_default(bits, est::AbilityEstimator) =
    with_default_bit(bits, AbilityEstimator, est)

function with_ability_defaults(bits; ability_estimator = nothing, ability_tracker = nothing)
    with_tracker_default(with_estimator_default(bits, ability_estimator), ability_tracker)
end

# Absence of an inherited tracker is not an explicit request to disable a cache.
with_tracker_default(bits, ::NullAbilityTracker) = bits
with_tracker_default(bits, tracker) = with_default_bit(bits, AbilityTracker, tracker)

function build_ability_integrator(::LogSpace, backend::ContinuousLogBackend,
        est, bits; prefer_tracked = false)
    optimizer = Optimizer(bits...)
    optimizer = optimizer === nothing ? inherited_reference_optimizer(bits) : optimizer
    optimizer === nothing && throw(ArgumentError(
        "Log-space continuous integration requires a maximizing Optimizer config bit"))
    LogFunctionIntegrator(backend, optimizer)
end

function inherited_backend(bits)
    point = find1_instance(MeanAbilityEstimator, bits)
    point === nothing ? nothing : numerical_backend(point.integrator)
end
numerical_backend(integral::AbilityIntegrator) = get_integrator(integral)
numerical_backend(::RiemannEnumerationIntegrator) = nothing

function inherited_reference_optimizer(bits)
    point = find1_instance(MeanAbilityEstimator, bits)
    point === nothing ? nothing : reference_optimizer(point.integrator)
end
reference_optimizer(::AbilityIntegrator) = nothing
reference_optimizer(integral::LogFunctionIntegrator) = integral.optimizer

function build_ability_integrator(::LogSpace, backend::Integrator,
        est, bits; prefer_tracked = false)
    throw(ArgumentError("No log-space ability integrator supports $(typeof(backend)); supply a supported backend or an explicit AbilityIntegrator"))
end
