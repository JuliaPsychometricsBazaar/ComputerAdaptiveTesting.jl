"""
This module provides a common interface to different integration techniques.
"""
module Integrators

export DiscreteDomain, ContinuousDomain, Integrator, QuadGKIntegrator, FixedGKIntegrator, DiscreteIterableDomain, DiscreteIndexableDomain, DomainType

abstract type DomainType end
abstract type DiscreteDomain <: DomainType end
DomainType(callable) = DomainType(typeof(callable))
DomainType(callable::Type) = ContinuousDomain() # default
struct ContinuousDomain <: DomainType end
struct DiscreteIndexableDomain <: DiscreteDomain end
struct DiscreteIterableDomain <: DiscreteDomain end

using QuadGK
using QuadGK: cachedrule, evalrule, Segment
using LinearAlgebra: norm
import Base.Iterators

function fixed_gk(f::F, lo, hi, n) where {F}
    x, w, gw = cachedrule(Float64, n)

    seg = evalrule(f, lo, hi, x, w, gw, norm)
    (seg.I, seg.E)
end

abstract type Integrator end

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

function (integrator::QuadGKIntegrator)(f::F) where F
    quadgk(f, integrator.lo, integrator.hi, rtol=1e-4, segbuf=segbufs[Threads.threadid()], order=integrator.order)[1]
end

struct FixedGKIntegrator <: Integrator
    lo::Float64
    hi::Float64
    order::Int
end

function (integrator::FixedGKIntegrator)(f::F) where F
    fixed_gk(f, integrator.lo, integrator.hi, integrator.order)[1]
end

end