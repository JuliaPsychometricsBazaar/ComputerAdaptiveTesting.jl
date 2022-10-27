# TODO: Could probably refactor to be more generic w.r.t. cdf_items.jl

using LinearAlgebra: dot

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

    function CdfMirtItemBank(
        distribution::DistT,
        difficulties::Vector{Float64},
        discriminations::Matrix{Float64},
        labels::MaybeLabels
    ) where {DistT <: ContinuousUnivariateDistribution}
        if size(discriminations, 2) != length(difficulties)
            error(
                "Number of items in first (only) dimension of difficulties " *
                "should match number of item in 2nd dimension of discriminations"
            )
        end
        if labels !== nothing && length(difficulties) !== length(labels)
            error("Labels must have same number of items as difficulties")
        end
        new{typeof(distribution)}(distribution, difficulties, discriminations, labels)
    end
end

MathTraits.DomainType(::CdfMirtItemBank) = VectorContinuousDomain()
Responses.ResponseType(::CdfMirtItemBank) = BooleanResponse()

function raw_difficulty(item_bank::CdfMirtItemBank, item_idx)
    item_bank.difficulties[item_idx]
end

function Base.length(item_bank::CdfMirtItemBank)
    length(item_bank.difficulties)
end

function Base.ndims(item_bank::CdfMirtItemBank)
    size(item_bank.discriminations, 1)
end

function _mirt_norm_abil(θ, difficulty, discrimination)
    #@info "_mirt_norm_abil" θ difficulty discrimination
    dot((θ .- difficulty), discrimination)
end

function norm_abil(ir::ItemResponse{<:CdfMirtItemBank}, θ)
    _mirt_norm_abil(θ, ir.item_bank.difficulties[ir.index], @view ir.item_bank.discriminations[:, ir.index])
end

function (ir::ItemResponse{<:CdfMirtItemBank})(θ)
    resp(ir, θ)
end

function resp_vec(ir::ItemResponse{<:CdfMirtItemBank}, θ)
    resp1 = resp(ir, θ)
    SVector(1.0 - resp1, resp1)
end

function resp(ir::ItemResponse{<:CdfMirtItemBank}, outcome::Bool, θ)
    if outcome
        resp(ir, θ)
    else
        cresp(ir, θ)
    end
end

function resp(ir::ItemResponse{<:CdfMirtItemBank}, θ)
    cdf(ir.item_bank.distribution, norm_abil(ir, θ))
end

function cresp(ir::ItemResponse{<:CdfMirtItemBank}, θ)
    ccdf(ir.item_bank.distribution, norm_abil(ir, θ))
end

function logresp(ir::ItemResponse{<:CdfMirtItemBank}, outcome::Bool, θ)
    if outcome
        logresp(ir, θ)
    else
        logcresp(ir, θ)
    end
end

function logresp(ir::ItemResponse{<:CdfMirtItemBank}, θ)
    logcdf(ir.item_bank.distribution, norm_abil(ir, θ))
end

function logcresp(ir::ItemResponse{<:CdfMirtItemBank}, θ)
    logccdf(ir.item_bank.distribution, norm_abil(ir, θ))
end
