function load_bootstrapped_item_bank(dims_path, resampled_path; labels_path=nothing, use_zipfs=false)::BootstrappedItemBank
    num_docs_, vocab_len = read_dims_file(dims_path)
    io = open(resampled_path);
    resamples = mmap(io, Matrix{Float64}, (100, Int64(vocab_len)))
    if use_zipfs
        resamples = reverse(min.(10.0 .- log10.(resamples * 1_000_000_000), 10.1))
    end
    labels = nothing
    if labels_path !== nothing
        labels = readlines(labels_path) 
    end
    BootstrappedItemBank(
        resamples,
        labels
    )
end

struct BootstrappedItemBank <: AbstractItemBank
    resamples::Matrix{Float64}
    labels::Union{Vector{String}, Nothing}
end

function Base.length(item_bank::BootstrappedItemBank)
    size(item_bank.resamples, 2)
end

function subset_item_bank(item_bank::BootstrappedItemBank, word_list)::BootstrappedItemBank
    # XXX: Investigate views/AbstractBootstrappedItemBank
    word_idxs = get_word_list_idxs(word_list, item_bank.labels)
    BootstrappedItemBank(
        item_bank.resamples[:, word_idxs],
        item_bank.labels[word_idxs]
    )
end

"""
The item-response function at a particular item and value of θ. This is the
empirical/nonparametric variant.
"""
function irf(items::BootstrappedItemBank, index, θ::Float64)::Float64
    loc = searchsorted((@view items.resamples[:, index]), θ)
    if loc.start < loc.stop
        avg_loc = (loc.stop - loc.start) / 2
    else
        avg_loc = loc.stop
    end
    return avg_loc / length(items.resamples)
end

@resumable function iter_irf(items::BootstrappedItemBank, resp::Response)
    cur = 0
    num_resamples = size(items.resamples, 1)
    for si in axes(items.resamples, 1)
        cur += 1
        @nosave val = cur / num_resamples
        @yield (items.resamples[si, resp.index], pick_outcome(val, resp.value > 0))
    end
end

function cb_abil_given_resps(
    cb::F,
    responses::AbstractVector{Response},
    items::BootstrappedItemBank;
    lo=0.0,
    hi=10.0,
    irf_states_storage=nothing
) where {F}
    item_indices = [r.index for r in responses]
    response_values = [r.value > 0 for r in responses]

    if irf_states_storage === nothing
        resp_length = length(item_indices)
        irf_states::Vector{Int32} = zeros(Int, resp_length)
    else
        irf_states = irf_states_storage 
        fill!(irf_states, 0)
    end
    cb(lo, any(response_values) ? 0.0 : 1.0)
    num_resamples = size(items.resamples, 1)
    while true
        min_θ = Inf
        min_curve_idx = nothing
        for curve_idx in axes(irf_states, 1)
            resample_index = irf_states[curve_idx] + 1
            if resample_index >= num_resamples
                continue
            end
            item_index = item_indices[curve_idx]
            θ = items.resamples[resample_index, item_index ]
            if θ < min_θ
                min_θ = θ
                min_curve_idx = curve_idx
            end
        end
        if min_curve_idx === nothing
            cb(hi, all(response_values) ? 1.0 : 0.0)
            return
        end
        y = prod(
            pick_outcome(irf / num_resamples, resp)
            for (irf, resp)
            in zip(irf_states, response_values)
        )
        cb(min_θ, y)
        irf_states[min_curve_idx] += 1
    end
end

function iter_item_idxs(item_bank::BootstrappedItemBank)
    axes(item_bank.resamples, 2)
end