"""
Typically DistT <: ContinuousUnivariateDistribution
"""
struct TransferItemBank{DistT} <: AbstractItemBank
    distribution::DistT
    difficulties::Vector{Float64}
    discriminations::Vector{Float64}
    labels::MaybeLabels
end

MathTraits.DomainType(::TransferItemBank) = OneDimContinuousDomain()
Responses.ResponseType(::TransferItemBank) = BooleanResponse()

function raw_difficulty(item_bank::TransferItemBank, item_idx)
    item_bank.difficulties[item_idx]
end

function Base.length(item_bank::TransferItemBank)
    length(item_bank.difficulties)
end

function _norm_abil_1d(θ, difficulty, discrimination)
    (θ - difficulty) * discrimination
end

function norm_abil(ir::ItemResponse{<:TransferItemBank}, θ)
    _norm_abil_1d(θ, ir.item_bank.difficulties[ir.index], ir.item_bank.discriminations[ir.index])
end

function (ir::ItemResponse{<:TransferItemBank})(θ)
    resp(ir, θ)
end

function resp_vec(ir::ItemResponse{<:TransferItemBank}, θ)
    resp1 = resp(ir, θ)
    SVector(1.0 - resp1, resp1)
end

function resp(ir::ItemResponse{<:TransferItemBank}, outcome::Bool, θ)
    if outcome
        resp(ir, θ)
    else
        cresp(ir, θ)
    end
end

function resp(ir::ItemResponse{<:TransferItemBank}, θ)
    cdf(ir.item_bank.distribution, norm_abil(ir, θ))
end

function cresp(ir::ItemResponse{<:TransferItemBank}, θ)
    ccdf(ir.item_bank.distribution, norm_abil(ir, θ))
end

function logresp(ir::ItemResponse{<:TransferItemBank}, outcome::Bool, θ)
    if outcome
        logresp(ir, θ)
    else
        logcresp(ir, θ)
    end
end

function logresp(ir::ItemResponse{<:TransferItemBank}, θ)
    logcdf(ir.item_bank.distribution, norm_abil(ir, θ))
end

function logcresp(ir::ItemResponse{<:TransferItemBank}, θ)
    logccdf(ir.item_bank.distribution, norm_abil(ir, θ))
end

function item_params(item_bank::TransferItemBank, idx)
    (; difficulty=item_bank.difficulties[idx], discrimination=item_bank.discriminations[idx])
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
) where {F}
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