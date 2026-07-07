# Ability estimators come in two flavours:
#   * `DistributionAbilityEstimator`s produce a (possibly unnormalized)
#     density over ability, via `pdf(est, tracked_responses)`, e.g. the raw
#     likelihood (`LikelihoodAbilityEstimator`) or a Bayesian posterior
#     (`PosteriorAbilityEstimator`).
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
$(TYPEDEF)

The ability likelihood distribution.

    $(FUNCTIONNAME)()
"""
struct LikelihoodAbilityEstimator <: DistributionAbilityEstimator end

function pdf(::LikelihoodAbilityEstimator,
        tracked_responses::TrackedResponses)
    AbilityLikelihood(tracked_responses)
end

function power_summary(io::IO, ::LikelihoodAbilityEstimator)
    println(io, "Ability likelihood distribution")
end

"""
$(TYPEDEF)

Ability posterior distribution: the response likelihood times a `prior`
distribution over ability (a standard normal by default).

    $(FUNCTIONNAME)(; ncomp=0)

Constructs with a standard normal prior (`ncomp=0`) or a `ncomp`-dimensional
standard multivariate normal prior.
"""
struct PosteriorAbilityEstimator{PriorT <: Distribution} <: DistributionAbilityEstimator
    prior::PriorT
end

function PosteriorAbilityEstimator(; ncomp = 0)
    if ncomp == 0
        return PosteriorAbilityEstimator(std_normal)
    else
        return PosteriorAbilityEstimator(std_mv_normal(ncomp))
    end
end

function pdf(est::PosteriorAbilityEstimator,
        tracked_responses::TrackedResponses)
    IntegralCoeffs.PriorApply(IntegralCoeffs.Prior(est.prior),
        AbilityLikelihood(tracked_responses))
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

function SafeLikelihoodAbilityEstimator(args...; kwargs...)
    GuardedAbilityEstimator(
        LikelihoodAbilityEstimator(),
        PosteriorAbilityEstimator(args...),
        multiple_response_types_guard
    )
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
and `AbilityIntegrator` found in `bits`, or builds default ones from the rest
of `bits`.
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
    @requiresome integrator = AbilityIntegrator(bits...)
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
