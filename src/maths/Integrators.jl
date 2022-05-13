"""
This module provides a common interface to different integration techniques.
"""
module Integrators

export Integrator, QuadGKIntegrator, FixedGKIntegrator, normdenom

using QuadGK
using QuadGK: cachedrule, evalrule, Segment
using LinearAlgebra: norm
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

end