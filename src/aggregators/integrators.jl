struct FunctionProduct{F, LHF}
    f::F
    lh_function::LHF
end

function (product::FunctionProduct)(x::T) where {T}
    product.f(x) * product.lh_function(x)
end

struct FunctionArgProduct{F}
    f::F
end

function (product::FunctionArgProduct)(x::A, y::B) where {A, B}
    product.f(x) * y
end

struct TrackedLikelihoodIntegrator{IntegratorT <: Integrator} <: AbilityIntegrator
    integrator::IntegratorT
    tracker::GriddedAbilityTracker
end

function(integrator::TrackedLikelihoodIntegrator{IntegratorT})(
    f::F,
    ncomp
) where {F, IntegratorT}
    integrator.integrator(FunctionArgProduct(f), integrator.tracker.cur_ability, ncomp)
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

function (integrator::Union{RiemannEnumerationIntegrator, FunctionIntegrator})(
    f::F,
    ncomp,
    est,
    tracked_responses::TrackedResponses;
    kwargs...
) where {F}
    integrator(maybe_apply_prior(f, est), ncomp, AbilityLikelihood(tracked_responses); kwargs...)
end

function (integrator::TrackedLikelihoodIntegrator)(
    f::F,
    ncomp,
    est,
    tracked_responses::TrackedResponses;
    kwargs...
) where {F}
    # No need to apply prior here because it is already applied in the tracker
    integrator(f, ncomp; kwargs...)
end
