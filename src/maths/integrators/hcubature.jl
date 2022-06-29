import HCubature

struct HCubatureIntegrator{KwargsT} <: Integrator
    lo::Vector{Float64}
    hi::Vector{Float64}
    kwargs::KwargsT
end

function HCubatureIntegrator(lo, hi; kwargs...)
    HCubatureIntegrator(lo, hi, kwargs)
end

function (integrator::HCubatureIntegrator)(
    f::F;
    ncomp=1,
    lo=integrator.lo,
    hi=integrator.hi,
    kwargs...
) where F
    ErrorIntegrationResult(HCubature.hcubature(
        f, lo, hi;
        merge(integrator.kwargs, kwargs)...
    )...)
end