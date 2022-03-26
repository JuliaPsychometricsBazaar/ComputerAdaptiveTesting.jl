module ExtraDistributions

using Random: AbstractRNG
using Distributions: Normal, UnivariateDistribution

using Lazy: @forward

struct NormalScaledLogistic
    inner::Normal
    NormalScaledLogistic(μ, σ) = Normal(μ * SCALING_FACTOR, σ * SCALING_FACTOR)
end

NormalScaledLogistic() = NormalScaledLogistic(0.0, 1.0)

# This is the most commonly found value, see e.g. the R package `mirt``
const SCALING_FACTOR = 1.702


@forward NormalScaledLogistic.inner (
    sampler, pdf, logpdf, cdf, quantile, minimum, maximum, insupport, mean, var,
    modes, mode, skewness, kurtosis, entropy, mgf, cf
)

rand(rng::AbstractRNG, d::UnivariateDistribution) = rand(rng, d.inner)

end