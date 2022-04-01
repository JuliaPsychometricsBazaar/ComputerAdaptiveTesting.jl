using Setfield
using Lazy: @forward

struct FixedGuessItemBank{InnerItemBank <: AbstractItemBank} <: AbstractItemBank
    guess::Float64
    inner_bank::InnerItemBank
end
y_offset(item_bank::FixedGuessItemBank, item_idx) = item_bank.guess
@forward FixedGuessItemBank.inner_bank Base.length

struct FixedSlipItemBank{InnerItemBank <: AbstractItemBank} <: AbstractItemBank
    slip::Float64
    inner_bank::InnerItemBank
end
y_offset(item_bank::FixedSlipItemBank, item_idx) = item_bank.slip
@forward FixedSlipItemBank.inner_bank Base.length

struct GuessItemBank{InnerItemBank <: AbstractItemBank} <: AbstractItemBank
    guesses::Vector{Float64}
    inner_bank::InnerItemBank
end
y_offset(item_bank::GuessItemBank, item_idx) = item_bank.guesses[item_idx]
@forward GuessItemBank.inner_bank Base.length

struct SlipItemBank{InnerItemBank <: AbstractItemBank} <: AbstractItemBank
    slips::Vector{Float64}
    inner_bank::InnerItemBank
end
y_offset(item_bank::SlipItemBank, item_idx) = item_bank.slips[item_idx]
@forward SlipItemBank.inner_bank Base.length

const AnySlipItemBank = Union{SlipItemBank, FixedSlipItemBank}
const AnyGuessItemBank = Union{GuessItemBank, FixedGuessItemBank}
const AnySlipOrGuessItemBank = Union{AnySlipItemBank, AnyGuessItemBank}
const AnySlipAndGuessItemBank = Union{SlipItemBank{AnyGuessItemBank}, FixedSlipItemBank{AnyGuessItemBank}}

DomainType(item_bank::AnySlipOrGuessItemBank) = DomainType(item_bank.inner_bank)

# Ensure we always have Slip{Guess{ItemBank}}
function FixedGuessItemBank(guess::Float64, inner_bank::AnySlipItemBank)
    @set inner_bank.inner_bank = FixedGuessItemBank(guess, inner_bank.inner_bank)
end

function GuessItemBank(guesses::Vector{Float64}, inner_bank::AnySlipItemBank)
    @set inner_bank.inner_bank = GuessItemBank(guess, inner_bank.inner_bank)
end

@inline function transform_irf_y(guess::Float64, slip::Float64, y::Float64)::Float64
    irf_size = 1 - guess - slip
    guess + irf_size * y
end

function (ir::ItemResponse{<:GuessItemBank})(θ::Float64)::Float64
    transform_irf_y(y_offset(ir.item_bank, ir.index), 0.0, ItemResponse(ir.item_bank.inner_bank, ir.index)(θ))
end

function (ir::ItemResponse{<:SlipItemBank})(θ::Float64)::Float64
    transform_irf_y(0.0, y_offset(ir.item_bank, ir.index), ItemResponse(ir.item_bank.inner_bank, ir.index)(θ))
end

function (ir::ItemResponse{<:AnySlipAndGuessItemBank})(θ::Float64)::Float64
    transform_irf_y(
        y_offset(ir.item_bank.inner_bank, ir.index),
        y_offset(ir.item_bank, ir.index),
        ItemResponse(ir.item_bank.inner_bank.inner_bank, ir.index)(θ)
    )
end

#=
function cb_abil_given_resps(
    cb::F,
    responses::AbstractVector{Response},
    item_bank::GuessSlipItemBank;
    lo=0.0,
    hi=10.0,
    irf_states_storage=nothing
) where {F}
    @inline function cb_wrap(x, y)
        cb(x, transform_irf_y(item_bank, y))
    end
    cb_abil_given_resps(cb_wrap, responses, item_bank; lo=lo, hi=hi, irf_states_storage=irf_states_storage)
end
=#

function labels(item_bank::AnySlipOrGuessItemBank)
    labels(item_bank.inner_bank)
end