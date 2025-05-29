"""
This module implements the next item selection rules, which form the main part
of CAT.

## Bibliography

[1] Linden, W. J., & Pashley, P. J. (2009). Item selection and ability
estimation in adaptive testing. In Elements of adaptive testing (pp. 3-30).
Springer, New York, NY.
"""
module NextItemRules

using DocStringExtensions: FUNCTIONNAME, TYPEDEF, TYPEDFIELDS
using PsychometricsBazaarBase.Parameters: @with_kw
using LinearAlgebra: det, tr
using Random: AbstractRNG, Xoshiro

using ..Responses: BareResponses
using ..ConfigBase
using PsychometricsBazaarBase.ConfigTools: @requiresome, @returnsome,
                                           find1_instance, find1_type
using PsychometricsBazaarBase.Integrators: Integrator
using PsychometricsBazaarBase: Integrators
import PsychometricsBazaarBase.IntegralCoeffs
using FittedItemBanks: AbstractItemBank, DiscreteDomain, DomainType,
                       ItemResponse, OneDimContinuousDomain, domdims, item_params,
                       resp, resp_vec, responses
using ..Aggregators
using ..Aggregators: covariance_matrix

using Distributions: logccdf, logcdf, pdf
using Base.Threads
using Base.Order
using StaticArrays: SVector
using ConstructionBase: constructorof
import ForwardDiff

export ExpectationBasedItemCriterion, AbilityVarianceStateCriterion, init_thread
export NextItemRule, ItemStrategyNextItemRule
export UrryItemCriterion, InformationItemCriterion
export RandomNextItemRule
export PiecewiseNextItemRule, MemoryNextItemRule, FixedFirstItemNextItemRule
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
export DRuleItemCriterion, TRuleItemCriterion

# Prelude
include("./prelude/abstract.jl")
include("./prelude/next_item_rule.jl")
include("./prelude/criteria.jl")
include("./prelude/preallocate.jl")

# Selection strategies
include("./strategies/random.jl")
include("./strategies/sequential.jl")
include("./strategies/exhaustive.jl")

# Combinators
include("./combinators/expectation.jl")
include("./combinators/scalarizers.jl")
include("./combinators/likelihood.jl")

# Criteria
include("./criteria/item/information_special.jl")
include("./criteria/item/information_support.jl")
include("./criteria/item/information.jl")
include("./criteria/item/urry.jl")
include("./criteria/state/ability_variance.jl")
include("./criteria/pointwise/kl.jl")

# Porcelain
include("./porcelain/porcelain.jl")
include("./porcelain/aliases.jl")

end
