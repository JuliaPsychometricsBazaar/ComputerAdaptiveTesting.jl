@from "../Responses.jl" using Responses: Response
@from "../maths/IntegralCoeffs.jl" import IntegralCoeffs
using Distributions: ContinuousUnivariateDistribution

"""
Integrate over the ability likihood given a set of responses with a given
coefficient using a Riemann sum (aka the rectangle rule).
"""
function int_abil_lh_given_resps(
    f::F,
    responses::AbstractVector{Response},
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

function integrate(
    f::F,
    est_::LikelihoodAbilityEstimator,
    tracked_responses::TrackedResponses
)::Float64 where {F}
    int_abil_lh_given_resps(
        f,
        tracked_responses.responses,
        tracked_responses.item_bank;
        lo=0.0, hi=10.0, irf_states_storage=nothing
    )
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

function integrate(
    f::F,
    est::PriorAbilityEstimator,
    tracked_responses::TrackedResponses
)::Float64 where {F}
    int_abil_lh_given_resps(
        IntegralCoeffs.PriorApply(est.prior, f),
        tracked_responses.responses,
        tracked_responses.item_bank;
        lo=0.0, hi=10.0, irf_states_storage=nothing
    )
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

struct ModeAbilityEstimator{DistEst <: DistributionAbilityEstimator} <: PointAbilityEstimator
    dist_est::DistEst
end

struct MeanAbilityEstimator{DistEst <: DistributionAbilityEstimator} <: PointAbilityEstimator
    dist_est::DistEst
end

function (est::ModeAbilityEstimator)(tracked_responses::TrackedResponses)
    maximise(IntegralCoeffs.one, est.dist_est, tracked_responses)
end

function (est::MeanAbilityEstimator)(tracked_responses::TrackedResponses)
    integrate(IntegralCoeffs.one, est.dist_est, tracked_responses)
end