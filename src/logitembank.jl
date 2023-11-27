using FittedItemBanks: AbstractItemBank, ItemResponse
using LogarithmicNumbers: ULogarithmic
import FittedItemBanks
using Lazy: @forward

struct LogItemBank{ItemBankT <: AbstractItemBank} <: AbstractItemBank
    inner::ItemBankT
end

function FittedItemBanks.resp(ir::ItemResponse{<:LogItemBank}, response, θ)
    ULogarithmic(FittedItemBanks.resp(ItemResponse(ir.item_bank.inner, ir.index),
        response,
        θ))
end

function FittedItemBanks.resp_vec(ir::ItemResponse{<:LogItemBank}, θ)
    ULogarithmic.(FittedItemBanks.resp_vec(ItemResponse(ir.item_bank.inner, ir.index), θ))
end

@forward LogItemBank.inner Base.length,
FittedItemBanks.domdims,
FittedItemBanks.ResponseType,
FittedItemBanks.DomainType
