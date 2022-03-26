"""
function cb_abil_given_resps(
    cb::F,
    responses::AbstractVector{Response},
    items::AbstractItemBank;
    lo=0.0,
    hi=10.0
) where {F}
    response_values = [r.value > 0 for r in responses]

    cb(lo, any(response_values) ? 0.0 : 1.0)
    for idx in 1:length(items.xs)
        y = prod(
            pick_outcome(irf(items, idx, ), resp.value > 0)
            for resp in responses;
            init=1.0
        )
        cb(items.xs[idx], y)
    end
    cb(hi, all(response_values) ? 1.0 : 0.0)
end
"""