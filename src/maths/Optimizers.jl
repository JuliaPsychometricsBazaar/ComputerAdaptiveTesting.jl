module Optimizers

using Optim

#=
optimize(
    (θ_arr -> -abil_posterior_given_resps(responses, items, first(θ_arr))),
    lo,
    hi,
    NelderMead(),
    Optim.Options(g_tol = OPTIM_TOL)
)[1]
=#

end