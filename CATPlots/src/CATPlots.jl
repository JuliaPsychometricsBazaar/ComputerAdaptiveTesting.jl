"""
This module contains helpers for creating CAT/IRT related plots. This module
requires the optional depedencies AlgebraOfGraphics, DataFrames and Makie to be
installed.
"""
module CATPlots

export CatRecorder, ability_evolution_lines, lh_evoluation_interactive, @automakie

using Parameters
using Distributions
using AlgebraOfGraphics
using DataFrames
using Makie
using MakieLayout
using ComputerAdaptiveTesting: Aggregators
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.ItemBanks
using ComputerAdaptiveTesting.Integrators

# Allows hline! on AlgebraOfGraphics plots. May be better way in future.
# See: https://github.com/JuliaPlots/AlgebraOfGraphics.jl/issues/299
function Makie.hlines!(fg::AlgebraOfGraphics.FigureGrid, args...; kws...)
	for axis in fg.grid
		hlines!(axis.axis, args...; kws...)
	end
	return fg
end

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

mutable struct CatRecorder{AbilityVecT}
	col_idx::Int
	step::Int
	points::Int
	respondents::Vector{Int}
	ability_ests::AbilityVecT
	steps::Vector{Int}
	xs::AbilityVecT
	likelihoods::Matrix{Float64}
	integrator::AbilityIntegrator
	raw_estimator::LikelihoodAbilityEstimator
	raw_likelihoods::Matrix{Float64}
	item_responses::Matrix{Float64}
	item_difficulties::Matrix{Float64}
	item_correctness::Matrix{Bool}
	ability_estimator::AbilityEstimator
    respondent_step_lookup::Dict{Tuple{Int, Int}, Int}
end

#xs = range(-2.5, 2.5, length=points)

function CatRecorder(xs, points, ability_ests, num_questions, num_respondents, integrator, raw_estimator, ability_estimator)
    num_values = num_questions * num_respondents
	xs_vec = collect(xs)

	CatRecorder(
		1,
		1,
		points,
		zeros(Int, num_values),
		ability_ests,
		zeros(Int, num_values),
		xs_vec,
		zeros(points, num_values),
		AbilityIntegrator(integrator),
		raw_estimator,
		zeros(points, num_values),
		zeros(points, num_values),
		zeros(num_questions, num_respondents),
		zeros(Bool, num_questions, num_respondents),
		ability_estimator,
		Dict{Tuple{Int, Int}, Int}()
	)
end

function CatRecorder(xs::AbstractVector{Float64}, responses, integrator, raw_estimator, ability_estimator)
	points = size(xs, 1)
    num_questions = size(responses, 1)
    num_respondents = size(responses, 2)
    num_values = num_questions * num_respondents
	CatRecorder(xs, points, zeros(num_values), num_questions, num_respondents, integrator, raw_estimator, ability_estimator)
end

function CatRecorder(xs::AbstractMatrix{Float64}, responses, integrator, raw_estimator, ability_estimator)
	points = size(xs, 2)
    num_questions = size(responses, 1)
    num_respondents = size(responses, 2)
    num_values = num_questions * num_respondents
	CatRecorder(xs, points, zeros(size(xs, 1), num_values), num_questions, num_respondents, integrator, raw_estimator, ability_estimator)
end

function push_ability_est!(ability_ests::AbstractMatrix{Float64}, col_idx, ability_est)
    ability_ests[:, col_idx] = ability_est
end

function push_ability_est!(ability_ests::AbstractVector{Float64}, col_idx, ability_est)
    ability_ests[col_idx] = ability_est
end

function eachmatcol(xs::Matrix)
	eachcol(xs)
end

function eachmatcol(xs::Vector)
	xs
end

function (recorder::CatRecorder)(tracked_responses, resp_idx, terminating)
    ability_est = recorder.ability_estimator(tracked_responses)
    if recorder.col_idx > 1 && recorder.respondents[recorder.col_idx - 1] != resp_idx
        recorder.step = 1
    end
    recorder.respondent_step_lookup[(resp_idx, recorder.step)] = recorder.col_idx
    recorder.respondents[recorder.col_idx] = resp_idx
    push_ability_est!(recorder.ability_ests, recorder.col_idx, ability_est)
    recorder.steps[recorder.col_idx] = recorder.step

    # Save likelihoods
	dist_est = distribution_estimator(recorder.ability_estimator)
    denom = normdenom(recorder.integrator, dist_est, tracked_responses)
    recorder.likelihoods[:, recorder.col_idx] = Aggregators.pdf.(Ref(dist_est), Ref(tracked_responses), eachmatcol(recorder.xs)) ./ denom
    raw_denom = normdenom(recorder.integrator, recorder.raw_estimator, tracked_responses)
    recorder.raw_likelihoods[:, recorder.col_idx] = Aggregators.pdf.(Ref(recorder.raw_estimator), Ref(tracked_responses), eachmatcol(recorder.xs)) ./ raw_denom

	# Save item responses
    item_index = tracked_responses.responses.indices[end]
    item_correct = tracked_responses.responses.values[end] > 0
    ir = ItemResponse(tracked_responses.item_bank, item_index)
    recorder.item_responses[:, recorder.col_idx] = pick_resp(item_correct).(Ref(ir), eachmatcol(recorder.xs))

	# Save item parameters
    recorder.item_difficulties[recorder.step, resp_idx] = raw_difficulty(tracked_responses.item_bank, item_index)
    recorder.item_correctness[recorder.step, resp_idx] = item_correct

    recorder.col_idx += 1
    recorder.step += 1
end

function ability_evolution_lines(recorder; abilities=nothing)
	plt = (
		data((respondent = recorder.respondents, ability_est = recorder.ability_ests, step = recorder.steps)) *
		visual(Lines) *
		mapping(:step, :ability_est, color = :respondent => nonnumeric)
	)
	conv_lines_fig = draw(plt)
	if abilities !== nothing
		hlines!(conv_lines_fig, abilities)
	end
	conv_lines_fig
end

function lh_evoluation_interactive(recorder; abilities=nothing)
	conv_dist_fig = Figure()
	ax = Axis(conv_dist_fig[1, 1])

	lsgrid = SliderGrid(
		conv_dist_fig,
		(label = "Respondent", range = 1:3, format = "{:d}"),
		(label = "Time step", range = 1:99, format = "{:d}"),
		width = 350,
		tellheight = false
	)

	toggle_labels = [
		"posterior ability estimate",
		"raw ability estimate",
		"actual ability",
		"current item response",
		"previous responses"
	]
	toggles = [Toggle(conv_dist_fig, active = true) for _ in toggle_labels]
	labels = [
		Label(conv_dist_fig, lift(x -> x ? "Show $l" : "Hide $l", t.active))
		for (t, l) in zip(toggles, toggle_labels)
	]
	toggle_by_name = Dict(zip(toggle_labels, toggles))

	conv_dist_fig[1, 2] = GridLayout()
	conv_dist_fig[1, 2][1, 1] = lsgrid.layout
	conv_dist_fig[1, 2][2, 1] = grid!(hcat(toggles, labels), tellheight = false)

	respondent = lsgrid.sliders[1].value
	time_step = lsgrid.sliders[2].value

	cur_col_idx = @lift(recorder.respondent_step_lookup[($respondent, $time_step)])
	cur_likelihood_ys = @lift(@view recorder.likelihoods[:, $cur_col_idx])
	cur_raw_likelihood_ys = @lift(@view recorder.raw_likelihoods[:, $cur_col_idx])
	cur_response_ys = @lift(@view recorder.item_responses[:, $cur_col_idx])
	if abilities !== nothing
		cur_ability = @lift(abilities[$respondent])
	end
	function mk_get_correctness(correct)
		function get_correctness(time_step, respondent)
			difficulty = @view recorder.item_difficulties[1:time_step, respondent]
			correctness = @view recorder.item_correctness[1:time_step, respondent]
			difficulty[correctness .== correct]
		end
	end
	cur_prev_correct = lift(mk_get_correctness(true), time_step, respondent)
	cur_prev_incorrect = lift(mk_get_correctness(false), time_step, respondent)

	posterior_likelihood_line = lines!(ax, recorder.xs, cur_likelihood_ys)
	raw_likelihood_line = lines!(ax, recorder.xs, cur_raw_likelihood_ys)
	cur_item_response_curve = lines!(ax, recorder.xs, cur_response_ys)
	correct_items = scatter!(ax, cur_prev_correct, [0.0], color = :green)
	incorrect_items = scatter!(ax, cur_prev_incorrect, [0.0], color = :red)
	if abilities !== nothing
		actual_ability_line = vlines!(ax, cur_ability)
	end

	connect!(correct_items.visible, toggle_by_name["previous responses"].active)
	connect!(incorrect_items.visible, toggle_by_name["previous responses"].active)
	connect!(actual_ability_line.visible, toggle_by_name["actual ability"].active)
	connect!(posterior_likelihood_line.visible, toggle_by_name["posterior ability estimate"].active)
	connect!(raw_likelihood_line.visible, toggle_by_name["raw ability estimate"].active)
	connect!(cur_item_response_curve.visible, toggle_by_name["current item response"].active)

	conv_dist_fig
end

@Block LabelledToggleGrid begin
    @forwarded_layout
    toggles::Vector{Toggle}
    labels::Vector{Label}
    @attributes begin
        "The horizontal alignment of the block in its suggested bounding box."
        halign = :center
        "The vertical alignment of the block in its suggested bounding box."
        valign = :center
        "The width setting of the block."
        width = Auto()
        "The height setting of the block."
        height = Auto()
        "Controls if the parent layout can adjust to this block's width"
        tellwidth::Bool = true
        "Controls if the parent layout can adjust to this block's height"
        tellheight::Bool = true
        "The align mode of the block in its parent GridLayout."
        alignmode = Inside()
    end
end

function initialize_block!(sg::LabelledToggleGrid, nts::NamedTuple...)

    sg.toggles = Toggle[]
    sg.labels = Label[]

    for (i, nt) in enumerate(nts)
        label = haskey(nt, :label) ? nt.label : ""
        remaining_pairs = filter(pair -> pair[1] ∉ (:label, :format), pairs(nt))
        l = Label(sg.layout[i, 1], label, halign = :left)
        toggle = Toggle(sg.layout[i, 2]; remaining_pairs...)
        push!(sg.toggles, toggle)
        push!(sg.labels, l)
    end
end

macro automakie()
    quote
		if "USE_WGL_MAKIE" in keys(ENV)
			using WGLMakie
		elseif "USE_GL_MAKIE" in keys(ENV)
			using GLMakie
		elseif "USE_CARIO_MAKIE" in keys(ENV)
			using CairoMakie
		elseif (isdefined(Main, :IJulia) && Main.IJulia.inited)
			using WGLMakie
		else
			Pkg = Base.require(Base.PkgId(Base.UUID(0x44cfe95a1eb252eab672e2afdf69b78f), "Pkg"))
			if "WGLMakie" in keys(Pkg.project().dependencies)
				using WGLMakie
			elseif "GLMakie" in keys(Pkg.project().dependencies)
				using GLMakie
			else
				using CairoMakie
			end
		end
	end
end

#=
fig[1, 2] = GridLayout()
fig[1, 2][1, 1] = lsgrid.layout
fig[1, 2][2, 1] = grid!(hcat(toggles, labels), tellheight = false)
=#

end