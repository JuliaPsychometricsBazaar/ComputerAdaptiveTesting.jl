"""

"""
module Integrators

abstract type DomainType end
abstract type DiscreteDomain <: DomainType end
DomainType(callable) = DomainType(typeof(callable))
DomainType(callable::Type) = ContinuousDomain() # default
struct ContinuousDomain <: DomainType end
struct DiscreteIndexableDomain <: DiscreteDomain end
struct DiscreteIterableDomain <: DiscreteDomain end

using QuadGK: cachedrule, evalrule
using LinearAlgebra: norm
import Base.Iterators

function fixed_gk(f::F, lo, hi, n) where {F}
    x, w, gw = cachedrule(Float64, n)

    seg = evalrule(f, lo, hi, x, w, gw, norm)
    (seg.I, seg.E)
end

end