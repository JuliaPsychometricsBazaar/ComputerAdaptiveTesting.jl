# TODO: Could probably refactor to be more generic w.r.t. cdf_items.jl

"""
This item bank corresponds to the most commonly found version of MIRT in the
literature. Its items feature multidimensional discriminations and its learners
multidimensional abilities, but item difficulties are single-dimensional.
"""
struct CdfMirtItemBank{DistT <: ContinuousUnivariateDistribution} <: AbstractItemBank
    distribution::DistT
    difficulties::Vector{Float64}
    discriminations::Matrix{Float64}
    labels::MaybeLabels
end

DomainType(::CdfMirtItemBank) = VectorContinuousDomain()

function raw_difficulty(item_bank::CdfMirtItemBank, item_idx)
    item_bank.difficulties[item_idx]
end

function Base.length(item_bank::CdfMirtItemBank)
    length(item_bank.difficulties)
end

function dim(item_bank::CdfMirtItemBank)
    size(item_bank.discriminations, 1)
end

function _mirt_norm_abil(θ, difficulty, discrimination)
    (θ .- difficulty) .* discrimination
end

function norm_abil(ir::ItemResponse{<:CdfMirtItemBank}, θ)
    _mirt_norm_abil(θ, ir.item_bank.difficulties[ir.index], @view ir.item_bank.discriminations[:, ir.index])
end

function (ir::ItemResponse{<:CdfMirtItemBank})(θ)
    cdf.(Ref(ir.item_bank.distribution), norm_abil(ir, θ))
end

function log_response(ir::ItemResponse{<:CdfMirtItemBank}, θ)
    logcdf.(Ref(ir.item_bank.distribution), norm_abil(ir, θ))
end