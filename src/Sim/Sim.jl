module Sim

using DataFrames: DataFrame
using ElasticArrays
using ElasticArrays: sizehint_lastdim!
using DocStringExtensions
using StatsBase
using FittedItemBanks: AbstractItemBank, ResponseType, ItemResponse, domdims
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.IndentWrappers: indent
using ..ConfigBase
using ..Responses
using ..Rules: CatRules
using ..Aggregators: TrackedResponses,
                     add_response!,
                     get_integrator,
                     Aggregators,
                     AbilityIntegrator,
                     AbilityEstimator,
                     LikelihoodAbilityEstimator,
                     PosteriorAbilityEstimator,
                     ModeAbilityEstimator,
                     MeanAbilityEstimator,
                     LikelihoodAbilityEstimator,
                     RiemannEnumerationIntegrator
using ..NextItemRules: AbilityVariance, compute_criteria, best_item
import Base: show

export CatRecorder, CatRecording
export CatLoop, record!
export RecordedCatLoop
export run_cat, prompt_response, auto_responder

include("./recorder.jl")
include("./loop.jl")
include("./run.jl")
include("./recorded_loop.jl")

end
