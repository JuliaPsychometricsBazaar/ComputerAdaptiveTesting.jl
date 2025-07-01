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

struct LikelihoodAbilityEstimator <: DistributionAbilityEstimator end

function pdf(::LikelihoodAbilityEstimator,
        tracked_responses::TrackedResponses)
    AbilityLikelihood(tracked_responses)
end

function show(io::IO, ::MIME"text/plain", ability_estimator::LikelihoodAbilityEstimator)
    println(io, "Ability likelihood distribution")
end

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

function show(io::IO, ::MIME"text/plain", ability_estimator::PosteriorAbilityEstimator)
    println(io, "Ability posterior distribution")
    indent_io = indent(io, 2)
    print(indent_io, "Prior: ")
    show(indent_io, MIME("text/plain"), ability_estimator.prior)
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

function show(io::IO, ::MIME"text/plain", ability_estimator::ModeAbilityEstimator)
    println(io, "Estimate ability using its mode")
    indent_io = indent(io, 2)
    show(indent_io, MIME("text/plain"), ability_estimator.dist_est)
    show(indent_io, MIME("text/plain"), ability_estimator.optim)
end

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

function show(io::IO, ::MIME"text/plain", ability_estimator::MeanAbilityEstimator)
    println(io, "Estimate ability using its mean")
    indent_io = indent(io, 2)
    show(indent_io, MIME("text/plain"), ability_estimator.dist_est)
    print(indent_io, "Integrator: ")
    show(indent_io, MIME("text/plain"), ability_estimator.integrator)
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
