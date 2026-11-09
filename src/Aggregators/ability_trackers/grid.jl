const EqualWeightGridIntegrator = Union{FixedGridIntegrator,
    PreallocatedFixedGridIntegrator, Integrators.IterativeFixedGridIntegrator}
const ScalarGrid = Union{AbstractVector{Float32}, AbstractVector{Float64}}
const ScalarGridIntegrator = Union{FixedGridIntegrator{<:ScalarGrid},
    PreallocatedFixedGridIntegrator{<:ScalarGrid},
    Integrators.IterativeFixedGridIntegrator{<:ScalarGrid}}
const TabulatedDichotomousBank = Union{FittedItemBanks.DichotomousPointsItemBank,
    FittedItemBanks.DichotomousPointsWithLogsItemBank}

grid_linear_values(density, grid) = density.(grid)
function grid_linear_values(density::AbilityLikelihood{<:TabulatedDichotomousBank}, grid)
    grid == function_xs(density) ||
        throw(ArgumentError("The integration grid must match the tabulated item bank grid"))
    function_ys(density)
end
function grid_linear_values(density::IntegralCoeffs.PriorApply, grid)
    grid_linear_values(density.func, grid) .* pdf.(Ref(density.prior.dist), grid)
end

# Keep analytic delta evaluation lazy so the tracker can broadcast directly into
# its destination. Tabulated banks require their grid adapter, not pointwise resp.
grid_delta_values(likelihood, grid) = Base.Broadcast.broadcasted(likelihood, grid)
grid_delta_values(likelihood::AbilityLikelihood{<:TabulatedDichotomousBank}, grid) =
    grid_linear_values(likelihood, grid)

"""
$(TYPEDEF)

Cache an unnormalized density on an equal-weight fixed grid. The estimator
must declare `MultiplicativeResponseDelta()` through [`response_delta_style`](@ref).
The density uses the precision of the evaluated prior and responses.
Use Float32 coordinates, prior parameters and a Float32 2PL transfer bank
for Float32 EAP and prepared MEPV. FittedItemBanks 0.7.7 widens Float32
guess/slip responses to Float64.
Appending responses multiplies only their probabilities into `density`;
`track!`, rollback and clearing rebuild the density, including its prior.

The density starts uninitialized. Call `track!` after editing a bare response
history, changing the item bank, grid, or estimator. Mutations through
`TrackedResponses` update the density automatically. A speculator uses its own
stacked density. Concurrent reads must not overlap committed updates.
"""
mutable struct GriddedAbilityTracker{
    AbilityEstimatorT <: DistributionAbilityEstimator,
    IntegratorT <: EqualWeightGridIntegrator
} <: AbilityTracker
    ability_estimator::AbilityEstimatorT
    integrator::IntegratorT
    density::Union{Nothing, Vector}

    function GriddedAbilityTracker(est::E, integrator::I,
            density::Union{Nothing, Vector}) where {
            E <: DistributionAbilityEstimator, I <: EqualWeightGridIntegrator}
        require_response_deltas(est)
        density === nothing || length(density) == length(Integrators.get_grid(integrator)) ||
            throw(DimensionMismatch("Tracker and grid differ in length"))
        new{E, I}(est, integrator, density)
    end
end

function GriddedAbilityTracker(bits...)
    @returnsome find1_instance(GriddedAbilityTracker, bits)
    @requiresome est = DistributionAbilityEstimator(bits...)
    @requiresome integrator = Integrator(bits...)
    GriddedAbilityTracker(est, integrator)
end

function GriddedAbilityTracker(est::DistributionAbilityEstimator, integrator::EqualWeightGridIntegrator)
    GriddedAbilityTracker(est, integrator, nothing)
end

function track!(responses::TrackedResponses, tracker::GriddedAbilityTracker)
    responses.speculation_start == 0 || return tracker
    tracker.density = nothing
    tracker.density = collect(grid_linear_values(pdf(tracker.ability_estimator, responses),
        Integrators.get_grid(tracker.integrator)))
    tracker
end

function track_append!(responses::TrackedResponses, tracker::GriddedAbilityTracker)
    responses.speculation_start == 0 || return tracker
    density = tracker.density
    density === nothing && return track!(responses, tracker)
    tracker.density = nothing
    delta = response_view(responses.responses, length(responses):length(responses))
    likelihood = AbilityLikelihood(responses.item_bank, delta)
    factors = grid_delta_values(likelihood, Integrators.get_grid(tracker.integrator))
    tracker.density = update_grid_buffer!(density, *, density, factors)
    tracker
end

function refresh_after_history_edit!(responses, tracker::GriddedAbilityTracker)
    track!(responses, tracker)
end

# Widen when a response has more precision than the existing buffer. In
# particular, an empty history's density has not seen the bank's response type.
function update_grid_buffer!(buffer, op, density, factors)
    values = Base.Broadcast.broadcasted(op, density, factors)
    if Base.Broadcast.combine_eltypes(values.f, values.args) === eltype(buffer)
        return Base.materialize!(buffer, values)
    end
    Base.materialize(values)
end

copy_grid_buffer!(scratch::Vector{T}, density::Vector{T}) where {T} = copyto!(scratch, density)
copy_grid_buffer!(scratch, density) = copy(density)

function grid_delta_density!(scratch::Vector, tracker::GriddedAbilityTracker,
        density, responses, start)
    start > length(responses) && return copy_grid_buffer!(scratch, density)
    delta = response_view(responses.responses, start:length(responses))
    likelihood = AbilityLikelihood(responses.item_bank, delta)
    factors = grid_delta_values(likelihood, Integrators.get_grid(tracker.integrator))
    update_grid_buffer!(scratch, *, density, factors)
end
