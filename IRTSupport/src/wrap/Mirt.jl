module Mirt

using Conda
using RCall
using ComputerAdaptiveTesting.ItemBanks

export fit_mirt, fit_2pl, fit_3pl, fit_4pl, fit_gpcm

function fit_mirt(df; kwargs...)
    @debug "Fitting IRT model"
    Conda.add("r-mirt"; channel="conda-forge")
    R"""
    library(mirt)
    """
    irt_model = rcall(:mirt, df; kwargs...)
    df = rcopy(
        R"""
        coefs_list <- coef($irt_model)
        coefs_list["GroupPars"] <- NULL
        coefs_df <- do.call(rbind.data.frame, c(coefs_list, stringsAsFactors=FALSE))
        cbind(label = names(coefs_list), coefs_df)
        """
    )
    @info "fit_mirt" df
    return df
end

function fit_gpcm(df; kwargs...)
    params = fit_mirt(df; model=1, itemtype="gpcm", kwargs...)
    discriminations = convert(Matrix, select(params, r"a\d+"))
    cut_points = convert(Matrix, select(params, r"d\d+"))
    GPCMItemBank(discriminations, cut_points, labels=params[!, "label"])
end

function fit_4pl(df; kwargs...)
    params = fit_mirt(df; model=1, itemtype="4PL", kwargs...)
    ItemBank4PL(params[!, "d"], params[!, "a1"], params[!, "g"], 1.0 .- params[!, "u"]; labels=params[!, "label"])
end

function fit_3pl(df; kwargs...)
    params = fit_mirt(df; model=1, itemtype="3PL", kwargs...)
    ItemBank3PL(params[!, "d"], params[!, "a1"], params[!, "g"]; labels=params[!, "label"])
end

function fit_2pl(df; kwargs...)
    params = fit_mirt(df; model=1, itemtype="2PL", kwargs...)
    ItemBank2PL(params[!, "d"], params[!, "a1"]; labels=labels)
end

end