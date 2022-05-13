using ..ExtraDistributions: NormalScaledLogistic

function FixedGuessSlipItemBank(guess::Float64, slip::Float64, item_bank)
    FixedSlipItemBank(slip, FixedGuessItemBank(guess, item_bank))
end

function GuessSlipItemBank(guesses::Vector{Float64}, slips::Vector{Float64}, item_bank)
    SlipItemBank(slips, GuessItemBank(guesses, item_bank))
end

# TODO: 1PL

"""
Convenience function to construct an item bank of the standard 2-parameter
logistic single-dimensional IRT model.
"""
function ItemBank2PL(
    difficulties,
    discriminations;
    labels=nothing
)
    TransferItemBank(NormalScaledLogistic(), difficulties, discriminations, labels)
end

"""
Convenience function to construct an item bank of the standard 3-parameter
logistic single-dimensional IRT model.
"""
function ItemBank3PL(
    difficulties,
    discriminations,
    guesses;
    labels=nothing
)
    GuessItemBank(guesses, ItemBank2PL(difficulties, discriminations; labels=labels))
end

"""
Convenience function to construct an item bank of the standard 4-parameter
logistic single-dimensional IRT model.
"""
function ItemBank4PL(
    difficulties,
    discriminations,
    guesses,
    slips;
    labels=nothing
)
    SlipItemBank(slips, ItemBank3PL(difficulties, discriminations, guesses; labels=labels))
end

"""
Convenience function to construct an item bank of the standard 2-parameter
logistic MIRT model.
"""
function ItemBankMirt2PL(
    difficulties,
    discriminations;
    labels=nothing
)
    CdfMirtItemBank(NormalScaledLogistic(), difficulties, discriminations, labels)
end

"""
Convenience function to construct an item bank of the standard 3-parameter
logistic MIRT model.
"""
function ItemBankMirt3PL(
    difficulties,
    discriminations,
    guesses;
    labels=nothing
)
    GuessItemBank(guesses, ItemBankMirt2PL(difficulties, discriminations; labels=labels))
end

"""
Convenience function to construct an item bank of the standard 4-parameter
logistic MIRT model.
"""
function ItemBankMirt4PL(
    difficulties,
    discriminations,
    guesses,
    slips;
    labels=nothing
)
    SlipItemBank(slips, ItemBankMirt3PL(difficulties, discriminations, guesses; labels=labels))
end