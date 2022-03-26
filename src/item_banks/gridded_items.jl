function load_gridded_item_bank(gridify_path; labels_path=nothing)::GriddedItemBank
    (xs, ys) = load_gridify(gridify_path)
    labels = nothing
    if labels_path !== nothing
        labels = readlines(labels_path) 
    end
    GriddedItemBank(xs, ys, labels)
end

struct GriddedItemBank <: AbstractItemBank
    xs::Vector{Float64}
    ys::Matrix{Float64}
    labels::Union{Vector{String}, Nothing}
end

DomainType(::GriddedItemBank) = DiscreteIndexableDomain

function Base.length(item_bank::GriddedItemBank)
    size(item_bank.ys, 2)
end

function subset_item_bank(item_bank::GriddedItemBank, word_list)::GriddedItemBank
    word_idxs = get_word_list_idxs(word_list, item_bank.labels)
    GriddedItemBank(
        item_bank.xs,
        item_bank.ys[:, word_idxs],
        item_bank.labels[word_idxs]
    )
end

function irf(item_bank::GriddedItemBank, index, θ::Float64)::Float64
    loc = searchsorted(item_bank.xs, θ)
    item_bank.ys[loc.start, index]
end

function cb_abil_given_resps(
    cb::F,
    responses::AbstractVector{Response},
    items::GriddedItemBank;
    lo=0.0,
    hi=10.0,
    irf_states_storage=nothing
) where {F}
    response_values = [r.value > 0 for r in responses]

    cb(lo, any(response_values) ? 0.0 : 1.0)
    for idx in 1:length(items.xs)
        y = prod(
            pick_outcome(items.ys[idx, resp.index], resp.value > 0)
            for resp in responses;
            init=1.0
        )
        cb(items.xs[idx], y)
    end
    cb(hi, all(response_values) ? 1.0 : 0.0)
end

function iter_item_idxs(item_bank::GriddedItemBank)
    axes(item_bank.ys, 2)
end