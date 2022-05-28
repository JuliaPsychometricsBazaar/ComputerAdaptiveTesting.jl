module Optimizers

export Optimizer, OneDimOptimOptimizer, MultiDimOptimOptimizer

using ..ConfigBase

using Optim
using Parameters

abstract type Optimizer end
function Optimizer(bits...)
    @returnsome find1_instance(Optimizer, bits)
end

struct OneDimOptimOptimizer{OptimT <: Optim.AbstractOptimizer} <: Optimizer
    lo::Float64
    hi::Float64
    initial::Float64
    optim::OptimT
    opts::Optim.Options
end

function OneDimOptimOptimizer(lo, hi, optim)
    OneDimOptimOptimizer(lo, hi, lo + (hi - lo) / 2, optim, Optim.Options())
end

function(opt::OneDimOptimOptimizer)(
    f::F;
    lo=opt.lo,
    hi=opt.hi,
    initial=opt.initial,
    optim=opt.optim,
    opts=opt.opts
) where {F}
    Optim.minimizer(optimize(
        θ_arr -> -f(first(θ_arr)),
        lo,
        hi,
        [initial],
        optim,
        opts
    ))[1]
end

struct MultiDimOptimOptimizer{OptimT <: Optim.AbstractOptimizer} <: Optimizer
    lo::Vector{Float64}
    hi::Vector{Float64}
    initial::Vector{Float64}
    optim::OptimT
    opts::Optim.Options
end

function MultiDimOptimOptimizer(lo, hi, optim)
    MultiDimOptimOptimizer(lo, hi, lo + (hi - lo) / 2, optim, Optim.Options())
end

function(opt::MultiDimOptimOptimizer)(
    f::F;
    lo=opt.lo,
    hi=opt.hi,
    initial=opt.initial,
    optim=opt.optim,
    opts=opt.opts
) where {F}
    Optim.minimizer(optimize(
        θ_arr -> -f(θ_arr),
        lo,
        hi,
        initial,
        optim,
        opts
    ))
end

end