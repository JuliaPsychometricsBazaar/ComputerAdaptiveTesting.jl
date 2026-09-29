# Generic numerical machinery, kept separate from CAT density construction so it
# can move to PsychometricsBazaarBase. Grid points have equal integration weight.
struct LogGridWeights{T <: AbstractFloat}
    log_values::Vector{T}
    weights::Vector{T}
    log_scale::T
    scaled_sum::T
end

function LogGridWeights(log_values::AbstractVector)
    isempty(log_values) && throw(ArgumentError("Cannot normalize an empty grid"))
    logs = float.(collect(log_values))
    all(x -> isfinite(x) || x == -Inf, logs) ||
        throw(DomainError(logs, "Grid log densities must be finite or -Inf"))
    shift = maximum(logs)
    isfinite(shift) || throw(DomainError(shift, "The density has zero mass on the entire grid"))
    weights = exp.(logs .- shift)
    total = sum(weights)
    weights ./= total
    LogGridWeights(logs, weights, shift, total)
end

# Do not form exp(log_values - log_normalizer): adding log(scaled_sum) to
# an extremely large-magnitude shift can lose all the normalization precision.
function weighted_grid_mean(f::F, grid, state::LogGridWeights) where {F}
    length(grid) == length(state.weights) || throw(DimensionMismatch("Grid and weights differ in length"))
    # Zero-mass points may lie outside f's domain. They contribute nothing.
    sum(w * f(x) for (x, w) in zip(grid, state.weights) if !iszero(w))
end

grid_mass(state::LogGridWeights) = exp(ULogarithmic, state.log_scale) * state.scaled_sum

function scale_grid_value(value::Number, state::LogGridWeights)
    Logarithmic(value) * grid_mass(state)
end

scale_grid_value(value::AbstractArray, state::LogGridWeights) =
    map(x -> scale_grid_value(x, state), value)
