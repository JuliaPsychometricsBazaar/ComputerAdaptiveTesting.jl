function slow_int_abil_posterior_given_resps{F}(f::F,
        responses::AbstractVector{Response},
        items::AbstractItemBank;
        lo = 0.0,
        hi = 10.0) where {F}
    quadgk((θ -> f(θ) * abil_posterior_given_resps(responses, items, θ)), lo, hi, int_tol)[1]
end

function slow_max_abil_posterior_given_resps(f::Function,
        responses::AbstractVector{Response},
        items::AbstractItemBank;
        lo = 0.0,
        hi = 10.0)
    optimize((θ_arr -> -abil_posterior_given_resps(responses, items, first(θ_arr))),
        lo,
        hi,
        NelderMead(),
        Optim.Options(g_tol = optim_tol))[1]
end
