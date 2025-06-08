using FittedItemBanks: CdfMirtItemBank,
                       TransferItemBank, GuessAndSlipItemBank
using FittedItemBanks: inner_item_response, norm_abil, irf_size
using StatsFuns: logaddexp

function log_resp_vec(ir::ItemResponse{<:TransferItemBank}, θ)
    nθ = norm_abil(ir, θ)
    return SVector(
        logccdf(ir.item_bank.distribution, nθ),
        logcdf(ir.item_bank.distribution, nθ)
    )
end

function log_resp(ir::ItemResponse{<:TransferItemBank}, resp, θ)
    logcdf(ir.item_bank.distribution, norm_abil(ir, θ))
end

function log_resp_vec(ir::ItemResponse{<:CdfMirtItemBank}, θ)
    nθ = norm_abil(ir, θ)
    SVector(logccdf(ir.item_bank.distribution, nθ),
        logcdf(ir.item_bank.distribution, nθ))
end

function log_resp(ir::ItemResponse{<:CdfMirtItemBank}, val, θ)
    nθ = norm_abil(ir, θ)
    if val
        logcdf(ir.item_bank.distribution, nθ)
    else
        logccdf(ir.item_bank.distribution, nθ)
    end
end

#=
# XXX: Not sure if this is optimal numerically or speed wise -- possibly it
# would be better to just transform to linear space in this case?
@inline function log_transform_irf_y(guess, slip, y)
    # log space version of guess + irf_size(guess, slip) * y
    logaddexp(log(guess), log(irf_size(guess, slip)) + y)
end

@inline function log_transform_irf_y(ir::ItemResponse{<:GuessItemBank}, response, y)
    guess = y_offset(ir.item_bank, ir.index)
    if response
        log_transform_irf_y(guess, 0.0, y)
    else
        log_transform_irf_y(0.0, guess, y)
    end
end

@inline function log_transform_irf_y(ir::ItemResponse{<:SlipItemBank}, response, y)
    slip = y_offset(ir.item_bank, ir.index)
    if response
        log_transform_irf_y(0.0, slip, y)
    else
        log_transform_irf_y(slip, 0.0, y)
    end
end

function log_resp_vec(ir::ItemResponse{<:AnySlipOrGuessItemBank}, θ)
    r = log_resp_vec(inner_item_response(ir), θ)
    SVector(log_transform_irf_y(ir, false, r[1]), log_transform_irf_y(ir, true, r[2]))
end

function log_resp(ir::ItemResponse{<:AnySlipOrGuessItemBank}, val, θ)
    log_transform_irf_y(ir, val, log_resp(inner_item_response(ir), val, θ))
end
=#

log_resp(ir::ItemResponse{<:GuessAndSlipItemBank}, response, θ) = log(resp(ir, response, θ))
log_resp(ir::ItemResponse{<:GuessAndSlipItemBank}, θ) = log(resp(ir, θ))
log_resp_vec(ir::ItemResponse{<:GuessAndSlipItemBank}, θ) = log.(resp_vec(ir, θ))

function vector_hessian(f, x, n)
    out = ForwardDiff.jacobian(x -> ForwardDiff.jacobian(f, x), x)
    return reshape(out, n, n, n)
end

function double_derivative(f, x)
    ForwardDiff.derivative(x -> ForwardDiff.derivative(f, x), x)
end

function expected_item_information(ir::ItemResponse, θ::Number)
    exp_resp = resp_vec(ir, θ)
    d² = double_derivative((θ -> log_resp_vec(ir, θ)), θ)
    -sum(exp_resp .* d²)
end

# TODO: Unclear whether this should be implemented with ExpectationBasedItemCriterion
# TODO: This is not implementing DRule but postposterior DRule
function expected_item_information(ir::ItemResponse, θ::Vector)
    exp_resp = resp_vec(ir, θ)
    n = domdims(ir.item_bank)
    hess = vector_hessian(θ -> log_resp_vec(ir, θ), θ, n)
    return -sum(eachslice(hess, dims=1) .* exp_resp)
end

function known_item_information(ir::ItemResponse, resp_value, θ)
    -ForwardDiff.hessian(θ -> log_resp(ir, resp_value, θ), θ)
end

function responses_information(item_bank::AbstractItemBank, responses::BareResponses, θ)
    d = domdims(item_bank)
    reduce(.+,
        (known_item_information(ItemResponse(item_bank, resp_idx), resp_value > 0, θ)
        for (resp_idx, resp_value)
        in zip(responses.indices, responses.values)); init = zeros(d, d))
end

using ComputerAdaptiveTesting: ItemBanks

function log_resp_vec(ir::ItemResponse{<:ItemBanks.LogItemBank}, θ)
    # XXX: Should not destruct the logarithmic number here
    # Works for now
    log.(resp_vec(ItemBanks.inner_ir(ir), θ))
end

function log_resp(ir::ItemResponse{<:ItemBanks.LogItemBank}, resp, θ)
    log(resp(ItemBanks.inner_ir(ir), resp, θ))
end