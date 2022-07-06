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
export dim

using ResumableFunctions
using Distributions
#using Distributions: ContinuousUnivariateDistribution, cdf
import ForwardDiff
using ..MathTraits

using ..Responses: Response, BareResponses
using ..IOUtils: get_word_list_idxs

abstract type AbstractItemBank end
const MaybeLabels = Union{Vector{String}, Nothing}

include("./io.jl")
include("./generic.jl")
include("./bootstrapped_items.jl")
include("./gridded_items.jl")
include("./guess_slip_items.jl")
include("./cdf_items.jl")
include("./cdf_mirt_items.jl")
include("./porcelain.jl")

end