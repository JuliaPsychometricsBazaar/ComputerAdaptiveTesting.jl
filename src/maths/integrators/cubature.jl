import Cubature

struct CubatureIntegrator{KwargsT} <: Integrator
    lo::Vector{Float64}
    hi::Vector{Float64}
    kwargs::KwargsT
end

function CubatureIntegrator(lo, hi; kwargs...)
    CubatureIntegrator(lo, hi, kwargs)
end

function (integrator::CubatureIntegrator)(
    f::F,
    ncomp=1,
    lo=integrator.lo,
    hi=integrator.hi;
    kwargs...
) where F
    ErrorIntegrationResult(Cubature.hcubature(
        f, lo, hi;
        merge(integrator.kwargs, kwargs)...
    )...)
end
