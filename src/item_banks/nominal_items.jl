"""
This item bank implements the nominal model. The Graded Partial Credit Model
(GPCM) is implemented in terms of this one. See:

*A Generalized Partial Credit Model: Application of an EM Algorithm* Eiji Muraki, 1992
Applied Psychological Measurement
10.1177/014662169201600206

Currently, this item bank only supports the normal scaled logistic as the
characteristic/transfer function.
"""
PerCategoryFloat = AbstractArray{<: AbstractArray{Float64}}

struct NominalItemBank{CategoryStorageT <: PerCategoryFloat} <: AbstractItemBank
    ranks::CategoryStorageT # ak_1 ... ak_k
    discriminations::Matrix{Float64} # a_1 ... a_n
    cut_points::CategoryStorageT # d_1 ... d_k
    labels::MaybeLabels
end

function NominalItemBank(ranks::Matrix{Float64}, discriminations::Matrix{Float64}, cut_points::Matrix{Float64, 2}, labels=nothing)
    NominalItemBank(nestedview(ranks), discriminations, nestedview(cut_points), labels)
end

function NominalItemBank(ranks, discriminations::Vector{Float64}, cut_points, labels=nothing)
    NominalItemBank(ranks, reshape(discriminations, 1, :), cut_points, labels)
end

function GPCMItemBank(discriminations, cut_points::PerCategoryFloat, labels=nothing)
    NominalItemBank(
        # XXX: Could probably be more efficient by making this lazy somehow
        [1:length(item_cut_points) for item_cut_points in cut_points],
        discriminations,
        cut_points,
        labels
    )
end

function GPCMItemBank(discriminations, cut_points::Matrix{Float64, 2}, labels=nothing)
    GPCMItemBank(discriminations, nextedview(cut_points), labels)
end

MathTraits.DomainType(::GradedItemBank) = OneDimContinuousDomain()
Responses.ResponseType(::GradedItemBank) = MultinomialResponse()

function raw_difficulty(item_bank::GradedItemBank, item_idx)
    item_bank.difficulties[item_idx]
end

function Base.length(item_bank::GradedItemBank)
    length(item_bank.difficulties)
end

function linears(ir::ItemResponse{<:GradedItemBank}, θ)
    aks = @view ir.item_bank.ranks[ir.index]
    as = @view ir.item_bank.discriminations[:, ir.index]
    ds = @view ir.item_bank.cut_points[ir.index]
    aks .* (dot(as, θ) .+ ds)
end

function (ir::ItemResponse{<:GradedItemBank})(θ)
    resp(ir, θ)
end

function num_response_categories(ir::ItemResponse{<:GradedItemBank})
    length(ir.item_bank.cut_points[ir.index])
end

function resp_vec(ir::ItemResponse{<:TransferItemBank}, θ)
    ir(θ)
end

function resp(ir::ItemResponse{<:GradedItemBank}, θ)
    outs .= exp.(linears(ir, θ))
    outs ./ sum(outs)
end

function logresp(ir::ItemResponse{<:GradedItemBank}, θ)
    outs .= linears(ir, θ)
    outs .= outs - logsumexp(linears(ir, θ))
end

function item_params(item_bank::GradedItemBank, idx)
    (; difficulty=item_bank.difficulties[idx], discrimination=item_bank.discriminations[idx])
end