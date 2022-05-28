"""
This module provides a common interface to different integration techniques.
"""
module Integrators

export Integrator, QuadGKIntegrator, FixedGKIntegrator
export HCubatureIntegrator, MultiDimFixedGKIntegrator
export normdenom

using QuadGK
using QuadGK: cachedrule, evalrule, Segment
using HCubature
using LinearAlgebra: norm
using FillArrays
import Base.Iterators

using ..ConfigBase
using ..IntegralCoeffs: one

function fixed_gk(f::F, lo, hi, n) where {F}
    x, w, gw = cachedrule(Float64, n)

    seg = evalrule(f, lo, hi, x, w, gw, norm)
    (seg.I, seg.E)
end

abstract type Integrator end
function Integrator(bits...)
    @returnsome find1_instance(Integrator, bits)
end

function normdenom(integrator::Integrator; lo=integrator.lo, hi=integrator.hi, options...)
    integrator(one; lo=lo, hi=hi, options...)
end

struct QuadGKIntegrator <: Integrator
    lo::Float64
    hi::Float64
    order::Int
end

# This could be unsafe if quadgk performed i/o. It might be wise to switch to
# explicitly passing this through from the caller at some point.
# Just preallocate an arbitrary size for now (easiest, would make more sense to use 'order' somehow but we don't have it)
# It's 24 * 100 * threads bytes, ~10kb for 4 threads
segbufs = [Vector{Segment{Float64, Float64, Float64}}(undef, 100) for _ in Threads.nthreads()]

function (integrator::QuadGKIntegrator)(
    f::F;
    lo=integrator.lo,
    hi=integrator.hi,
    order=integrator.order,
    rtol=1e-4
) where F
    quadgk(f, lo, hi, rtol=rtol, segbuf=segbufs[Threads.threadid()], order=order)[1]
end

struct FixedGKIntegrator <: Integrator
    lo::Float64
    hi::Float64
    order::Int
end

function (integrator::FixedGKIntegrator)(
    f::F;
    lo=integrator.lo,
    hi=integrator.hi,
    order=integrator.order
) where F
    fixed_gk(f, lo, hi, order)[1]
end

struct HCubatureIntegrator <: Integrator
    lo::Vector{Float64}
    hi::Vector{Float64}
end

function (integrator::HCubatureIntegrator)(
    f::F;
    lo=integrator.lo,
    hi=integrator.hi
) where F
    hcubature(f, lo, hi)[1]
end

struct MultiDimFixedGKIntegrator{OrderT <: AbstractVector{Int}} <: Integrator
    lo::Vector{Float64}
    hi::Vector{Float64}
    order::OrderT
end

function MultiDimFixedGKIntegrator(lo, hi)
    MultiDimFixedGKIntegrator(lo, hi, mirtcat_quadpnts(length(lo)))
end

function MultiDimFixedGKIntegrator(lo, hi, order::Int)
    MultiDimFixedGKIntegrator(lo, hi, Fill(order, length(lo)))
end

function (integrator::MultiDimFixedGKIntegrator)(
    f::F;
    lo=integrator.lo,
    hi=integrator.hi,
    order=integrator.order
) where F
    x = Array{Float64}(undef, length(lo))
    function inner(idx)
        function integrate()
            return fixed_gk(inner(idx + 1), lo[idx + 1], hi[idx + 1], order[idx + 1])[1]
        end
        function f1d(x1d)
            x[idx] = x1d
            if idx >= length(lo)
                #@info "Calling f" x
                return f(x)
            else
                return integrate()
            end
        end
        if idx == 0
            return integrate()
        else
            return f1d
        end
    end
    inner(0)
end

# Values from fscore() from mirt/mirtCAT
function mirtcat_quadpnts(nd)
    if nd == 1
        61
    elseif nd == 2
        31
    elseif nd == 3
        15
    elseif nd == 4
        9
    elseif nd == 5
        7
    else
        3
    end
end

end