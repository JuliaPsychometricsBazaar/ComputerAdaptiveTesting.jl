# A scan owns its density snapshot and candidate buffers. It is valid for the
# history supplied to init_thread; start a new scan after editing that history.
struct PreparedGridMEPV{G, D, T, S}
    grid::G
    density::D
    theta::T
    scratch::S
end

const GridMEPVCriterion = ExpectationBasedItemCriterion{
    <:PointResponseExpectation{<:MeanAbilityEstimator}, <:AbilityVariance}

function init_thread(criterion::GridMEPVCriterion, history::TrackedResponses)
    prepare_grid_mepv(criterion, history, DomainType(history.item_bank),
        response_delta_style(criterion.criterion.dist_est), criterion.criterion.integrator)
end

prepare_grid_mepv(criterion, history, domain, delta, integrator) = Speculator(history, 1)

# Reuse range coordinates across candidates instead of recomputing them in each
# response and moment loop. Other grid containers retain their representation.
prepare_mepv_grid(grid) = grid
prepare_mepv_grid(grid::AbstractRange) = collect(grid)

function prepare_grid_mepv(criterion, history, ::OneDimContinuousDomain,
        ::MultiplicativeResponseDelta,
        integrator::Union{
            Aggregators.TrackedLikelihoodIntegrator{<:Aggregators.ScalarGridIntegrator},
            LogGridIntegrator{<:Aggregators.ScalarGridIntegrator}})
    coordinates = Integrators.get_grid(get_integrator(integrator))
    bank = history.item_bank
    paired = paired_mepv_bank(bank)
    # Custom banks retain their existing Float64 path. On Float32 grids
    # speculation can accommodate wider responses without rounding them.
    eltype(coordinates) === Float32 && !paired && return Speculator(history, 1)
    grid = prepare_mepv_grid(coordinates)
    density = deepcopy(Aggregators.grid_density(criterion.criterion.dist_est, history, integrator))
    scratch = if paired
        T = candidate_factor_type(density, bank, eltype(grid))
        isconcretetype(T) || return Speculator(history, 1)
        candidate_pair_scratch(density, T)
    else
        candidate_grid_scratch(density, ResponseType(bank))
    end
    theta = criterion.response_expectation.ability_estimator(history)
    PreparedGridMEPV(grid, density, theta, scratch)
end

const PairedMEPVBank = Union{TransferItemBank, SlopeInterceptTransferItemBank,
    CdfMirtItemBank, SlopeInterceptMirtItemBank}
paired_mepv_bank(::AbstractItemBank) = false
paired_mepv_bank(::PairedMEPVBank) = true
paired_mepv_bank(bank::GuessAndSlipItemBank) = paired_mepv_bank(bank.inner_bank)

function candidate_factor_type(density, bank, coordinate_type)
    response_pair = density isa Integrators.LogGridWeights ? log_resp_vec : resp_vec
    # A bank with abstractly typed parameters may vary precision by item.
    # Specialize the buffers only if one factor type covers the entire scan.
    eltype(Base.promote_op(response_pair, ItemResponse{typeof(bank)}, coordinate_type))
end

function candidate_pair_scratch(density::AbstractVector, factor_type)
    T = promote_type(eltype(density), factor_type)
    (similar(density, T), similar(density, T))
end

function candidate_pair_scratch(density::Integrators.LogGridWeights, factor_type)
    T = promote_type(eltype(density.log_values), factor_type)
    template = T === eltype(density.log_values) ? density :
        Integrators.LogGridWeights(T.(density.log_values))
    (deepcopy(template), deepcopy(template))
end

candidate_grid_scratch(density, response_type) = deepcopy(density)

# Native vector log responses preserve both tails for all supported banks.
candidate_grid_scratch(density::Integrators.LogGridWeights, ::BooleanResponse) =
    (deepcopy(density), deepcopy(density))

function candidate_grid_density!(scratch::AbstractVector, density::AbstractVector,
        ir, category, grid)
    @inbounds for j in eachindex(scratch, density, grid)
        scratch[j] = density[j] * resp(ir, category, grid[j])
    end
    scratch
end

function candidate_grid_density!(scratch::Integrators.LogGridWeights,
        density::Integrators.LogGridWeights, ir, category, grid)
    @inbounds for j in eachindex(grid, scratch.log_values, density.log_values)
        scratch.log_values[j] = density.log_values[j] + log_resp(ir, category, grid[j])
    end
    Integrators.normalize_grid_weights!(scratch.log_values, scratch.weights)
end

function compute_criterion(criterion::GridMEPVCriterion, state::PreparedGridMEPV,
        history::TrackedResponses, item_idx)
    ir = ItemResponse(history.item_bank, item_idx)
    candidate_expected_variance(criterion.criterion, state, ir, state.scratch)
end

function candidate_expected_variance(criterion, state, ir, scratch)
    probabilities = resp_vec(ir, state.theta)
    value = zero(state.theta)
    for (probability, category) in zip(probabilities, responses(ir))
        density = candidate_grid_density!(scratch, state.density, ir, category, state.grid)
        value += probability * candidate_grid_variance(criterion, state.grid, density)
    end
    value
end

function candidate_expected_variance(criterion, state, ir,
        scratch::NTuple{2, AbstractVector})
    # Preserve the existing per-outcome Inf convention for zero-mass outcomes.
    # The shared numerical summary deliberately rejects zero-mass channels.
    criterion.skip_zero && return candidate_expected_variance(criterion, state, ir, first(scratch))
    # Prepared buffers are disjoint and equally indexed; these banks return a pair.
    summaries = Integrators.weighted_grid_moments!(x -> resp_vec(ir, x),
        state.grid, state.density, scratch; skip_checks=true)
    probabilities = resp_vec(ir, state.theta)
    probabilities[1] * summaries[1].variance + probabilities[2] * summaries[2].variance
end

function candidate_grid_densities!(scratch::NTuple{2, Integrators.LogGridWeights},
        density::Integrators.LogGridWeights, ir, grid)
    first_logs, second_logs = scratch[1].log_values, scratch[2].log_values
    @inbounds for j in eachindex(grid, first_logs, second_logs, density.log_values)
        logs = log_resp_vec(ir, grid[j])
        first_logs[j] = density.log_values[j] + logs[1]
        second_logs[j] = density.log_values[j] + logs[2]
    end
    map(s -> Integrators.normalize_grid_weights!(s.log_values, s.weights), scratch)
end

function candidate_expected_variance(criterion, state, ir,
        scratch::NTuple{2, Integrators.LogGridWeights})
    densities = candidate_grid_densities!(scratch, state.density, ir, state.grid)
    probabilities = exp.(log_resp_vec(ir, state.theta))
    probabilities[1] * candidate_grid_variance(criterion, state.grid, densities[1]) +
        probabilities[2] * candidate_grid_variance(criterion, state.grid, densities[2])
end

function candidate_grid_variance(criterion, grid, density::AbstractVector)
    criterion.skip_zero && all(iszero, density) && return oftype(float(zero(eltype(density))), Inf)
    Integrators.weighted_grid_moments(grid, density).variance
end

candidate_grid_variance(criterion, grid, density::Integrators.LogGridWeights) =
    Integrators.weighted_grid_moments(grid, density).variance
