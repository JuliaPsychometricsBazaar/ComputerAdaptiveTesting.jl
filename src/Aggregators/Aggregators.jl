"""
This module takes care of integrating and optimizing over the ability/difficulty
space. It includes TrackedResponses, which can store cumulative results during a
test.
"""
module Aggregators

using PsychometricsBazaarBase.Parameters
using StaticArrays: SVector
using Distributions: Distribution, Normal, Distributions
using Base.Threads
using ForwardDiff: ForwardDiff
using LogarithmicNumbers: Logarithmic, ULogarithmic

using FittedItemBanks: AbstractItemBank, ContinuousDomain,
                       DichotomousSmoothedItemBank, DiscreteIndexableDomain,
                       DomainType, ItemResponse, OneDimContinuousDomain,
                       PointsItemBank, ResponseType, VectorContinuousDomain,
                       domdims, item_params, resp, resp_vec, responses
using ..Responses
using ..Responses: concrete_response_type, function_xs, function_ys, Responses
using ..ConfigBase
import PsychometricsBazaarBase: power_summary
using PsychometricsBazaarBase.ConfigTools: @requiresome, @returnsome,
                                           find1_instance, find1_type,
                                           find1_type_sloppy
using PsychometricsBazaarBase.Integrators: Integrators,
                                           BareIntegrationResult,
                                           FixedGridIntegrator,
                                           IntReturnType,
                                           IntValue, Integrator,
                                           PreallocatedFixedGridIntegrator,
                                           normdenom
using PsychometricsBazaarBase.Optimizers: OneDimOptimOptimizer, Optimizer, Optimizers
using PsychometricsBazaarBase.ConstDistributions: std_normal, std_mv_normal
using PsychometricsBazaarBase.IndentWrappers: indent
using DocStringExtensions
import Distributions: pdf, logpdf
import Base: show

import FittedItemBanks
import PsychometricsBazaarBase.IntegralCoeffs

export AbilityEstimator, TrackedResponses
export AbilityTracker, NullAbilityTracker, PointAbilityTracker, GriddedAbilityTracker
export ClosedFormNormalAbilityTracker, track!
export response_expectation, expectation, distribution_estimator
export PointAbilityEstimator, PosteriorAbilityEstimator
export SafeLikelihoodAbilityEstimator, LikelihoodAbilityEstimator
export ModeAbilityEstimator, MeanAbilityEstimator
export Speculator, replace_speculation!, normdenom, maybe_tracked_ability_estimate
export AbilityIntegrator, AbilityOptimizer
export FunctionOptimizer, FunctionIntegrator
export DistributionAbilityEstimator
export variance, variance_given_mean, mean_1d
export RiemannEnumerationIntegrator
export get_integrator
export LogGridIntegrator, LogGridAbilityTracker
export LogFunctionIntegrator
export CalculationSpace, LinSpace, LogSpace, calculation_space
# export EnumerationOptimizer

# Basic types
include("./spaces.jl")
# XXX: Does having a common supertype of DistributionAbilityEstimator and PointAbilityEstimator make sense?
abstract type AbilityEstimator <: CatConfigBase end

function AbilityEstimator(bits...; ability_estimator = nothing, ability_tracker = nothing)
    @returnsome ability_estimator
    @returnsome PointAbilityEstimator(bits...)
    @returnsome find1_instance(AbilityEstimator, bits)
    item_bank = find1_type_sloppy(AbstractItemBank, bits)
    if item_bank !== nothing
        @returnsome AbilityEstimator(DomainType(item_bank), bits...)
    end
end
AbilityEstimator(::DomainType) = nothing
function AbilityEstimator(::ContinuousDomain, bits...)
    @returnsome Integrator(bits...) integrator->MeanAbilityEstimator(
        LikelihoodAbilityEstimator(),
        integrator)
end

# Mark as a scalar for broadcasting
Base.broadcastable(ir::AbilityEstimator) = Ref(ir)

abstract type DistributionAbilityEstimator <: AbilityEstimator end
function DistributionAbilityEstimator(bits...)
    @returnsome find1_instance(DistributionAbilityEstimator, bits)
    point_ability_estimator = find1_instance(PointAbilityEstimator, bits)
    if point_ability_estimator !== nothing
        return distribution_estimator(point_ability_estimator)
    end
end

abstract type PointAbilityEstimator <: AbilityEstimator end
function PointAbilityEstimator(bits...)
    @returnsome find1_instance(PointAbilityEstimator, bits)
    @returnsome find1_type(PointAbilityEstimator, bits) typ->typ(bits...)
end

abstract type AbilityTracker <: CatConfigBase end

function AbilityTracker(bits...; integrator = nothing, ability_estimator = nothing)
    @returnsome find1_instance(AbilityTracker, bits)
    estimator = ability_estimator === nothing ? AbilityEstimator(bits...) : ability_estimator
    tracker_type = find1_type(AbilityTracker, bits)
    tracker_type === nothing || return construct_tracker(tracker_type, estimator, integrator, bits)
    if estimator !== nothing && integrator !== nothing
        return default_grid_tracker(calculation_space(distribution_estimator(estimator)),
            distribution_estimator(estimator), integrator)
    end
    NullAbilityTracker()
end

function compatible_tracker(bits...; integrator, ability_estimator, prefer_tracked,
        space = LinSpace())
    tracker = find1_instance(AbilityTracker, bits)
    # An explicitly supplied tracker, including NullAbilityTracker, takes precedence.
    if tracker !== nothing
        return matching_tracker(space, tracker, integrator, ability_estimator)
    end
    requested = find1_type(AbilityTracker, bits)
    @returnsome requested_grid_tracker(requested, ability_estimator, integrator)
    if prefer_tracked && requested === nothing && ability_estimator !== nothing
        return default_grid_tracker(space, ability_estimator, integrator)
    end
    nothing
end

abstract type AbilityIntegrator <: CatConfigBase end
function AbilityIntegrator(bits...; ability_estimator = nothing, prefer_tracked = false)
    @returnsome find1_instance(AbilityIntegrator, bits)
    zero_arg_intergrators = find1_type(RiemannEnumerationIntegrator, bits)
    if (zero_arg_intergrators !== nothing)
        return RiemannEnumerationIntegrator()
    end
    est = ability_estimator === nothing ? DistributionAbilityEstimator(bits...) :
          distribution_estimator(ability_estimator)
    integrator = Integrator(bits...)
    @returnsome inherited_integrator(bits, est, integrator)
    integrator = integrator === nothing ? inherited_backend(bits) : integrator
    if integrator === nothing
        return nothing
    end
    space = est === nothing ? LinSpace() : calculation_space(est)
    build_ability_integrator(space, integrator, est, bits; prefer_tracked)
end

function build_ability_integrator(::LinSpace, integrator, ability_estimator, bits;
        prefer_tracked = false)
    tracker = compatible_tracker(bits...;
        integrator = integrator,
        ability_estimator = ability_estimator,
        prefer_tracked = prefer_tracked)
    if tracker !== nothing
        tracked_integrator(integrator, tracker)
    else
        FunctionIntegrator(integrator)
    end
end

abstract type AbilityOptimizer end
function AbilityOptimizer(bits...; ability_estimator = nothing)
    @returnsome find1_instance(AbilityOptimizer, bits)
    #=zero_arg_optimizers = find1_type(EnumerationOptimizer, bits)
    if (zero_arg_optimizers !== nothing)
        return EnumerationOptimizer()
    end=#
    @returnsome Optimizer(bits...) optimizer->FunctionOptimizer(optimizer)
end

"""
$(TYPEDEF)

Responses to items in `item_bank` (as [`BareResponses`](@ref)), together with
an `ability_tracker` that maintains an incrementally-updated ability estimate
(or distribution) as responses are added. This is the object threaded through
a CAT run and passed to next item rules, termination conditions and ability
estimators.
"""
@with_kw struct TrackedResponses{
    BareResponsesT <: BareResponses,
    ItemBankT <: AbstractItemBank,
    AbilityTrackerT <: AbilityTracker
}
    responses::BareResponsesT
    item_bank::ItemBankT
    ability_tracker::AbilityTrackerT = NullAbilityTracker()
end

function TrackedResponses(responses, item_bank)
    TrackedResponses(responses, item_bank, NullAbilityTracker())
end

# Mark as a scalar for broadcasting
Base.broadcastable(ir::TrackedResponses) = Ref(ir)

function Responses.AbilityLikelihood(tracked_responses::TrackedResponses{
        BareResponsesT,
        ItemBankT,
        AbilityTrackerT
}) where {
        BareResponsesT <: BareResponses,
        ItemBankT <: AbstractItemBank,
        AbilityTrackerT <: AbilityTracker
}
    Responses.AbilityLikelihood{ItemBankT, BareResponsesT}(tracked_responses.item_bank,
        tracked_responses.responses)
end

function Base.length(responses::TrackedResponses)
    length(responses.responses.indices)
end

function Responses.AbilityLogLikelihood(tracked_responses::TrackedResponses)
    AbilityLogLikelihood(AbilityLikelihood(tracked_responses))
end

struct FunctionIntegrator{IntegratorT <: Integrator} <: AbilityIntegrator
    integrator::IntegratorT
end

function get_integrator(integrator::FunctionIntegrator)
    return integrator.integrator
end

function (integrator::FunctionIntegrator{IntegratorT})(f::F,
        ncomp,
        lh_function::LHF) where {F, LHF, IntegratorT}
    # This will allocate without the `moneypatch_broadcast` hack

    # TODO: Make integration range configurable
    # TODO: Make integration technique configurable
    integrator.integrator(FunctionProduct(f, lh_function), ncomp)
end

function power_summary(io::IO, responses::FunctionIntegrator)
    println(io, "Ordinary density integration (linear space)")
    power_summary(indent(io, 2), responses.integrator)
end

# Defaults
const optim_tol = 1e-12
const int_tol = 1e-8

# Includes
include("./riemann.jl")
include("./ability_estimator.jl")
include("./ability_tracker.jl")
include("./tracked.jl")
include("./log_grid_weights.jl")
include("./log_grid.jl")
include("./log_function.jl")
include("./configuration.jl")
include("./optimizers.jl")
include("./speculators.jl")

end
