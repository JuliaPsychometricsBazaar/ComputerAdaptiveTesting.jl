using ParallelKMeans, Interpolations, Base.Filesystem

using ..ItemBanks: load_bootstrapped_item_bank, save_gridify

function make_cdf(num_resamples)
    cdf = Array{Float64}(undef, num_resamples)
    for idx in 0:(num_resamples - 1)
        cdf[idx + 1] = idx / (num_resamples - 1)
    end
    cdf
end

function gridify(corpus_dims, corpus_resampled, out_dir, new_samples=500)
    empirical_irf = load_bootstrapped_item_bank(
        corpus_dims,
        corpus_resampled;
        use_zipfs=true
    )
    grid_points = kmeans(Hamerly(), reshape(empirical_irf.resamples, 1, :), new_samples).centers
    grid_points = dropdims(grid_points, dims=1)
    sort!(grid_points)
    @debug "Got grid points" points=repr(grid_points)
    gridified_cdf = Array{Float64}(undef, (new_samples, size(empirical_irf.resamples, 2)))
    cdf = make_cdf(size(empirical_irf.resamples, 1))
    for word_idx in axes(empirical_irf.resamples, 2)
        itp_cdf = extrapolate(
            interpolate(
                empirical_irf.resamples[:, word_idx],
                cdf,
                SteffenMonotonicInterpolation()
            ),
            Interpolations.Flat()
        )
        gridified_cdf[:, word_idx] = itp_cdf.(grid_points)
    end
    save_gridify(grid_points, gridified_cdf, out_dir)
end