using ..Responses: Response
import ..IntegralCoeffs
using ..Integrators: ContinuousDomain, DiscreteIterableDomain, DiscreteIndexableDomain, DomainType, fixed_gk
using Distributions: ContinuousUnivariateDistribution
using QuadGK
using QuadGK: Segment
using HCubature
using Base.Threads

"""
Integrate over the ability likihood given a set of responses with a given
coefficient using a Riemann sum (aka the rectangle rule).
"""
function int_abil_lh_given_resps(
    f::F,
    responses::BareResponses,
    items::AbstractItemBank;
    lo=0.0,
    hi=10.0,
    irf_states_storage=nothing
)::Float64 where {F}
    result::Ref{Float64} = Ref(0.0)
    cb_abil_given_resps(responses, items; lo=lo, hi=hi, irf_states_storage=irf_states_storage) do (x, prob)
        # @inline 
        result[] += f(x) * prob
    end
    result[]
end

"""
Argmax + max over the ability likihood given a set of responses with a given coefficient using exhaustive search.
"""
function max_abil_lh_given_resps(
    f::F,
    responses::AbstractVector{Response},
    items::AbstractItemBank;
    lo=0.0,
    hi=10.0
) where {F}
    cur_argmax::Ref{Float64} = Ref(NaN)
    cur_max::Ref{Float64} = Ref(-Inf)
    cb_abil_given_resps(responses, items; lo=lo, hi=hi) do (x, prob)
        # @inline 
        fprob = f(x) * prob
        if fprob >= cur_max[]
            cur_argmax[] = x
            cur_max[] = fprob
        end
    end
    (cur_argmax[], cur_max[])
end

struct LikelihoodAbilityEstimator <: DistributionAbilityEstimator end

function pdf(
    ::LikelihoodAbilityEstimator,
    tracked_responses::TrackedResponses,
    x::Float64
)::Float64
    ability_lh = AbilityLikelihood(tracked_responses.item_bank, tracked_responses.responses)
    ability_lh(x)
end

function integrate(
    f::F,
    ::LikelihoodAbilityEstimator,
    tracked_responses::TrackedResponses
)::Float64 where {F}
    ability_lh = AbilityLikelihood(tracked_responses.item_bank, tracked_responses.responses)
    integrate(f, ability_lh)
    #=int_abil_lh_given_resps(
        f,
        tracked_responses.responses,
        tracked_responses.item_bank;
        lo=0.0, hi=10.0, irf_states_storage=nothing
    )=#
end

function maximize(
    f::F,
    est_::LikelihoodAbilityEstimator,
    tracked_responses::TrackedResponses
) where {F}
    max_abil_lh_given_resps(
        f,
        tracked_responses.responses,
        tracked_responses.item_bank;
        lo=0.0, hi=10.0,
    )
end

struct PriorAbilityEstimator{PriorT <: ContinuousUnivariateDistribution} <: DistributionAbilityEstimator
    prior::PriorT
end

function pdf(
    est::PriorAbilityEstimator,
    tracked_responses::TrackedResponses,
    x::Float64
)::Float64
    ability_lh = AbilityLikelihood(tracked_responses.item_bank, tracked_responses.responses)
    prior_f = IntegralCoeffs.PriorApply(IntegralCoeffs.Prior(est.prior), ability_lh)
    prior_f(x)
end

function integrate(
    f::F,
    est::PriorAbilityEstimator,
    tracked_responses::TrackedResponses
)::Float64 where {F}
    prior_f = IntegralCoeffs.PriorApply(IntegralCoeffs.Prior(est.prior), f)
    ability_lh = AbilityLikelihood(tracked_responses.item_bank, tracked_responses.responses)
    integrate(prior_f, ability_lh)
end

function integrate(
    f::F,
    lh_function::LikelihoodFunction
)::Float64 where {F}
    integrate(DomainType(lh_function), f, lh_function)
end

# This could be unsafe if quadgk performed i/o. It might be wise to switch to
# explicitly passing this through from the caller at some point.
const quadgk_order = 20
const segbufs = [Vector{Segment{Float64, Float64, Float64}}(undef, quadgk_order - 1) for _ in Threads.nthreads()]

function integrate(
    ::ContinuousDomain,
    f::F,
    lh_function::LikelihoodFunction;
    buf=nothing
)::Float64 where {F}
    # TODO: Make integration range configurable
    # TODO: Make integration technique configurable
    comp_f = let f=f, lh_function=lh_function
        x -> f(x) * lh_function(x)
    end
    segbuf = segbufs[Threads.threadid()]
    quadgk(comp_f, -10.0, 10.0, rtol=1e-4, segbuf=segbuf, order=quadgk_order)[1]
    #fixed_gk(comp_f, -10.0, 10.0, 100)[1]
end

function integrate(
    ::DiscreteIterableDomain,
    f::F,
    lh_function::LikelihoodFunction
)::Float64 where {F}
    error("TODO")
end

function integrate(
    ::DiscreteIndexableDomain,
    f::F,
    lh_function::LikelihoodFunction
)::Float64 where {F}
    error("TODO")
end

function maximize(
    f::F,
    est::PriorAbilityEstimator,
    tracked_responses::TrackedResponses
) where {F}
    max_abil_lh_given_resps(
        IntegralCoeffs.PriorApply(est.prior, f),
        tracked_responses.responses,
        tracked_responses.item_bank;
        lo=0.0, hi=10.0,
    )
end

function expectation(
    f::F,
    est::DistributionAbilityEstimator,
    tracked_responses::TrackedResponses
) where {F}
    expectation(
        f,
        est,
        tracked_responses,
        integrate(IntegralCoeffs.one, est, tracked_responses)
    )
end

function expectation(
    f::F,
    est::DistributionAbilityEstimator,
    tracked_responses::TrackedResponses,
    denom::Float64
) where {F}
    integrate(f, est, tracked_responses) / denom
end

struct ModeAbilityEstimator{DistEst <: DistributionAbilityEstimator} <: PointAbilityEstimator
    dist_est::DistEst
end

struct MeanAbilityEstimator{DistEst <: DistributionAbilityEstimator} <: PointAbilityEstimator
    dist_est::DistEst
end

function distribution_estimator(dist_est::DistributionAbilityEstimator)::DistributionAbilityEstimator
    dist_est
end

function distribution_estimator(point_est::Union{ModeAbilityEstimator, MeanAbilityEstimator})::DistributionAbilityEstimator
    point_est.dist_est
end

function (est::ModeAbilityEstimator)(tracked_responses::TrackedResponses)
    maximise(IntegralCoeffs.one, est.dist_est, tracked_responses)
end

function (est::MeanAbilityEstimator)(tracked_responses::TrackedResponses)
    expectation(IntegralCoeffs.id, est.dist_est, tracked_responses)
end