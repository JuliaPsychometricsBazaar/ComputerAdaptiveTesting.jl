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
    PreparedGridMEPV(grid, density, theta, deepcopy(density))
end

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
    probabilities = resp_vec(ir, state.theta)
    value = 0.0
    for (probability, category) in zip(probabilities, responses(ir))
        density = candidate_grid_density!(state.scratch, state.density, ir, category, state.grid)
        value += probability * candidate_grid_variance(criterion.criterion, state.grid, density)
    end
    value
end

function candidate_grid_variance(criterion, grid, density::AbstractVector)
    criterion.skip_zero && all(iszero, density) && return Inf
    Integrators.weighted_grid_moments(grid, density).variance
end

candidate_grid_variance(criterion, grid, density::Integrators.LogGridWeights) =
    Integrators.weighted_grid_moments(grid, density).variance
