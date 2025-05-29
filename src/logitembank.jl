module ItemBanks

using ComputerAdaptiveTesting.Responses
import ComputerAdaptiveTesting.Responses

export LogItemBank, DichotomousPointsWithLogsItemBank

using FittedItemBanks: AbstractItemBank, ItemResponse, PointsItemBank,
                       DichotomousPointsItemBank, NearestNeighborSmoother,
                       DichotomousSmoothedItemBank
using LogarithmicNumbers: ULogarithmic
import FittedItemBanks
using Lazy: @forward

struct LogItemBank{ItemBankT <: AbstractItemBank} <: AbstractItemBank
    inner::ItemBankT
end

inner_ir(ir::ItemResponse{<:LogItemBank}) = ItemResponse(ir.item_bank.inner, ir.index)

## TODO: Support item banks with other response types e.g. Float32

function FittedItemBanks.resp(ir::ItemResponse{<:LogItemBank}, θ)
    exp(ULogarithmic, FittedItemBanks.log_resp(inner_ir(ir), θ))
end

function FittedItemBanks.resp(ir::ItemResponse{<:LogItemBank}, response, θ)
    exp(
        ULogarithmic,
        FittedItemBanks.log_resp(inner_ir(ir), response, θ)
    )
end

function FittedItemBanks.resp_vec(ir::ItemResponse{<:LogItemBank}, θ)
    exp.(ULogarithmic, FittedItemBanks.log_resp_vec(inner_ir(ir), θ))
end

@forward LogItemBank.inner Base.length,
FittedItemBanks.domdims,
FittedItemBanks.ResponseType,
FittedItemBanks.DomainType

struct DichotomousPointsWithLogsItemBank{DomainT} <: PointsItemBank
    inner_bank::DichotomousPointsItemBank{DomainT}
    log_ys::Array{Float64, 3}
end

function DichotomousPointsWithLogsItemBank(inner_bank::DichotomousPointsItemBank)
    ys = inner_bank.ys
    log_ys = @views stack((log.(ys), log.(ones(eltype(ys)) .- ys)), dims = 1)
    return DichotomousPointsWithLogsItemBank(inner_bank, log_ys)
end

function inner_ir(ir::ItemResponse{<:DichotomousPointsWithLogsItemBank})
    ItemResponse(ir.item_bank.inner_bank, ir.index)
end

@forward DichotomousPointsWithLogsItemBank.inner_bank Base.length,
FittedItemBanks.domdims,
FittedItemBanks.item_bank_xs,
FittedItemBanks.ResponseType,
FittedItemBanks.DomainType

function FittedItemBanks.item_domain(ir::ItemResponse{<:DichotomousPointsWithLogsItemBank})
    FittedItemBanks.item_domain(inner_ir(ir))
end
function FittedItemBanks.item_xs(ir::ItemResponse{<:DichotomousPointsWithLogsItemBank})
    FittedItemBanks.item_xs(inner_ir(ir))
end
function FittedItemBanks.item_ys(ir::ItemResponse{<:DichotomousPointsWithLogsItemBank})
    FittedItemBanks.item_ys(inner_ir(ir))
end

function item_log_ys(ir::ItemResponse{<:DichotomousPointsWithLogsItemBank})
    return @view ir.item_bank.log_ys[:, :, ir.index]
end

function item_log_ys(ir::ItemResponse{<:DichotomousPointsWithLogsItemBank}, resp)
    return @view ir.item_bank.log_ys[Int(resp) + 1, :, ir.index]
end

function Responses.function_xs(ability_lh::AbilityLikelihood{<:DichotomousPointsWithLogsItemBank})
    return ability_lh.item_bank.inner_bank.xs
end

function Responses.function_ys(ability_lh::AbilityLikelihood{<:DichotomousPointsWithLogsItemBank})
    num_integration_points = length(FittedItemBanks.item_bank_xs(ability_lh.item_bank))
    # TODO: Figure out how to avoid loosing all the dynamic range here
    return exp.(reduce(
        .+,
        (
            item_log_ys(
                ItemResponse(
                    ability_lh.item_bank,
                    ability_lh.responses.indices[resp_idx]
                ),
                ability_lh.responses.values[resp_idx]
            )
        for resp_idx in axes(ability_lh.responses.indices, 1)
        );
        init = zeros(num_integration_points)
    ))
end

function FittedItemBanks.resp_vec(ir::ItemResponse{<:DichotomousPointsWithLogsItemBank}, θ)
    item_bank = DichotomousSmoothedItemBank(
        ir.item_bank.inner_bank, NearestNeighborSmoother())
    FittedItemBanks.resp_vec(ItemResponse(item_bank, ir.index), θ)
end

end
