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
    grid = prepare_mepv_grid(Integrators.get_grid(get_integrator(integrator)))
    density = deepcopy(Aggregators.grid_density(criterion.criterion.dist_est, history, integrator))
    theta = criterion.response_expectation.ability_estimator(history)
    PreparedGridMEPV(grid, density, theta,
        candidate_grid_scratch(density, ResponseType(history.item_bank), history.item_bank))
end

candidate_grid_scratch(density, response_type) = deepcopy(density)
candidate_grid_scratch(density, response_type, bank) = candidate_grid_scratch(density, response_type)

# Native vector log responses preserve both tails for all supported banks.
struct LogGridMEPVScratch{L, W}
    logs::L
    weights::W
end
candidate_grid_scratch(density::Integrators.LogGridWeights, ::BooleanResponse) =
    LogGridMEPVScratch((similar(density.log_values), similar(density.log_values)),
        (similar(density.weights), similar(density.weights)))

# Only opt into paired ordinary responses where FIB preserves both tails.
# Custom banks retain scalar evaluation: their resp_vec may still form 1-p.
candidate_grid_scratch(density::AbstractVector, ::BooleanResponse, bank) =
    candidate_linear_scratch(density, bank)
candidate_linear_scratch(density, bank::AbstractItemBank) = deepcopy(density)
candidate_linear_scratch(density, bank::Union{TransferItemBank, SlopeInterceptTransferItemBank,
    CdfMirtItemBank, SlopeInterceptMirtItemBank}) = (deepcopy(density), deepcopy(density))
candidate_linear_scratch(density, bank::GuessAndSlipItemBank) =
    candidate_linear_scratch(density, bank.inner_bank)

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
    value = 0.0
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

function candidate_expected_variance(criterion, state, ir,
        scratch::LogGridMEPVScratch)
    log_probabilities = log_resp_vec(ir)
    summaries = Integrators.weighted_log_grid_moments!(log_probabilities,
        state.grid, state.density.log_values,
        scratch.logs, scratch.weights; skip_checks=true)
    probabilities = exp.(log_probabilities(state.theta))
    probabilities[1] * summaries[1].variance + probabilities[2] * summaries[2].variance
end

function candidate_grid_variance(criterion, grid, density::AbstractVector)
    criterion.skip_zero && all(iszero, density) && return Inf
    Integrators.weighted_grid_moments(grid, density).variance
end

candidate_grid_variance(criterion, grid, density::Integrators.LogGridWeights) =
    Integrators.weighted_grid_moments(grid, density).variance
