module MirtWrap

using Conda
using RCall
using ComputerAdaptiveTesting.ItemBanks

export fit_mirt, fit_2pl, fit_3pl, fit_4pl

function fit_mirt(df; kwargs...)
    @debug "Fitting IRT model"
    Conda.add("r-mirt"; channel="conda-forge")
    R"""
    library(mirt)
    """
    irt_model = rcall(:mirt, df; kwargs...)
    R"""
    do.call(rbind, head(coef($irt_model), -1))
    """
end

function fit_4pl(df; kwargs...)
    params = fit_mirt(df; model=1, itemtype="4PL", kwargs...)
    @info "params" params
    arr = rcopy(Array{Float64}, params)
    ItemBank4PL(arr[:, 2], arr[:, 1], arr[:, 3], 1.0 .- arr[:, 4])
end

function fit_3pl(df; kwargs...)
    params = fit_mirt(df; model=1, itemtype="3PL", kwargs...)
    arr = rcopy(Array{Float64}, params)
    ItemBank3PL(arr[:, 2], arr[:, 1], arr[:, 3])
end

function fit_2pl(df; kwargs...)
    params = fit_mirt(df; model=1, itemtype="2PL", kwargs...)
    arr = rcopy(Array{Float64}, params)
    ItemBank2PL(arr[:, 2], arr[:, 1])
end

end