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

end