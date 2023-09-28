struct FunctionProduct{F, LHF}
    f::F
    lh_function::LHF
end

function (product::FunctionProduct)(x::T) where {T}
    product.f(x) * product.lh_function(x)
end

struct FunctionIntegrator{IntegratorT <: Integrator} <: AbilityIntegrator 
    integrator::IntegratorT
end

function(integrator::FunctionIntegrator{IntegratorT})(
    f::F,
    ncomp,
    lh_function::LHF
) where {F, LHF, IntegratorT}
    # This will allocate without the `moneypatch_broadcast` hack

    # TODO: Make integration range configurable
    # TODO: Make integration technique configurable
    integrator.integrator(FunctionProduct(f, lh_function), ncomp)
end

"""
In case an item bank is enumerable (e.g. GriddedItemBank), then this method
integrates over the ability likihood given a set of responses with a given
coefficient function using a Riemann sum (aka the rectangle rule).
"""
struct RiemannEnumerationIntegrator <: AbilityIntegrator end

function (integrator::RiemannEnumerationIntegrator)(
    f::F,
    ability_likelihood::AbilityLikelihood;
    lo=-6.0,
    hi=6.0,
    irf_states_storage=nothing
) where {F}
    result::Ref{Float64} = Ref(0.0)
    cb_abil_given_resps(ability_likelihood.responses, ability_likelihood.items; lo=lo, hi=hi, irf_states_storage=irf_states_storage) do (x, prob)
        # @inline 
        result[] += f(x) * prob
    end
    result[]
end

function (integrator::AbilityIntegrator)(
    f::F,
    ncomp,
    est,
    tracked_responses::TrackedResponses;
    kwargs...
) where {F}
    integrator(maybe_apply_prior(f, est), ncomp, AbilityLikelihood(tracked_responses); kwargs...)
end
