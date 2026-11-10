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
    bank = history.item_bank
    density = Aggregators.grid_density(criterion.criterion.dist_est, history, integrator)
    paired = paired_mepv_bank(density, bank)
    T = candidate_weight_type(density, ItemResponse{typeof(bank)}, eltype(grid),
        eltype(history.responses.values), paired)
    scratch = if isconcretetype(T) && T <: Real
        candidate_grid_scratch(density, T, paired)
    elseif paired
        return Speculator(history, 1)
    else
        # Let each outcome determine its own buffer type.
        nothing
    end
    theta = criterion.response_expectation.ability_estimator(history)
    PreparedGridMEPV(grid, deepcopy(density), theta, scratch)
end

const PairedMEPVBank = Union{TransferItemBank, SlopeInterceptTransferItemBank,
    CdfMirtItemBank, SlopeInterceptMirtItemBank}
paired_mepv_bank(::AbstractItemBank) = false
paired_mepv_bank(::PairedMEPVBank) = true
paired_mepv_bank(bank::GuessAndSlipItemBank) = paired_mepv_bank(bank.inner_bank)

paired_mepv_bank(::AbstractVector, bank) = paired_mepv_bank(bank)
paired_mepv_bank(::Integrators.LogGridWeights, bank) = ResponseType(bank) isa BooleanResponse

function candidate_weight_type(::AbstractVector{W}, ::Type{IR},
        ::Type{X}, ::Type{C}, paired) where {W, IR, X, C}
    paired ? Base.promote_op((w, ir, x, i) -> w * resp_vec(ir, x)[i], W, IR, X, Int) :
        Base.promote_op((w, ir, c, x) -> w * resp(ir, c, x), W, IR, C, X)
end

function candidate_weight_type(::Integrators.LogGridWeights{W}, ::Type{IR},
        ::Type{X}, ::Type{C}, paired) where {W, IR, X, C}
    paired ? Base.promote_op((w, ir, x, i) -> w + log_resp_vec(ir, x)[i], W, IR, X, Int) :
        Base.promote_op((w, ir, c, x) -> w + log_resp(ir, c, x), W, IR, C, X)
end

function candidate_grid_scratch(density::AbstractVector, T, paired)
    scratch = similar(density, T)
    paired ? (scratch, similar(scratch)) : scratch
end

function candidate_grid_scratch(density::Integrators.LogGridWeights, T, paired)
    template = T === eltype(density.log_values) ? density :
        Integrators.LogGridWeights(T.(density.log_values))
    scratch = deepcopy(template)
    paired ? (scratch, deepcopy(template)) : scratch
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

function candidate_grid_density!(::Nothing, density::AbstractVector, ir, category, grid)
    density .* resp.(Ref(ir), Ref(category), grid)
end

function candidate_grid_density!(::Nothing, density::Integrators.LogGridWeights, ir, category, grid)
    Integrators.LogGridWeights(density.log_values .+ log_resp.(Ref(ir), Ref(category), grid))
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
