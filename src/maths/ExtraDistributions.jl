module ExtraDistributions

using Random: AbstractRNG
using Distributions: Logistic, UnivariateDistribution, Normal, MvNormal, Zeros, ScalMat

using Lazy: @forward

# This seems to be the most commonly found exact value in the wild, see e.g. the
# R package `mirt``
const scaling_factor = 1.702

struct NormalScaledLogistic
    inner::Logistic
    NormalScaledLogistic(μ, σ) = Logistic(μ / scaling_factor, σ / scaling_factor)
end

NormalScaledLogistic() = NormalScaledLogistic(0.0, 1.0)

@forward NormalScaledLogistic.inner (
    sampler, pdf, logpdf, cdf, quantile, minimum, maximum, insupport, mean, var,
    modes, mode, skewness, kurtosis, entropy, mgf, cf
)

const std_normal = Normal()

function std_mv_normal(dim)
    MvNormal(Zeros(dim), ScalMat(dim, 1.0))
end

rand(rng::AbstractRNG, d::UnivariateDistribution) = rand(rng, d.inner)

end