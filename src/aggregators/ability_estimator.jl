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

struct PriorAbilityEstimator{PriorT <: Distribution} <: DistributionAbilityEstimator
    prior::PriorT
end

function pdf(est::PriorAbilityEstimator,
        tracked_responses::TrackedResponses)
    IntegralCoeffs.PriorApply(IntegralCoeffs.Prior(est.prior),
        AbilityLikelihood(tracked_responses))
end

function expectation(rett::IntReturnType,
        f::F,
        ncomp,
        integrator::AbilityIntegrator,
        est::DistributionAbilityEstimator,
        tracked_responses::TrackedResponses,
        denom = normdenom(rett, integrator, est, tracked_responses)) where {F}
    rett(integrator(f, ncomp, est, tracked_responses)) / denom
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
        criterion.integrator,
        criterion.dist_est,
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

struct ModeAbilityEstimator{
    DistEst <: DistributionAbilityEstimator,
    OptimizerT <: AbilityOptimizer,
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

struct MeanAbilityEstimator{
    DistEst <: DistributionAbilityEstimator,
    IntegratorT <: AbilityIntegrator,
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

function distribution_estimator(dist_est::DistributionAbilityEstimator)::DistributionAbilityEstimator
    dist_est
end

function distribution_estimator(point_est::Union{
        ModeAbilityEstimator,
        MeanAbilityEstimator,
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

function maybe_apply_prior(f::F, est::PriorAbilityEstimator) where {F}
    IntegralCoeffs.PriorApply(IntegralCoeffs.Prior(est.prior), f)
end

function maybe_apply_prior(f::F, ::LikelihoodAbilityEstimator) where {F}
    f
end
