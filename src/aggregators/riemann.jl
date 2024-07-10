"""
In case an item bank is enumerable (e.g. GriddedItemBank), then this method
integrates over the ability likihood given a set of responses with a given
coefficient function using a Riemann sum (aka the rectangle rule).
"""
struct RiemannEnumerationIntegrator <: AbilityIntegrator end

function (integrator::RiemannEnumerationIntegrator)(f::F,
        ncomp,
        ability_likelihood::AbilityLikelihood{<: DichotomousSmoothedItemBank}) where {F}
    inner_ability_likelihood = AbilityLikelihood(ability_likelihood.item_bank.inner_bank, ability_likelihood.responses)
    return integrator(f, ncomp, inner_ability_likelihood)
end

function (integrator::RiemannEnumerationIntegrator)(f::F,
        ncomp,
        ability_likelihood::AbilityLikelihood{<: PointsItemBank}) where {F}
    @assert ncomp == 0 "RiemannEnumerationIntegrator only supports ncomp = 0"
    result = 0.0
    xs = function_xs(ability_likelihood)
    ys = function_ys(ability_likelihood)
    for (x, y) in zip(xs, ys)
        result += f(x) * y
    end
    return BareIntegrationResult(result)
end

function (integrator::Union{RiemannEnumerationIntegrator, FunctionIntegrator})(f::F,
        ncomp,
        est,
        tracked_responses::TrackedResponses;
        kwargs...) where {F}
    integrator(maybe_apply_prior(f, est),
        ncomp,
        AbilityLikelihood(tracked_responses);
        kwargs...)
end