module Sim

using DataFrames: DataFrame
using ElasticArrays
using ElasticArrays: sizehint_lastdim!, resize_lastdim!
using DocStringExtensions
using StatsBase
using FittedItemBanks: AbstractItemBank, ResponseType, ItemResponse, domdims
using PsychometricsBazaarBase: show_into_buf, power_summary_into_buf
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.IndentWrappers: indent
using PsychometricsBazaarBase: GridSummary
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
using ..NextItemRules: AbilityVariance, compute_criteria, compute_criterion, best_item
import Base: show
import PsychometricsBazaarBase: power_summary
using PrettyPrinting
using PrettyTables: fmt__printf
using DataAPI: nrow
using DataFrames: DataFrames

export CatRecorder, CatRecording
export CatLoop, record!
export RecordedCatLoop
export run_cat, prompt_response, auto_responder

include("./recorder.jl")
include("./loop.jl")
include("./run.jl")
include("./recorded_loop.jl")

show(io::IO, ::MIME"text/plain", obj::Union{CatRecorder, CatRecording, RecordedCatLoop}) = power_summary(io, obj)

end
