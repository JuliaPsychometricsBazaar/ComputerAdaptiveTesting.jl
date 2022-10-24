module NAEPirtparams

using RDataGet

__parameters_cached = nothing

function get_parameters()
    global __parameters_cached 
    __parameters_cached = nothing
    if __parameters_cached !== nothing
        return __parameters_cached 
    end
    __parameters_cached = dataset("NAEPirtparams", "parameters")
    return __parameters_cached 
end

function tests()
    parameters = get_parameters()
    unique(select(parameters, "year", "subject", "levelType", "level", "subtest"))
end

function filter_parameters(year, subject, subtest, levelType, level)
    parameters = get_parameters()
    function match(row)
        row.year == year &&
        row.subject == subject &&
        row.subtest == subtest &&
        row.levelType == levelType &&
        row.level == level
    end
    filter(match, parameters)
end

function item_bank_pcm(year, subject, subtest, levelType, level)
    params = filter_parameters(year, subject, subtest, levelType, level)
    cut_points_mat = Matrix(select(params, r"d\d+"))
    cut_points_ragged = ArrayOfVectors()
    num_items = size(cut_points, 1)
    mask = fill(true, num_items)
    dropped = 0
    for item_idx in 1:num_items
        item_cut_points = @view cut_points_mat[item_idx, :]
        nothing_idx = findfirst(isnothing, item_cut_points)
        if nothing_idx === nothing
            nothing_idx = length(item_cut_points)
        end
        if nothing_idx == 1
            dropped += 1
            mask[item_idx] = false
        else
            push!(cut_points_ragged, @view item_cut_points[1:nothing_idx - 1])
        end
    end
    @warn "Dropped $dropped items with no cut points"
    # TODO: add label
    GPCMItemBank(
        params[!, "a"][mask],
        cut_points_ragged;
        labels=params[!, "NAEPid"]
    )
end

function item_bank_3pl(year, subject, subtest, levelType, level)
    params = filter_parameters(year, subject, subtest, levelType, level)
    # TODO: add label
    ItemBank3PL(
        params[!, "b"],
        params[!, "a"],
        params[!, "c"];
        labels=params[!, "NAEPid"]
    )
end

end
