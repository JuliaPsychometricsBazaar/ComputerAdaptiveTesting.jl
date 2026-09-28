# Ability estimators come in two flavours:
#   * `DistributionAbilityEstimator`s produce a (possibly unnormalized)
#     density over ability, via `pdf(est, tracked_responses)`, e.g. the raw
#     likelihood (`LikelihoodAbilityEstimator`) or a Bayesian posterior
#     (`PosteriorAbilityEstimator`).
#     `logpdf(est, tracked_responses)` provides the corresponding log density
#     directly, without evaluating the probability-space density first.
#   * `PointAbilityEstimator`s reduce such a distribution to a single ability
#     value when called as `est(tracked_responses)`, either by optimization
#     (`ModeAbilityEstimator`, i.e. MAP/MLE) or by integration
#     (`MeanAbilityEstimator`, i.e. EAP).
# `AbilityTracker`s (see ability_tracker.jl) wrap an estimator to maintain an
# incrementally-updated estimate as responses are added, avoiding
# recomputation from scratch after every response.
#
# Constructors here follow the package-wide "bag of config bits" convention:
# `XAbilityEstimator(bits...)` scans the heterogeneous `bits` arguments (which
# may include other estimators, integrators, optimizers, priors, item banks,
# etc.) via `find1_instance`/`find1_type` and assembles a suitable estimator,
# falling back to sensible defaults (e.g. a standard normal prior) when
# nothing more specific is found.

function Integrators.normdenom(integrator::AbilityIntegrator,
        est::DistributionAbilityEstimator,
        tracked_responses::TrackedResponses)
    normdenom(IntValue(), integrator, est, tracked_responses)
end

function Integrators.normdenom(rett::IntReturnType,
        integrator::AbilityIntegrator,
        est::DistributionAbilityEstimator,
        tracked_responses::TrackedResponses)
    rett(integrator(IntegralCoeffs.one, 0, est, tracked_responses))
end

# This is not type piracy, but maybe a slightly distasteful overload
# TODO: Fix this interface?
function pdf(ability_est::DistributionAbilityEstimator,
        tracked_responses::TrackedResponses,
        x)
    pdf(ability_est, tracked_responses)(x)
end

"""
$(TYPEDSIGNATURES)

Evaluate the unnormalized log density of a distribution ability estimator at
`x`. The two-argument form, `logpdf(est, tracked_responses)`, returns a callable
log-density function instead.

For `LikelihoodAbilityEstimator`, this is the sum of item log probabilities;
for `PosteriorAbilityEstimator`, it additionally includes `logpdf(prior, x)`.
No normalizing constant is subtracted, matching the existing `pdf` convention.
`GuardedAbilityEstimator` selects the same branch as `pdf` when the callable
is constructed. Custom distribution estimators implement the two-argument form;
there is deliberately no fallback through `log(pdf(...))`.
"""
function logpdf(ability_est::DistributionAbilityEstimator,
        tracked_responses::TrackedResponses, x)
    logpdf(ability_est, tracked_responses)(x)
end

"""
$(TYPEDEF)

The ability likelihood distribution. Optional `LinSpace()` (default) or
`LogSpace()` config bits select the default integration policy.

    $(FUNCTIONNAME)(bits...)
"""
struct LikelihoodAbilityEstimator{SpaceT <: CalculationSpace} <: DistributionAbilityEstimator
    space::SpaceT
end

function LikelihoodAbilityEstimator(bits...)
    space = CalculationSpace(bits...)
    LikelihoodAbilityEstimator{typeof(space)}(space)
end

"""
$(SIGNATURES)

Default integration policy for a distribution estimator. Custom estimators
default to `LinSpace()` and may specialize this method. Both `pdf` and `logpdf`
retain their usual meaning regardless of this policy.
"""
calculation_space(::DistributionAbilityEstimator) = LinSpace()
calculation_space(est::LikelihoodAbilityEstimator) = est.space

function pdf(::LikelihoodAbilityEstimator,
        tracked_responses::TrackedResponses)
    AbilityLikelihood(tracked_responses)
end

function logpdf(::LikelihoodAbilityEstimator, tracked_responses::TrackedResponses)
    AbilityLogLikelihood(tracked_responses)
end

function power_summary(io::IO, est::LikelihoodAbilityEstimator)
    println(io, "Ability likelihood distribution")
    power_summary(indent(io, 2), calculation_space(est))
end

"""
$(TYPEDEF)

Ability posterior distribution: the response likelihood times a `prior`
distribution over ability (a standard normal by default).

    $(FUNCTIONNAME)(bits...; ncomp=0)

Accepts a prior distribution and a `LinSpace()` (default) or `LogSpace()` policy
in either order. Without a prior, constructs with a standard normal (`ncomp=0`)
or a `ncomp`-dimensional standard multivariate normal prior. The policy affects
automatic integrator construction, not the meanings of `pdf` and `logpdf`.
"""
struct PosteriorAbilityEstimator{PriorT <: Distribution, SpaceT <: CalculationSpace} <: DistributionAbilityEstimator
    prior::PriorT
    space::SpaceT
end

function PosteriorAbilityEstimator(bits...; ncomp = 0)
    prior = find1_instance(Distribution, bits)
    if prior === nothing
        prior = ncomp == 0 ? std_normal : std_mv_normal(ncomp)
    end
    space = CalculationSpace(bits...)
    PosteriorAbilityEstimator{typeof(prior), typeof(space)}(prior, space)
end

calculation_space(est::PosteriorAbilityEstimator) = est.space

function pdf(est::PosteriorAbilityEstimator,
        tracked_responses::TrackedResponses)
    IntegralCoeffs.PriorApply(IntegralCoeffs.Prior(est.prior),
        AbilityLikelihood(tracked_responses))
end

struct LogPosteriorDensity{PriorT <: Distribution, LikelihoodT <: AbilityLogLikelihood}
    prior::PriorT
    likelihood::LikelihoodT
end

function (density::LogPosteriorDensity)(x)
    logpdf(density.prior, x) + density.likelihood(x)
end

function logpdf(est::PosteriorAbilityEstimator, tracked_responses::TrackedResponses)
    LogPosteriorDensity(est.prior, AbilityLogLikelihood(tracked_responses))
end

function multiple_response_types_guard(tracked_responses)
    if length(tracked_responses.responses.values) == 0
        return false
    end
    seen_value = tracked_responses.responses.values[1]
    for value in tracked_responses.responses.values
        if value !== seen_value
            return true
        end
    end
    return false
end

function power_summary(io::IO, ability_estimator::PosteriorAbilityEstimator)
    println(io, "Ability posterior distribution")
    indent_io = indent(io, 2)
    power_summary(indent_io, calculation_space(ability_estimator))
    print(indent_io, "Prior: ")
    power_summary(indent_io, ability_estimator.prior)
    println(io)
end

struct GuardedAbilityEstimator{T <: DistributionAbilityEstimator, U <: DistributionAbilityEstimator, F} <: DistributionAbilityEstimator
    est::T
    fallback::U
    guard::F
end

function pdf(est::GuardedAbilityEstimator,
        tracked_responses::TrackedResponses)
    if est.guard(tracked_responses)
        return pdf(est.est, tracked_responses)
    else
        return pdf(est.fallback, tracked_responses)
    end
end

function logpdf(est::GuardedAbilityEstimator, tracked_responses::TrackedResponses)
    if est.guard(tracked_responses)
        return logpdf(est.est, tracked_responses)
    else
        return logpdf(est.fallback, tracked_responses)
    end
end

function SafeLikelihoodAbilityEstimator(args...; kwargs...)
    posterior = PosteriorAbilityEstimator(args...; kwargs...)
    GuardedAbilityEstimator(
        LikelihoodAbilityEstimator(calculation_space(posterior)),
        posterior,
        multiple_response_types_guard
    )
end

function calculation_space(est::GuardedAbilityEstimator)
    space = calculation_space(est.est)
    space == calculation_space(est.fallback) ||
        throw(ArgumentError("Guarded estimator branches must agree on the default integration space"))
    space
end

function power_summary(io::IO, est::GuardedAbilityEstimator)
    println(io, "Guarded ability distribution")
    power_summary(indent(io, 2), est.est)
    println(indent(io, 2), "Fallback:")
    power_summary(indent(io, 4), est.fallback)
end

unlog(x) = x
unlog(x::Logarithmic{T}) where {T} = T(x)
unlog(x::ULogarithmic{T}) where {T} = T(x)
unlog(x::AbstractVector{Logarithmic{T}}) where {T} = T.(x)
unlog(x::AbstractVector{ULogarithmic{T}}) where {T} = T.(x)
#=unlog(x::ErrorIntegrationResult{Logarithmic{T}}) where {T} = T(x)
unlog(x::ErrorIntegrationResult{ULogarithmic{T}}) where {T} = T(x)
unlog(x::ErrorIntegrationResult{AbstractVector{Logarithmic{T}}}) where {T} = T.(x)
unlog(x::ErrorIntegrationResult{AbstractVector{ULogarithmic{T}}}) where {T} = T.(x)
=#

function expectation(rett::IntReturnType,
        f::F,
        ncomp,
        integrator::AbilityIntegrator,
        est::DistributionAbilityEstimator,
        tracked_responses::TrackedResponses,
        denom = normdenom(rett, integrator, est, tracked_responses)) where {F}
    unlog(rett(integrator(f, ncomp, est, tracked_responses)) / denom)
end

function expectation(f::F,
        ncomp,
        integrator::AbilityIntegrator,
        est::DistributionAbilityEstimator,
        tracked_responses::TrackedResponses,
        denom...) where {F}
    expectation(IntValue(),
        f,
        ncomp,
        integrator,
        est,
        tracked_responses,
        denom...)
end

function mean_1d(integrator::AbilityIntegrator,
        est::DistributionAbilityEstimator,
        tracked_responses::TrackedResponses,
        denom = normdenom(integrator, est, tracked_responses))
    expectation(IntegralCoeffs.id,
        0,
        integrator,
        est,
        tracked_responses,
        denom)
end

function mean(
        integrator::AbilityIntegrator,
        est::DistributionAbilityEstimator,
        tracked_responses::TrackedResponses,
        denom = normdenom(integrator, est, tracked_responses)
)
    n = domdims(tracked_responses.item_bank)
    expectation(IntegralCoeffs.id,
        n,
        integrator,
        est,
        tracked_responses,
        denom)
end

function variance_given_mean(integrator::AbilityIntegrator,
        est::DistributionAbilityEstimator,
        tracked_responses::TrackedResponses,
        mean,
        denom = normdenom(integrator, est, tracked_responses))
    expectation(IntegralCoeffs.SqDev(mean),
        0,
        integrator,
        est,
        tracked_responses,
        denom)
end

function variance(integrator::AbilityIntegrator,
        est::DistributionAbilityEstimator,
        tracked_responses::TrackedResponses,
        denom = normdenom(integrator, est, tracked_responses))
    variance_given_mean(integrator,
        est,
        tracked_responses,
        mean_1d(integrator, est, tracked_responses, denom),
        denom)
end

function covariance_matrix_given_mean(
        integrator::AbilityIntegrator,
        est::DistributionAbilityEstimator,
        tracked_responses::TrackedResponses,
        mean,
        denom = normdenom(integrator, est, tracked_responses)
)
    n = domdims(tracked_responses.item_bank)
    expectation(IntegralCoeffs.OuterProdDev(mean),
        n,
        integrator,
        est,
        tracked_responses,
        denom)
end

function covariance_matrix(
        integrator::AbilityIntegrator,
        est::DistributionAbilityEstimator,
        tracked_responses::TrackedResponses,
        denom = normdenom(integrator, est, tracked_responses))
    covariance_matrix_given_mean(
        integrator,
        est,
        tracked_responses,
        mean(integrator, est, tracked_responses, denom),
        denom
    )
end

"""
$(TYPEDEF)

Point ability estimate given by the mode of `dist_est` (e.g. MLE for a
[`LikelihoodAbilityEstimator`](@ref) or MAP for a
[`PosteriorAbilityEstimator`](@ref)), found using `optim`.

With `FunctionOptimizer`, maximizes `logpdf(dist_est, tracked_responses)`
directly to avoid likelihood underflow. Custom distribution estimators must
implement the two-argument `logpdf` interface; custom `AbilityOptimizer`s
control their own objective evaluation.

    $(FUNCTIONNAME)(bits...)

Bag-of-config-bits constructor: uses any given `DistributionAbilityEstimator`
and `AbilityOptimizer` found in `bits`, or builds default ones from the rest
of `bits`.
"""
struct ModeAbilityEstimator{
    DistEst <: DistributionAbilityEstimator,
    OptimizerT <: AbilityOptimizer
} <: PointAbilityEstimator
    dist_est::DistEst
    optim::OptimizerT
end

function ModeAbilityEstimator(bits...)
    @returnsome find1_instance(ModeAbilityEstimator, bits)
    @requiresome dist_est = DistributionAbilityEstimator(bits...)
    @requiresome optimizer = AbilityOptimizer(bits...)
    ModeAbilityEstimator(dist_est, optimizer)
end

function power_summary(io::IO, ability_estimator::ModeAbilityEstimator)
    println(io, "Estimate ability using its mode")
    indent_io = indent(io, 2)
    power_summary(indent_io, ability_estimator.dist_est)
    power_summary(indent_io, ability_estimator.optim)
end

"""
$(TYPEDEF)

Point ability estimate given by the mean (EAP) of `dist_est`, computed using
`integrator`.

    $(FUNCTIONNAME)(bits...)

Bag-of-config-bits constructor: uses any given `DistributionAbilityEstimator`
and `AbilityIntegrator` found in `bits`, or adapts a numerical backend using
the distribution's [`calculation_space`](@ref). Explicit ability integrators
override this default. Log-space continuous integration also needs a maximizing
optimizer config bit; grid tracking can be requested with `GriddedAbilityTracker`.
"""
struct MeanAbilityEstimator{
    DistEst <: DistributionAbilityEstimator,
    IntegratorT <: AbilityIntegrator
} <: PointAbilityEstimator
    dist_est::DistEst
    integrator::IntegratorT
end

function MeanAbilityEstimator(bits...)
    @returnsome find1_instance(MeanAbilityEstimator, bits)
    @requiresome dist_est = DistributionAbilityEstimator(bits...)
    @requiresome integrator = AbilityIntegrator(bits...; ability_estimator = dist_est)
    MeanAbilityEstimator(dist_est, integrator)
end

function power_summary(io::IO, ability_estimator::MeanAbilityEstimator)
    println(io, "Estimate ability using its mean")
    indent_io = indent(io, 2)
    power_summary(indent_io, ability_estimator.dist_est)
    print(indent_io, "Integrator: ")
    power_summary(indent_io, ability_estimator.integrator)
end

function distribution_estimator(dist_est::DistributionAbilityEstimator)::DistributionAbilityEstimator
    dist_est
end

function distribution_estimator(point_est::Union{
        ModeAbilityEstimator,
        MeanAbilityEstimator
})::DistributionAbilityEstimator
    point_est.dist_est
end

function (est::ModeAbilityEstimator)(tracked_responses::TrackedResponses)
    est.optim(IntegralCoeffs.one, est.dist_est, tracked_responses)
end

function (est::MeanAbilityEstimator)(tracked_responses::TrackedResponses)
    est(IntValue(), tracked_responses)
end

function (est::MeanAbilityEstimator)(rett::IntReturnType,
        tracked_responses::TrackedResponses)
    est(DomainType(tracked_responses.item_bank), rett, tracked_responses)
end

function (est::MeanAbilityEstimator)(::OneDimContinuousDomain,
        rett::IntReturnType,
        tracked_responses::TrackedResponses)
    expectation(rett, IntegralCoeffs.id, 0, est.integrator, est.dist_est, tracked_responses)
end

function (est::MeanAbilityEstimator)(::VectorContinuousDomain,
        rett::IntReturnType,
        tracked_responses::TrackedResponses)
    expectation(rett,
        IntegralCoeffs.id,
        domdims(tracked_responses.item_bank),
        est.integrator,
        est.dist_est,
        tracked_responses)
end

function (est::MeanAbilityEstimator{AbilityEstimatorT, RiemannEnumerationIntegrator})(
        ::DiscreteIndexableDomain,
        rett::IntReturnType,
        tracked_responses::TrackedResponses) where {AbilityEstimatorT}
    expectation(rett,
        IntegralCoeffs.id,
        domdims(tracked_responses.item_bank),
        est.integrator,
        est.dist_est,
        tracked_responses)
end

function maybe_apply_prior(f::F, est::PosteriorAbilityEstimator) where {F}
    IntegralCoeffs.PriorApply(IntegralCoeffs.Prior(est.prior), f)
end

function maybe_apply_prior(f::F, ::LikelihoodAbilityEstimator) where {F}
    f
end
