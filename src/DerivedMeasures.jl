module DerivedMeasures

using Distributions: pdf

import PsychometricsBazaarBase: power_summary, GridSummary
using ..Aggregators: TrackedResponses,
                     Aggregators,
                     AbilityIntegrator,
                     AbilityOptimizer,
                     AbilityEstimator,
                     ModeAbilityEstimator,
                     MeanAbilityEstimator,
                     LikelihoodAbilityEstimator,
                     DistributionAbilityEstimator,
                     get_integrator,
                     expectation
using FittedItemBanks: domdims
using ..NextItemRules: AbilityVariance, compute_criteria, compute_criterion, best_item
using PsychometricsBazaarBase.Integrators: AnyGridIntegrator, get_grid, normdenom
using PsychometricsBazaarBase.IndentWrappers: indent
using PsychometricsBazaarBase: IntegralCoeffs
using PsychometricsBazaarBase: Differentiation

export PointAndSpreadEstimator, MeanAndStdDevEstimator, LaplaceApproxEstimator, SpreadEstimator

abstract type PointAndSpreadEstimator end

# TODO: These all recalculate everything at the moment, but they should reuse the results generated during the CAT

struct MeanAndStdDevEstimator{
    DistEstT <: DistributionAbilityEstimator,
    IntegratorT <: AbilityIntegrator
} <: PointAndSpreadEstimator
    dist_est::DistEstT
    integrator::IntegratorT
end

MeanAndStdDevEstimator(ability_estimator::MeanAbilityEstimator) = MeanAndStdDevEstimator(ability_estimator.dist_est, ability_estimator.integrator)
MeanAndStdDevEstimator(ability_variance::AbilityVariance) = MeanAndStdDevEstimator(ability_variance.dist_est, ability_variance.integrator)

function (est::MeanAndStdDevEstimator)(tracked_responses::TrackedResponses)
    denom = normdenom(est.integrator,
        est.dist_est,
        tracked_responses)
    mean = expectation(IntegralCoeffs.id,
        domdims(tracked_responses.item_bank),
        est.integrator,
        est.dist_est,
        tracked_responses,
        denom)
    return (
        mean,
        sqrt(expectation(IntegralCoeffs.SqDev(mean),
            domdims(tracked_responses.item_bank),
            est.integrator,
            est.dist_est,
            tracked_responses,
            denom))
    )
end

function power_summary(io::IO, est::MeanAndStdDevEstimator)
    println(io, "Mean and standard deviation estimator")
    indent_io = indent(io, 2)
    power_summary(indent_io, est.dist_est)
    power_summary(indent_io, est.integrator)
end

show(io::IO, ::MIME"text/plain", est::MeanAndStdDevEstimator) = power_summary(io, est)

struct LaplaceApproxEstimator{
    DistEstT <: DistributionAbilityEstimator,
    OptimizerT <: AbilityOptimizer
} <: PointAndSpreadEstimator
    dist_est::DistEstT
    optimizer::OptimizerT
end

LaplaceApproxEstimator(ability_estimator::ModeAbilityEstimator) = LaplaceApproxEstimator(ability_estimator.dist_est, ability_estimator.optim)

function (est::LaplaceApproxEstimator)(tracked_responses::TrackedResponses)
    # TODO: Numerical stability: Should directly access the log-pdf here
    mode = est.optimizer(IntegralCoeffs.one, est.dist_est, tracked_responses)
    return (
        mode,
        -Differentiation.double_derivative((ability -> log(pdf(est.dist_est, tracked_responses, ability))), mode)
    )
end

function power_summary(io::IO, est::LaplaceApproxEstimator)
    println(io, "Laplace approximation based mean and standard deviation estimator")
    indent_io = indent(io, 2)
    power_summary(indent_io, est.dist_est)
    power_summary(indent_io, est.optimizer)
end

struct SpreadEstimator{InnerT <: PointAndSpreadEstimator}
    inner::InnerT
end

function (est::SpreadEstimator)(tracked_responses::TrackedResponses)
    _, stddev = est.inner(tracked_responses)
    return stddev
end

struct DistributionSampler{
    DistEst <: DistributionAbilityEstimator,
    IntegratorT <: AbilityIntegrator,
    ContainerT <: Union{Vector{Float64}, Vector{Vector{Float64}}}
}
    dist_est::DistEst
    integrator::IntegratorT
    points::ContainerT
end

_get_estimator_and_integrator(ability_estimator::MeanAbilityEstimator) = (ability_estimator.dist_est, ability_estimator.integrator)
_get_estimator_and_integrator(ability_variance::AbilityVariance) = (ability_variance.dist_est, ability_variance.integrator)

function DistributionSampler(composite::Union{MeanAbilityEstimator, AbilityVariance}, points=nothing)
    dist_est, integrator = _get_estimator_and_integrator(composite)
    return DistributionSampler(dist_est, integrator, points)
end

function DistributionSampler(dist_est::DistributionAbilityEstimator, integrator::Union{AbilityIntegrator, Nothing}=nothing, points::Nothing=nothing)
    if isnothing(integrator)
        return nothing
    end
    inner_integrator = get_integrator(integrator)
    if !isnothing(points)
        return DistributionSampler(dist_est, integrator, points)
    elseif inner_integrator isa AnyGridIntegrator
        return DistributionSampler(dist_est, integrator, get_grid(inner_integrator))
    else
        return nothing
    end
end

function eachmatcol(xs::AbstractMatrix)
    eachcol(xs)
end

function eachmatcol(xs::AbstractVector)
    xs
end

function (est::DistributionSampler)(tracked_responses::TrackedResponses)
    num = Aggregators.pdf.(
        est.dist_est,
        tracked_responses,
        eachmatcol(est.points)
    )
    denom = normdenom(est.integrator, est.dist_est, tracked_responses)
    return num ./ denom
end

function power_summary(io::IO, est::DistributionSampler)
    println(io, "Distribution sampler")
    indent_io = indent(io, 2)
    power_summary(indent_io, est.dist_est)
    power_summary(indent_io, est.integrator)
    power_summary(indent_io, GridSummary(est.points))
end

end
