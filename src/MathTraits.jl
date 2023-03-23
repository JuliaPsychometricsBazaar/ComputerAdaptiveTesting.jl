"""
This module provides some basic traits related to function domains
"""
module MathTraits

export DomainType, DiscreteDomain, ContinuousDomain
export VectorContinuousDomain, OneDimContinuousDomain, DiscreteIterableDomain, DiscreteIndexableDomain

abstract type DomainType end
abstract type DiscreteDomain <: DomainType end
abstract type ContinuousDomain <: DomainType end
struct VectorContinuousDomain <: ContinuousDomain end
struct OneDimContinuousDomain <: ContinuousDomain end
struct DiscreteIndexableDomain <: DiscreteDomain end
struct DiscreteIterableDomain <: DiscreteDomain end
#DomainType(callable) = DomainType(typeof(callable))
#DomainType(callable::Type) = OneDimContinuousDomain() # default

end