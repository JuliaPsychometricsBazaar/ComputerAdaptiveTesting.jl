import ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.ItemBanks
using FittedItemBanks: item_bank_xs
using KernelAbstractions
using KernelAbstractions.Extras.LoopInfo: @unroll

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct KernelAbstractionsExhaustiveSearchConfig{ArgsT} <: NextItemStrategy
    kernel_args::ArgsT

    function KernelAbstractionsExhaustiveSearchConfig(kwargs...)
        return new{typeof(kwargs)}(kwargs)
    end
end


"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct KernelAbstractionsExhaustiveSearch{KernelT} <: NextItemStrategy
    kernel::KernelT
end

function NextItemRules.preallocate(config::KernelAbstractionsExhaustiveSearchConfig)
    return KernelAbstractionsExhaustiveSearch(gridded_point_expected_posterior_variance_kernel_simple(config.kernel_args...))
end

function expected_response(ability, xs, ys)
    start = xs.start
    stop = xs.stop
    lendiv = xs.lendiv
    ability_index = (ability - start)  * (lendiv / (stop - start))
    if isnan(ability_index)
        KernelAbstractions.@print("ability ", ability, "\tstart ", start, "\tstop ", stop, "\tlendiv ", lendiv, "\tability_index", ability_index, "\n")
    end
    index_floor = floor(Int, ability_index)
    index_ceil = index_floor + 1
    if index_floor < 1
        return ys[1]
    elseif index_ceil > length(ys)
        return ys[end]
    else
        # Linear interpolation
        return ys[index_floor] + (ys[index_ceil] - ys[index_floor]) * (ability_index - index_floor)
    end
end

function var(x, w)
    #KernelAbstractions.@print("x ", x, "\tw ", w, "\n")
    mean = zero(eltype(x))
    norm = zero(eltype(x))
    #@unroll
    for i in eachindex(x)
        #KernelAbstractions.@print("i ", i, "\tw[i] ", w[i], "\tx[i]: ", x[i], "\n")
        mean += w[i] * x[i]
        norm += w[i]
    end
    if norm == zero(eltype(x))
        return typemax(eltype(x))
    end
    mean /= norm
    var = zero(eltype(x))
    #@unroll
    for i in eachindex(x)
        dev = (x[i] - mean)
        var += w[i] * dev * dev
    end
    return var / norm
end

# This kernel is parallel across items
# It is not tiled
@kernel inbounds=true function gridded_point_expected_posterior_variance_kernel_simple(
    # The xs from the item bank as a LinRange
    @Const(in_gridded_item_bank_xs),
    # All ys from the item bank
    @Const(in_gridded_item_bank_ys),
    # The evaluated likelihood at the integration points
    @Const(in_likelihood_points),
    # The current point estimate of the ability
    @Const(ability_estimate),
    # The resulting expected posterior variance array
    out_epv
)
    lh_eltype = eltype(in_likelihood_points)
    grid_size = length(in_gridded_item_bank_xs)
    lh_buf = @private lh_eltype grid_size
    #@private item_index
    item_index = @index(Global)
    item_ys = @view in_gridded_item_bank_ys[:, item_index]
    # Step 1: Compute the expected response for the current item
    #KernelAbstractions.@print("ability_estimate", ability_estimate, "\tin_gridded_item_bank_xs ", in_gridded_item_bank_xs, "item_ys", item_ys, "\n")
    response_expectation = expected_response(ability_estimate, in_gridded_item_bank_xs, item_ys)
    # Step 2: Get the variance in the positive response case
    lh_buf .= in_likelihood_points .* item_ys
    #KernelAbstractions.@print("First lh buf")
    #KernelAbstractions.@print("in_gridded_item_bank_xs ", size(in_gridded_item_bank_xs), "\tlh_buf ", size(lh_buf), "\n")
    #KernelAbstractions.@print("\n\n\n")
    KernelAbstractions.@print("in_gridded_item_bank_xs ", in_gridded_item_bank_xs, "\tlh_buf ", lh_buf, "\n")
    pos_exp_var = @inline var(in_gridded_item_bank_xs, lh_buf)
    # Step 3: Get the variance in the negative response case
    lh_buf .= in_likelihood_points .* (one(eltype(item_ys)) .- item_ys)
    #KernelAbstractions.@print("Second lh buf")
    #KernelAbstractions.@print("in_gridded_item_bank_xs ", size(in_gridded_item_bank_xs), "\tlh_buf ", size(lh_buf), "\n")
    #KernelAbstractions.@print("\n\n\n")
    neg_exp_var = @inline var(in_gridded_item_bank_xs, lh_buf)
    # Step 4: Combine the variances using the response expectation
    #KernelAbstractions.@print("item_index ", item_index, "\tresponse_expectation ", response_expectation, "\tneg_exp_var ", neg_exp_var, "\tpos_exp_var ", pos_exp_var, "\n")
    if isinf(pos_exp_var) || isinf(neg_exp_var)
        out_epv[item_index] = typemax(eltype(response_expectation))
    else
        negative_response_expectation = one(eltype(response_expectation)) - response_expectation
        out_epv[item_index] = negative_response_expectation * neg_exp_var + response_expectation * pos_exp_var
    end
end

function (
    rule_config::RuleConfigT where {
        RuleConfigT <: ItemStrategyNextItemRule{
            <: KernelAbstractionsExhaustiveSearchConfig,
            <: PointExpectationBasedItemCriterion{<: PointAbilityEstimator, <: AbilityVarianceStateCriterion}
        }
    }
)(responses, items::DichotomousPointsWithLogsItemBank)
    return preallocate(rule_config)(responses, items)
end

function move(backend, input)
    # TODO replace with adapt(backend, input)
    #out = KernelAbstractions.allocate(backend, eltype(input), size(input))
    out = KernelAbstractions.allocate(backend, Float32, size(input))
    return KernelAbstractions.copyto!(backend, out, input)
end

function linrange_to_float32(input)
    return LinRange(Float32(input.start), Float32(input.stop), input.len)
end

function(
    rule::RuleT where {
        RuleT <: ItemStrategyNextItemRule{
            <: KernelAbstractionsExhaustiveSearch,
            <: PointExpectationBasedItemCriterion{<: PointAbilityEstimator, <: AbilityVarianceStateCriterion}
        }
    }
)(tracked_responses, items::DichotomousPointsWithLogsItemBank{})
    backend = rule.strategy.kernel.backend
    responses = tracked_responses.responses
    #=exp_resp = Aggregators.response_expectation(
        rule,
        tracked_responses,
        item_idx
    )=#

    @info "responses" responses.indices responses.values
    #for item_index in responses.indices
        #@info "ys" items.inner_bank.ys[:, item_index]
    #end
    ability_estimate = rule.criterion.ability_estimator(tracked_responses)
    @info "ability_estimate" rule.criterion.ability_estimator ability_estimate
    in_gridded_item_bank_xs = item_bank_xs(items)
    in_gridded_item_bank_ys = items.inner_bank.ys
    in_gridded_item_bank_log_ys = items.log_ys
    (num_quadrature_points, num_items) = size(in_gridded_item_bank_ys)
    # TODO: This could be handled by TrackedResponses
    log_likelihood_points = reduce(.+,
        (
            @view in_gridded_item_bank_log_ys[Int(resp_value) + 1, :, resp_idx]
            for (resp_idx, resp_value)
            in zip(responses.indices, responses.values)
        );
        init = zeros(eltype(in_gridded_item_bank_log_ys), num_quadrature_points)
    )
    c = maximum(log_likelihood_points)
    log_likelihood_points .-= c
    # TODO: Keep this as logs
    log_likelihood_points = exp.(log_likelihood_points)
    @info "xs" in_gridded_item_bank_xs
    in_gridded_item_bank_xs = linrange_to_float32(in_gridded_item_bank_xs)
    in_gridded_item_bank_ys = move(backend, in_gridded_item_bank_ys)
    log_likelihood_points = move(backend, log_likelihood_points)
    out_epv = KernelAbstractions.zeros(backend, eltype(in_gridded_item_bank_ys), num_items)
    rule.strategy.kernel(
        in_gridded_item_bank_xs,
        in_gridded_item_bank_ys,
        log_likelihood_points,
        ability_estimate,
        out_epv
    )
    synchronize(backend)
    out_epv[responses.indices] .= typemax(eltype(out_epv))
    @info "out_epv" out_epv
    return argmin(out_epv)
end
