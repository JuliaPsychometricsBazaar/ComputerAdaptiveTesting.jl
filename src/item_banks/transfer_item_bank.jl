using Distributions: ContinuousUnivariateDistribution, cdf
using QuadGK

struct TransferItemBank{DistT <: ContinuousUnivariateDistribution} <: AbstractItemBank
    distribution::DistT
    difficulties::Vector{Float64}
    discriminations::Vector{Float64}
    labels::MaybeLabels
end

DomainType(::TransferItemBank) = ContinuousDomain

function Base.length(item_bank::TransferItemBank)
    length(item_bank.difficulties)
end

function norm_abil(θ, difficulty, discrimination)
    (θ - difficulty) * discrimination
end

function norm_abil(ir::ItemResponse{<:TransferItemBank}, θ::Float64)::Float64
    norm_abil(θ, ir.item_bank.difficulties[ir.index], ir.item_bank.discriminations[ir.index])
end

function (ir::ItemResponse{<:TransferItemBank})(θ::Float64)::Float64
    cdf(ir.item_bank.distribution, norm_abil(ir, θ))
end

function log_response(ir::ItemResponse{<:TransferItemBank}, θ::Float64)::Float64
    logcdf(ir.item_bank.distribution, norm_abil(ir, θ))
end

#=
"""
Integrate over the ability likihood given a set of responses using QuadGK.
"""
function int_abil_lh_given_resps(
    f::F,
    responses::AbstractVector{Response},
    items::TransferItemBank;
    lo=0.0,
    hi=10.0
)::Float64 where {F}
    quadgk(f(x) * prob), lo, hi)
end

"""
Argmax + max over the ability likihood given a set of responses with a given coefficient using XXX.
"""
function max_abil_lh_given_resps(
    f::F,
    responses::AbstractVector{Response},
    items::TransferItemBank;
    lo=0.0,
    hi=10.0
) where {F}
    cur_argmax::Ref{Float64} = Ref(NaN)
    cur_max::Ref{Float64} = Ref(-Inf)
    cb_abil_given_resps(responses, items; lo=lo, hi=hi) do (x, prob)
        # @inline 
        fprob = f(x) * prob
        if fprob >= cur_max[]
            cur_argmax[] = x
            cur_max[] = fprob
        end
    end
    (cur_argmax[], cur_max[])
end
=#