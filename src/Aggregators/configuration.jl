# Construction dispatch is kept separate from the numerical implementations.
function build_ability_integrator(::LogSpace, backend::EqualWeightGridIntegrator,
        est, bits; prefer_tracked = false)
    LogGridIntegrator(backend)
end

function build_ability_integrator(::LogSpace, backend::ContinuousLogBackend,
        est, bits; prefer_tracked = false)
    optimizer = Optimizer(bits...)
    optimizer === nothing && throw(ArgumentError(
        "Log-space continuous integration requires a maximizing Optimizer config bit"))
    LogFunctionIntegrator(backend, optimizer)
end

function build_ability_integrator(::LogSpace, backend::Integrator,
        est, bits; prefer_tracked = false)
    throw(ArgumentError("No log-space ability integrator supports $(typeof(backend)); supply a supported backend or an explicit AbilityIntegrator"))
end
