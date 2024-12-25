"""
This module implements the next item selection rules, which form the main part
of CAT.

## Bibliography

[1] Linden, W. J., & Pashley, P. J. (2009). Item selection and ability
estimation in adaptive testing. In Elements of adaptive testing (pp. 3-30).
Springer, New York, NY.
"""
module NextItemRules

using Accessors
using DocStringExtensions
using Reexport
using PsychometricsBazaarBase.Parameters
using LinearAlgebra
using Random

using ..Responses: Response, BareResponses
using ..ConfigBase
using PsychometricsBazaarBase.ConfigTools
using PsychometricsBazaarBase.Integrators: Integrator
using PsychometricsBazaarBase: Integrators
import PsychometricsBazaarBase.IntegralCoeffs
using FittedItemBanks
using FittedItemBanks: item_params
using ..Aggregators
using ..Aggregators: covariance_matrix

using Distributions, Base.Threads, Base.Order, StaticArrays
using ConstructionBase: constructorof
import ForwardDiff

export ExpectationBasedItemCriterion, AbilityVarianceStateCriterion, init_thread
export NextItemRule, ItemStrategyNextItemRule
export UrryItemCriterion, InformationItemCriterion
export RandomNextItemRule
export ExhaustiveSearch
export catr_next_item_aliases
export preallocate
export compute_criteria, compute_criterion, compute_multi_criterion,
       compute_pointwise_criterion
export best_item
export PointResponseExpectation, DistributionResponseExpectation
export MatrixScalarizer, DeterminantScalarizer, TraceScalarizer
export AbilityCovarianceStateMultiCriterion, StateMultiCriterion, ItemMultiCriterion
export InformationMatrixCriteria
export ScalarizedStateCriteron, ScalarizedItemCriteron

# Prelude
include("./prelude/abstract.jl")
include("./prelude/next_item_rule.jl")
include("./prelude/criteria.jl")
include("./prelude/preallocate.jl")

# Selection strategies
include("./strategies/random.jl")
include("./strategies/exhaustive.jl")

# Combinators
include("./combinators/expectation.jl")
include("./combinators/scalarizers.jl")

# Criteria
include("./criteria/item/information_special.jl")
include("./criteria/item/information_support.jl")
include("./criteria/item/information.jl")
include("./criteria/item/urry.jl")
include("./criteria/state/ability_variance.jl")

# Porcelain
include("./porcelain/aliases.jl")

end
