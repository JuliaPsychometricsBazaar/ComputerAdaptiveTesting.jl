function expected_item_information(ir::ItemResponse, θ::Number)
    exp_resp = resp_vec(ir, θ)
    d² = Differentiation.double_derivative((θ -> log_resp_vec(ir, θ)), θ)
    -sum(exp_resp .* d²)
end

# TODO: Unclear whether this should be implemented with ExpectationBasedItemCriterion
# TODO: This is not implementing DRule but postposterior DRule
function expected_item_information(ir::ItemResponse, θ::Vector)
    exp_resp = resp_vec(ir, θ)
    n = domdims(ir.item_bank)
    hess = Differentiation.vector_hessian(θ -> log_resp_vec(ir, θ), θ, n)
    return -sum(eachslice(hess, dims=1) .* exp_resp)
end

expected_item_information(ir::ItemResponse, _, θ::Vector) = expected_item_information(ir, θ)

function known_item_information(ir::ItemResponse, resp_value, θ)
    -ForwardDiff.hessian(θ -> log_resp(ir, resp_value, θ), θ)
end

function responses_information(item_bank::AbstractItemBank, responses::BareResponses, θ; information_func=known_item_information)
    d = domdims(item_bank)
    reduce(.+,
        (information_func(ItemResponse(item_bank, resp_idx), resp_value > 0, θ)
        for (resp_idx, resp_value)
        in zip(responses.indices, responses.values)); init = zeros(d, d))
end
