@from "../maths/ExtraDistributions.jl" using ExtraDistributions: NormalScaledLogistic

function FixedGuessSlipItemBank(guess::Float64, slip::Float64, item_bank)
    FixedSlipItemBank(slip, FixedGuessItemBank(guess, item_bank))
end

function GuessSlipItemBank(guesses::Vector{Float64}, slips::Vector{Float64}, item_bank)
    SlipItemBank(slips, GuessItemBank(guesses, item_bank))
end

# TODO: 1PL

function ItemBank2PL(
    difficulties,
    discriminations
)
    TransferItemBank(NormalScaledLogistic(), difficulties, discriminations)
end

function ItemBank3PL(
    difficulties,
    discriminations,
    guesses
)
    GuessItemBank(guesses, ItemBank2PL(difficulties, discriminations))
end

function ItemBank4PL(
    difficulties,
    discriminations,
    guesses,
    slips
)
    SlipItemBank(slips, ItemBank3PL(difficulties, discriminations, guesses))
end