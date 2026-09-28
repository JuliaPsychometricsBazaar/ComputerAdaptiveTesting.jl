"""
$(TYPEDEF)

Policy used when constructing an ability-density integrator. See [`LinSpace`](@ref)
and [`LogSpace`](@ref). Explicit `AbilityIntegrator` instances override this default.
"""
abstract type CalculationSpace <: CatConfigBase end

"""
$(TYPEDEF)

Construct ordinary density integrators (the default). This does not change the
meaning of `pdf`/`logpdf`, or log-objective optimization of density modes.
"""
struct LinSpace <: CalculationSpace end

"""
$(TYPEDEF)

Construct integrators using native log densities and stable normalization.
Equal-weight grids use `LogGridIntegrator`; supported continuous backends use
`LogFunctionIntegrator` and require an optimizer for choosing the log scale.
Estimates and normalized moments remain ordinary numbers.
"""
struct LogSpace <: CalculationSpace end

function CalculationSpace(bits...)
    @returnsome find1_instance(CalculationSpace, bits)
    LinSpace()
end

power_summary(io::IO, ::LinSpace) = println(io, "Density integration: linear space")
power_summary(io::IO, ::LogSpace) = println(io, "Density integration: log space")
