using Cuba

abstract type CubaAlgorithm end
struct CubaVegas <: CubaAlgorithm end
struct CubaSuave <: CubaAlgorithm end
struct CubaDivonne <: CubaAlgorithm end
struct CubaCuhre <: CubaAlgorithm end

struct CubaIntegrator{AlgorithmT <: CubaAlgorithm, KwargsT} <: Integrator
    lo::Vector{Float64}
    hi::Vector{Float64}
    algorithm::AlgorithmT
    kwargs::KwargsT
end

function CubaIntegrator(lo, hi, algorithm; kwargs...)
    CubaIntegrator(lo, hi, algorithm, kwargs)
end

get_cuba_integration_func(::CubaVegas) = Cuba.vegas
get_cuba_integration_func(::CubaSuave) = Cuba.suave
get_cuba_integration_func(::CubaDivonne) = Cuba.divonne
get_cuba_integration_func(::CubaCuhre) = Cuba.cuhre
function get_cuba_integration_func(::CubaIntegrator{T}) where {T}
    get_cuba_integration_func(T)
end

struct PreallocatedOutputWrapper{F}
    inner::F
end

function assign_output(r, y::Number)
    r[1] = y
end

function assign_output(r, y::AbstractArray)
    for i in 1:length(r)
        r[i] = y[i]
    end
end

function (wrapper::PreallocatedOutputWrapper)(x, r)
    assign_output(r, wrapper.inner(x))
end

function (integrator::CubaIntegrator)(
    f::F,
    ncomp=0,
    lo=integrator.lo,
    hi=integrator.hi;
    kwargs...
) where F
    # TODO: Move ScaleUnitDomain to CubaIntegrator init
    res = get_cuba_integration_func(integrator.algorithm)(
        PreallocatedOutputWrapper(ScaleUnitDomain(f, lo, hi)),
        length(lo),
        ncomp == 0 ? 1 : ncomp;
        merge(integrator.kwargs, kwargs)...
    )
    # XXX: Should this be specialised?
    # TODO: Use OneDimContinuousDomain
    if ncomp == 0
        val = res.integral[1]
        err = res.error[1]
        ErrorIntegrationResult(val, err)
    else
        ErrorIntegrationResult(res.integral, res.error)
    end
end