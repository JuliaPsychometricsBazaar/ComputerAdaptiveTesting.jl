using FittedItemBanks: AbstractItemBank, ItemResponse
using LogarithmicNumbers: ULogarithmic
import FittedItemBanks
using Lazy: @forward

struct LogItemBank{ItemBankT <: AbstractItemBank} <: AbstractItemBank
    inner::ItemBankT
end

inner_ir(ir::ItemResponse{<:LogItemBank}) = ItemResponse(ir.item_bank.inner, ir.index)

## TODO: Support item banks with other response types e.g. Float32

function FittedItemBanks.resp(ir::ItemResponse{<:LogItemBank}, θ)
    exp(ULogarithmic{Float64}, FittedItemBanks.log_resp(inner_ir(ir), θ))
end

function FittedItemBanks.resp(ir::ItemResponse{<:LogItemBank}, response, θ)
    exp(
        ULogarithmic{Float64},
        FittedItemBanks.log_resp(inner_ir(ir), response, θ)
    )
end

function FittedItemBanks.resp_vec(ir::ItemResponse{<:LogItemBank}, θ)
    exp(ULogarithmic{Float64}, FittedItemBanks.log_resp_vec(inner_ir(ir), θ))
end

@forward LogItemBank.inner Base.length,
FittedItemBanks.domdims,
FittedItemBanks.ResponseType,
FittedItemBanks.DomainType
