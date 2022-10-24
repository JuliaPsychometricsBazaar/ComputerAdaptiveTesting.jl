"""
This module provides abstract and concrete item banks, which store information
about items and their parameters such as difficulty, most typically resulting
from fitting an Item-Response Theory (IRT) model. It includes TrackedResponses,
which can store cumulative results during a test.
"""
module ItemBanks

export ItemResponse, AbstractItemBank, AbilityLikelihood, GuessItemBank
export SlipItemBank, TransferItemBank, raw_difficulty, pick_outcome
export item_idxs, known_item_information, expected_item_information, item_information
export responses_information, pick_resp, pick_logresp
export ItemBank2PL, ItemBank3PL, ItemBank4PL
export ItemBankMirt2PL, ItemBankMirt3PL, ItemBankMirt4PL
export item_params, LikelihoodFunction, dim, resp, logresp
export resp_vec, responses

using LazyStack
using ResumableFunctions
using Distributions
#using Distributions: ContinuousUnivariateDistribution, cdf
import ForwardDiff
using StaticArrays: SVector
using ..MathTraits

using ..Responses

abstract type AbstractItemBank end
const MaybeLabels = Union{Vector{String}, Nothing}

function get_word_list_idxs(word_list, labels)
    word_set = Set(word_list)
    idxs = []
    sizehint!(idxs, length(word_list))
    for (idx, word) in enumerate(labels)
        if !(word in word_set)
            continue
        end
        push!(idxs, idx)
        delete!(word_set, word)
    end
    if length(word_set) > 0
        @warn "Could not find these words in IRF: " * join(word_set, ", ")
    end
    idxs
end

include("./io.jl")
include("./generic.jl")
include("./bootstrapped_items.jl")
include("./gridded_items.jl")
include("./guess_slip_items.jl")
include("./cdf_items.jl")
include("./cdf_mirt_items.jl")
include("./nominal_items.jl")
include("./porcelain.jl")

end