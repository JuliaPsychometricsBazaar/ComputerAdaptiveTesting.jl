"""
This module provides abstract and concrete item banks, which store information
about items and their parameters such as difficulty, most typically resulting
from fitting an Item-Response Theory (IRT) model. It includes TrackedResponses,
which can store cumulative results during a test.
"""
module ItemBanks

export ItemResponse, AbstractItemBank, AbilityLikelihood, GuessItemBank
export SlipItemBank, TransferItemBank, raw_difficulty, pick_outcome
export item_idxs, item_information

using ResumableFunctions
using ..Responses: Response, BareResponses
using ..IOUtils: get_word_list_idxs
import ForwardDiff

abstract type AbstractItemBank end
const MaybeLabels = Union{Vector{String}, Nothing}

include("./io.jl")
include("./generic.jl")
include("./bootstrapped_items.jl")
include("./gridded_items.jl")
include("./guess_slip_items.jl")
include("./transfer_item_bank.jl")
include("./porcelain.jl")

end