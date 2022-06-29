using MonteCarloIntegration

struct MCIVegasIntegrator <: Integrator
    lo::Vector{Float64}
    hi::Vector{Float64}
    kwargs::NamedTuple
end

function MCIVegasIntegrator(lo, hi)
    MCIVegasIntegrator(lo, hi, ())
end

function (integrator::MCIVegasIntegrator)(
    f::F;
    ncomp=1,
    lo=integrator.lo,
    hi=integrator.hi,
    kwargs...
) where F
    ErrorIntegrationResult(vegas(
        f,
        lo,
        hi;
        merge(integrator.kwargs, kwargs)...
    )...)
end