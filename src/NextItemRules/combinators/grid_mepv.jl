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

function prepare_grid_mepv(criterion, history, ::OneDimContinuousDomain,
        ::MultiplicativeResponseDelta,
        integrator::Union{
            Aggregators.TrackedLikelihoodIntegrator{<:Aggregators.ScalarGridIntegrator},
            LogGridIntegrator{<:Aggregators.ScalarGridIntegrator}})
    grid = Integrators.get_grid(get_integrator(integrator))
    density = deepcopy(Aggregators.grid_density(criterion.criterion.dist_est, history, integrator))
    theta = criterion.response_expectation.ability_estimator(history)
    PreparedGridMEPV(grid, density, theta,
        candidate_grid_scratch(density, ResponseType(history.item_bank)))
end

candidate_grid_scratch(density, response_type) = deepcopy(density)

# The native vector log-response API preserves both tails. The ordinary
# resp_vec API may form 1-p, so linear scans retain separate scalar evaluations.
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
    value = 0.0
    for (probability, category) in zip(probabilities, responses(ir))
        density = candidate_grid_density!(scratch, state.density, ir, category, state.grid)
        value += probability * candidate_grid_variance(criterion, state.grid, density)
    end
    value
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
    criterion.skip_zero && all(iszero, density) && return Inf
    Integrators.weighted_grid_moments(grid, density).variance
end

candidate_grid_variance(criterion, grid, density::Integrators.LogGridWeights) =
    Integrators.weighted_grid_moments(grid, density).variance
