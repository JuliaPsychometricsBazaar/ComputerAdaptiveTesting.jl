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
    labels::MaybeLabels
end

DomainType(::GriddedItemBank) = DiscreteIndexableDomain

function Base.length(item_bank::GriddedItemBank)
    size(item_bank.ys, 2)
end

function subset_item_bank(item_bank::GriddedItemBank, word_list)::GriddedItemBank
    ib_labels = labels(item_bank)
    word_idxs = get_word_list_idxs(word_list, ib_labels)
    GriddedItemBank(
        item_bank.xs,
        item_bank.ys[:, word_idxs],
        ib_labels[word_idxs]
    )
end

function irf(item_bank::GriddedItemBank, index, θ::Float64)::Float64
    loc = searchsorted(item_bank.xs, θ)
    item_bank.ys[loc.start, index]
end

function cb_abil_given_resps(
    cb::F,
    responses::BareResponses,
    items::GriddedItemBank;
    lo=0.0,
    hi=10.0,
    irf_states_storage=nothing
) where {F}
    cb(lo, any(responses.values) ? 0.0 : 1.0)
    for idx in 1:length(items.xs)
        y = prod(
            pick_outcome(items.ys[idx, responses.indices[ridx]], responses.values[ridx] > 0)
            for ridx in axes(responses.values, 2);
            init=1.0
        )
        cb(items.xs[idx], y)
    end
    cb(hi, all(responses.values) ? 1.0 : 0.0)
end