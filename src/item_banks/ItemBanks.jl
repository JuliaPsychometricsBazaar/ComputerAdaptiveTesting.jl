"""
This module provides abstract and concrete item banks, which store information
about items and their parameters such as difficulty, most typically resulting
from fitting an Item-Response Theory (IRT) model. It includes TrackedResponses,
which can store cumulative results during a test.
"""
module ItemBanks

export ItemResponse, AbilityLikelihood, GuessItemBank, SlipItemBank, TransferItemBank, ItemResponse

using Reexport, FromFile, ResumableFunctions
@from "../Responses.jl" using Responses: Response
@from "../utils.jl" import get_word_list_idxs

abstract type AbstractItemBank end

include("./io.jl")
include("./generic.jl")
include("./bootstrapped_items.jl")
include("./gridded_items.jl")
include("./guess_slip_items.jl")
include("./transfer_item_bank.jl")
include("./porcelain.jl")

end