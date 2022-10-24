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

function ItemBankGPCM2PL(
    discriminations,
    cut_points;
    labels=nothing
)
    GPCMItemBank(discriminations, cut_points, labels)
end

function ItemBankGPCM3PL(
    discriminations,
    cut_points,
    guesses;
    labels=nothing
)
    GuessItemBank(guesses, ItemBankGPCM2PL(discriminations, cut_points; labels=labels))
end

function ItemBankGPCM4PL(
    discriminations,
    cut_points,
    guesses,
    slips;
    labels=nothing
)
    SlipItemBank(slips, ItemBankGPCM3PL(discriminations, cut_points, guesses; labels=labels))
end

abstract type StdModelForm end
struct StdModel2PL <: StdModelForm end
struct StdModel3PL <: StdModelForm end
struct StdModel4PL <: StdModelForm end

struct SimpleItemBankSpec{StdModelT <: StdModelForm, DomainTypeT <: DomainType, ResponseTypeT <: ResponseType}
    model::StdModelT
    domain::DomainTypeT
    response::ResponseTypeT
end

constructor(::SimpleItemBankSpec{StdModel2PL, OneDimContinuousDomain, BooleanResponse}) = ItemBank2PL
constructor(::SimpleItemBankSpec{StdModel3PL, OneDimContinuousDomain, BooleanResponse}) = ItemBank3PL
constructor(::SimpleItemBankSpec{StdModel4PL, OneDimContinuousDomain, BooleanResponse}) = ItemBank4PL
constructor(::SimpleItemBankSpec{StdModel2PL, VectorContinuousDomain, BooleanResponse}) = ItemBankMirt2PL
constructor(::SimpleItemBankSpec{StdModel3PL, VectorContinuousDomain, BooleanResponse}) = ItemBankMirt3PL
constructor(::SimpleItemBankSpec{StdModel4PL, VectorContinuousDomain, BooleanResponse}) = ItemBankMirt4PL
constructor(::SimpleItemBankSpec{StdModel2PL, ContinuousDomain, MultinomialResponse}) = ItemBankGPCM2PL
constructor(::SimpleItemBankSpec{StdModel3PL, ContinuousDomain, MultinomialResponse}) = ItemBankGPCM3PL
constructor(::SimpleItemBankSpec{StdModel4PL, ContinuousDomain, MultinomialResponse}) = ItemBankGPCM4PL

function ItemBank(spec::SimpleItemBankSpec, args...; kwargs...)
    constructor(spec)(args...; kwargs...)
end