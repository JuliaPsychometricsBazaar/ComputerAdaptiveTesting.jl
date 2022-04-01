"""
These are helpers for weighting integrals of p.d.f.s for calculating basic
stats.

The main idea of doing it this way is to have a single instance of these to
reuse specializations and to use structs so as to be able to control the
level of specialization.
"""
module IntegralCoeffs

using Distributions: ContinuousUnivariateDistribution, pdf

@inline function one(x_::Float64)::Float64
    1.0
end

@inline function id(x::Float64)::Float64
    x
end

struct SqDev
    center::Float64
end

@inline function (sq_dev::SqDev)(x::Float64)::Float64
    (x - sq_dev.center) ^ 2
end

struct Prior{Dist <: ContinuousUnivariateDistribution}
    dist::Dist
end

struct PriorApply{Dist, F}
    prior::Prior{Dist}
    func::F
end

#function apply_prior{F}(prior::Prior, func: F)::PriorApply where {F}
    #PriorApply(prior, func)
#end

@inline function (prior_apply::PriorApply)(x::Float64)::Float64
    pdf(prior_apply.prior.dist, x) * prior_apply.func(x)
end

end