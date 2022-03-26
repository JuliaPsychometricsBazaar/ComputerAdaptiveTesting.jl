module Plots

using QuadGK
using Distributions
using Mmap
using AlgebraOfGraphics
using DataFrames
using Makie


function curve_data(responses; include_posterior=false)
	θs = Float64[]
	probs = Float64[]
	for (θ, prob) in iter_abil_given_resps(responses, empirical_irf)
		push!(θs, θ)
		push!(probs, include_posterior ? pdf(cauchy, θ) * prob : prob)
	end
	(θs, probs)
end

function make_resp(raw)
	[
		Response(
			findfirst((hlabel) -> hlabel == label, empirical_irf.labels),
			resp
		)
		for (label, resp) in raw
	]
end

function get_progressive_curves(empirical_irf)
	data = make_resp([("red", 1), ("dog", 1), ("fearfully", 0), ("snake", 0)])
	irfs = []
	likelihoods = []
	posterior_probs = []
	mean_θs = []
	for i in 1:length(data)
		irf_points = collect(Tuple{Float64, Float64}, iter_irf(empirical_irf, data[i]))
		push!(irfs, lines(irf_points))
	end
	for i in 0:length(data)
		push!(likelihoods, lines(curve_data(data[1:i])...))
		push!(posterior_probs, lines(curve_data(data[1:i]; include_posterior=true)...))
		push!(mean_θs, mean_θ(data[1:i], empirical_irf))
	end
	(irfs, likelihoods, posterior_probs, mean_θs)
end

const WORD_RE = r"^\p{L}+$"

function sample_words(empirical_irf; num_words=12, limit=nothing)
	label = empirical_irf.labels
	if limit !== nothing
		label = label[1:limit]
	end
    rand([idx for (idx, word) in enumerate(label) if match(WORD_RE, word) !== nothing], num_words)
end

function sample_strat_words(empirical_irf)
	[
		sample_words(empirical_irf, num_words=3, limit=1000)
		sample_words(empirical_irf, num_words=3, limit=2000)
		sample_words(empirical_irf, num_words=6)
	]
end

function plot_bootstrapped(empirical_irf, idxs)
    sampled_resamples = empirical_irf.resamples[:, idxs]

    words_rep = vec(repeat(permutedims(empirical_irf.labels[idxs]), 100, 1))
    df = (words=words_rep, freqs=(@view sampled_resamples[:]))
    xz = data(df) * mapping(:freqs, layout=:words) * AlgebraOfGraphics.density(bandwidth=0.04)
    axis = (; ylabel="")
    draw(xz; axis)

    current_figure()
end

function plot_gridified(words, in_path, idxs)
    xs, ys = load_gridify(in_path)
	xs_full = repeat(xs, 1, length(idxs))
    words_rep = repeat(permutedims(words[idxs]), length(xs), 1)
	selected_ys = ys[:,idxs]
	println("sizes")
	println(size(words_rep))
	println(size(xs_full))
	println(size(selected_ys))
    df = (words=words_rep[:], xs=xs_full[:], ys=selected_ys[:])
    xz = data(df) * mapping(:xs, :ys, layout=:words) * visual(Lines)
    axis = (; ylabel="")
    draw(xz; axis)

    current_figure()
end

end