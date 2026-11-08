const EqualWeightGridIntegrator = Union{FixedGridIntegrator,
    PreallocatedFixedGridIntegrator, Integrators.IterativeFixedGridIntegrator}
const ScalarGridIntegrator = Union{FixedGridIntegrator{<:AbstractVector{Float64}},
    PreallocatedFixedGridIntegrator{<:AbstractVector{Float64}},
    Integrators.IterativeFixedGridIntegrator{<:AbstractVector{Float64}}}
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
    density::Union{Nothing, Vector{Float64}}

    function GriddedAbilityTracker(est::E, integrator::I,
            density::Union{Nothing, Vector{Float64}}) where {
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
    tracker.density = grid_linear_values(pdf(tracker.ability_estimator, responses),
        Integrators.get_grid(tracker.integrator))
    tracker
end

function track_append!(responses::TrackedResponses, tracker::GriddedAbilityTracker)
    responses.speculation_start == 0 || return tracker
    density = tracker.density
    density === nothing && return track!(responses, tracker)
    tracker.density = nothing
    delta = response_view(responses.responses, length(responses):length(responses))
    likelihood = AbilityLikelihood(responses.item_bank, delta)
    density .*= grid_delta_values(likelihood, Integrators.get_grid(tracker.integrator))
    tracker.density = density
    tracker
end

function refresh_after_history_edit!(responses, tracker::GriddedAbilityTracker)
    track!(responses, tracker)
end

function grid_delta_density!(scratch::Vector{Float64}, tracker::GriddedAbilityTracker,
        density, responses, start)
    start > length(responses) && return copyto!(scratch, density)
    delta = response_view(responses.responses, start:length(responses))
    likelihood = AbilityLikelihood(responses.item_bank, delta)
    scratch .= density .* grid_delta_values(likelihood, Integrators.get_grid(tracker.integrator))
end
