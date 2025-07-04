struct FunctionProduct{F, LHF}
    f::F
    lh_function::LHF
end

function (product::FunctionProduct)(x::T) where {T}
    return product.f(x) * product.lh_function(x)
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

function (integrator::TrackedLikelihoodIntegrator{IntegratorT})(f::F,
        ncomp) where {F, IntegratorT}
    integrator.integrator(FunctionArgProduct(f), integrator.tracker.cur_ability, ncomp)
end

function (integrator::TrackedLikelihoodIntegrator)(f::F,
        ncomp,
        est,
        tracked_responses::TrackedResponses;
        kwargs...) where {F}
    # No need to apply prior here because it is already applied in the tracker
    integrator(f, ncomp; kwargs...)
end
