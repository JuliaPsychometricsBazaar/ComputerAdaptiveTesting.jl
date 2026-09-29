const ContinuousLogBackend = Union{Integrators.QuadGKIntegrator,
    Integrators.FixedGKIntegrator, Integrators.MultiDimFixedGKIntegrator,
    Integrators.HCubatureIntegrator, Integrators.CubatureIntegrator}

"""
$(TYPEDEF)

Continuous integration of native log ability densities. Construct with
`LogFunctionIntegrator(backend, optimizer)` (config bits in either order), where
`backend` is a `QuadGKIntegrator`, `FixedGKIntegrator`,
`MultiDimFixedGKIntegrator`, `HCubatureIntegrator` or `CubatureIntegrator`, and
`optimizer` is a PsychometricsBazaarBase `Optimizer` that maximizes a function.
The backend retains its integration domain, tolerances and output-shape limits.
Choose an optimizer search domain containing a representative density peak
inside the integration domain.

For each calculation, maximize the estimator's `logpdf` to choose a finite
reference log density `c`, then integrate `f(x) * exp(logpdf(x) - c)`. An
expectation uses the same reference for its numerator and denominator and
cancels the scale before conversion. Raw integrals and `normdenom` retain their
absolute scale as logarithmic numbers, including backend error estimates.
An explicit expectation denominator is an absolute mass, not its logarithm.

`IntValue()` returns ordinary normalized moments. `IntPassthrough()` also
retains the quadrature error estimate; for ratios this uses
`(numerator_error + abs(value) * mass_error) / (mass - mass_error)` when both
integrals supply errors. This is conditional on the backend error estimates,
not a rigorous guarantee. A backend without errors yields a bare result.

Nonfinite reference densities, invalid log-density evaluations, overflow of
the rescaled density, and zero/nonfinite normalization mass raise `DomainError`.
Scaling cannot repair missed peaks, an unsuitable integration domain or a
divergent integral. No density or response-history state is cached. Coefficients
must be defined at the reference point; zero-density quadrature points skip
coefficient evaluation, including for vector and matrix moments.
"""
struct LogFunctionIntegrator{I <: ContinuousLogBackend, O <: Optimizer} <: AbilityIntegrator
    integrator::I
    optimizer::O
end

function LogFunctionIntegrator(bits...)
    @returnsome find1_instance(LogFunctionIntegrator, bits)
    @requiresome integrator = Integrator(bits...)
    @requiresome optimizer = Optimizer(bits...)
    LogFunctionIntegrator(continuous_log_backend(integrator), optimizer)
end

continuous_log_backend(integrator::ContinuousLogBackend) = integrator
continuous_log_backend(::Integrator) =
    throw(ArgumentError("LogFunctionIntegrator requires a supported continuous quadrature backend"))

get_integrator(integrator::LogFunctionIntegrator) = integrator.integrator

function reference_density(integrator::LogFunctionIntegrator, est, responses)
    density = logpdf(est, responses)
    reference = integrator.optimizer(density)
    scale = density(reference)
    isfinite(scale) || throw(DomainError(scale,
        "Log-density optimizer must find a finite reference density"))
    (; density, reference, scale)
end

function scaled_density_value(density, scale, x)
    value = density(x)
    (isfinite(value) || value == -Inf) ||
        throw(DomainError(value, "Log density must be finite or -Inf"))
    weight = exp(value - scale)
    isfinite(weight) || throw(DomainError(weight,
        "Rescaled density overflowed; choose an optimizer that finds a representative peak"))
    weight
end

# Cubature's C-backed entry point requires Function rather than any callable.
struct ScaledAbilityIntegrand{F, D, S, Z} <: Function
    coefficient::F
    density::D
    scale::S
    zero_value::Z
end

function (f::ScaledAbilityIntegrand)(x)
    weight = scaled_density_value(f.density, f.scale, x)
    iszero(weight) ? f.zero_value : f.coefficient(x) * weight
end

# HCubature calls coefficients with static vectors, unlike Optim's ordinary
# vectors. Match that representation when establishing the zero output shape;
# IntegralCoeffs deliberately dispatches on the center's concrete type.
coefficient_reference(::Integrator, reference) = reference
coefficient_reference(::Integrators.HCubatureIntegrator, reference::AbstractVector) =
    SVector{length(reference)}(reference)

function integrate_scaled(integrator::LogFunctionIntegrator, f, ncomp, state)
    product = ScaledAbilityIntegrand(f, state.density, state.scale,
        zero(f(coefficient_reference(integrator.integrator, state.reference))))
    integrator.integrator(product, ncomp)
end

absolute_integral_value(value::Number, scale) = Logarithmic(value) * exp(ULogarithmic, scale)
absolute_integral_value(value::AbstractArray, scale) = map(x -> absolute_integral_value(x, scale), value)

function absolute_integral(result::BareIntegrationResult, scale)
    BareIntegrationResult(absolute_integral_value(Integrators.intval(result), scale))
end

function absolute_integral(result::Integrators.ErrorIntegrationResult, scale)
    Integrators.ErrorIntegrationResult(
        absolute_integral_value(Integrators.intval(result), scale),
        absolute_integral_value(Integrators.interr(result), scale))
end

function scaled_mass(integrator, state)
    result = integrate_scaled(integrator, IntegralCoeffs.one, 0, state)
    mass = Integrators.intval(result)
    (isfinite(mass) && mass > 0) || throw(DomainError(mass,
        "Integrated density must have finite positive mass; check support and quadrature resolution"))
    result
end

function (integrator::LogFunctionIntegrator)(f::F, ncomp,
        est::DistributionAbilityEstimator, responses::TrackedResponses) where {F}
    state = reference_density(integrator, est, responses)
    absolute_integral(integrate_scaled(integrator, f, ncomp, state), state.scale)
end

function Integrators.normdenom(rett::IntReturnType, integrator::LogFunctionIntegrator,
        est::DistributionAbilityEstimator, responses::TrackedResponses)
    state = reference_density(integrator, est, responses)
    rett(absolute_integral(scaled_mass(integrator, state), state.scale))
end

function normalized_integral(numerator, denominator, correction)
    BareIntegrationResult(Integrators.intval(numerator) / Integrators.intval(denominator) * correction)
end

function normalized_integral(numerator::Integrators.ErrorIntegrationResult,
        denominator::Integrators.ErrorIntegrationResult, correction)
    mass, mass_error = Integrators.intval(denominator), Integrators.interr(denominator)
    mass > mass_error || throw(DomainError(mass_error,
        "Normalization error is at least the integrated mass; refine the quadrature"))
    value = Integrators.intval(numerator) / mass
    error = (Integrators.interr(numerator) .+ abs.(value) .* mass_error) / (mass - mass_error)
    Integrators.ErrorIntegrationResult(value * correction, error * abs(correction))
end

function expectation(rett::IntReturnType, f::F, ncomp, integrator::LogFunctionIntegrator,
        est::DistributionAbilityEstimator, responses::TrackedResponses, denom = nothing) where {F}
    state = reference_density(integrator, est, responses)
    denominator = scaled_mass(integrator, state)
    numerator = integrate_scaled(integrator, f, ncomp, state)
    correction = denom === nothing ? 1.0 :
        unlog(Integrators.intval(absolute_integral(denominator, state.scale)) / denom)
    rett(normalized_integral(numerator, denominator, correction))
end

function response_expectation(est::DistributionAbilityEstimator, integrator::LogFunctionIntegrator,
        tracked_responses::TrackedResponses, item_idx)
    ir = ItemResponse(tracked_responses.item_bank, item_idx)
    map(FittedItemBanks.responses(ir)) do category
        expectation(x -> exp(FittedItemBanks.log_resp(ir, category, x)), 0,
            integrator, est, tracked_responses)
    end
end

function power_summary(io::IO, integrator::LogFunctionIntegrator)
    println(io, "Continuous integration with rescaled log densities")
    power_summary(indent(io, 2), integrator.integrator)
    power_summary(indent(io, 2), FunctionOptimizer(integrator.optimizer))
end
