"""
This module provides some basic traits related to function domains
"""
module MathTraits

export DiscreteDomain, ContinuousDomain, DiscreteIterableDomain, DiscreteIndexableDomain, DomainType

abstract type DomainType end
abstract type DiscreteDomain <: DomainType end
DomainType(callable) = DomainType(typeof(callable))
DomainType(callable::Type) = ContinuousDomain() # default
struct VectorContinuousDomain <: DomainType end
struct ContinuousDomain <: DomainType end
struct DiscreteIndexableDomain <: DiscreteDomain end
struct DiscreteIterableDomain <: DiscreteDomain end

end