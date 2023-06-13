using HypothesisTests
using EffectSizes

using ComputerAdaptiveTesting.Sim: CatComparison

const tests = [
    UnequalVarianceTTest,
    ExactSignedRankTest,
    SignTest
]

name(typ) = string(Base.typename(typ).wrapper)

function compare(comparison::CatComparison)
    (cat_iters, num_testees) = size(comparison.cat_idxs)
    cat_diffs = abs.(comparison.cat_abilites .- reshape(comparison.true_abilities, 1, :))
    # For now we just take the median of the random differences. There might be a better way of integrating the whole distribution(?)
    # Could we generate a pair for each random sample by duplicating the treatment difference?
    all_rand_diffs = abs.(comparison.rand_abilities .- reshape(comparison.true_abilities, 1, 1, :))
    med_rand_diffs = dropdims(median(all_rand_diffs, dims=1), dims=1)
    @info "compare" size(cat_diffs) size(all_rand_diffs) size(med_rand_diffs)
    cols = Dict(
        "iteration" => Array{Int}(undef, cat_iters),
        "cohens_d" => Array{Float64}(undef, cat_iters),
        [name(test) => Array{Float64}(undef, cat_iters) for test in tests]...
    )
    for iter in 1:cat_iters
        cols["iteration"][iter] = iter
        cols["cohens_d"][iter] = effectsize(CohenD(cat_diffs[iter, :], med_rand_diffs[iter, :]))
        for test in tests
            cols[name(test)][iter] = pvalue(test(cat_diffs[iter, :], med_rand_diffs[iter, :]))
        end
    end
    DataFrame(cols)
end