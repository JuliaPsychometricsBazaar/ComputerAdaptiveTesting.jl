#md # Tutorial
#
#md # [![](https://mybinder.org/badge_logo.svg)](@__BINDER_ROOT_URL__/generated/ability_convergence_3pl.ipynb)

# # Running a CAT based on a synthetic correct/incorrect 3PL IRT model
#
# This example shows how to run a CAT based on a synthetic correct/incorrect 3PL
# IRT model.

# Import order is important. We put ComputerAdaptiveTesting last so we get the extra dependencies.
using Makie
import Random
using Distributions: Normal, cdf
using AlgebraOfGraphics
if isdefined(Main, :IJulia) && Main.IJulia.inited
    using WGLMakie
else
    using GLMakie
end
using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.ExtraDistributions: NormalScaledLogistic
using ComputerAdaptiveTesting.Sim: auto_responder
using ComputerAdaptiveTesting.NextItemRules: NEXT_ITEM_ALIASES
using ComputerAdaptiveTesting.TerminationConditions: FixedItemsTerminationCondition
using ComputerAdaptiveTesting.Aggregators: PriorAbilityEstimator, MeanAbilityEstimator, integrate, LikelihoodAbilityEstimator
using ComputerAdaptiveTesting.Plots
using ComputerAdaptiveTesting.ItemBanks
import ComputerAdaptiveTesting.IntegralCoeffs

# We will use the 3PL model. We can construct such an item bank in two ways.
# Typically, the logistic c.d.f. is used as the transfer function in IRT.
# However, it in an IRT context, a scaled version intended to be close to a
# normal c.d.f. is often used. The main advantage is that this is usually faster
# to compute. ComputerAdaptiveTesting provides NormalScaledLogistic, which is
# also used by default, for this purpose:

xs = -8:0.05:8
lines(xs, cdf.(Normal(), xs))
lines!(xs, cdf.(NormalScaledLogistic(), xs))
current_figure()

# Now we are read to generate our synthetic data using the supplied DummyData
# module. We generate an item bank with 100 items and fake responses for 3
# testees.
using ComputerAdaptiveTesting.DummyData: dummy_3pl, std_normal
Random.seed!(42)
(item_bank, question_labels, abilities, responses) = dummy_3pl(;num_questions=100, num_testees=3)

# Define a function to simulate a CAT for each testee with a callback.
# We'll then use this to draw different types of plots.
const max_questions = 99
const ability_estimator = MeanAbilityEstimator(PriorAbilityEstimator(std_normal))

function sim_cats(new_response_callback)
    for testee_idx in axes(responses, 2)
        config = CatLoopConfig(
            get_response=auto_responder(
                @view responses[:, testee_idx]
            ),
            next_item=NEXT_ITEM_ALIASES["MEPV"](ability_estimator, parallel=false),
            termination_condition=FixedItemsTerminationCondition(max_questions),
            ability_estimator=ability_estimator,
            new_response_callback=(tracked_responses, terminating) -> new_response_callback(tracked_responses, testee_idx, terminating)
        )
        θ = run_cat(config, item_bank)
        true_θ = abilities[testee_idx]
        abs_err = abs(θ - true_θ)
        @info "final estimated ability" testee_idx θ true_θ abs_err
    end
end

# Make a plot showing how the estimated value evolves during the CAT.
# We also plot the 'true' values used to generate the responses.
col_idx = 1
num_respondents = size(responses, 2)
num_values = max_questions * num_respondents
respondent_step_lookup = Dict()
respondents = zeros(Int, num_values)
ability_ests = zeros(num_values)
steps = zeros(Int, num_values)
step = 1

const points = 500
xs = range(-2.5, 2.5, length=points)
likelihoods = zeros(points, num_values)
raw_estimator = LikelihoodAbilityEstimator()
raw_likelihoods = zeros(points, num_values)
item_responses = zeros(points, num_values)
item_difficulties = zeros(max_questions, num_respondents)
item_correctness = zeros(Bool, max_questions, num_respondents)

sim_cats(function (tracked_responses, resp_idx, terminating)
    global col_idx
    global step
    ability_est = ability_estimator(tracked_responses)
    if col_idx > 1 && respondents[col_idx - 1] != resp_idx
        step = 1
    end
    respondent_step_lookup[(resp_idx, step)] = col_idx
    respondents[col_idx] = resp_idx
    ability_ests[col_idx] = ability_est
    steps[col_idx] = step

    ## We'll also save the prior weighted likelihood of the responses up to this point.
    denom = integrate(IntegralCoeffs.one, ability_estimator.dist_est, tracked_responses)
    likelihoods[:, col_idx] = Aggregators.pdf.(Ref(ability_estimator.dist_est), Ref(tracked_responses), xs) ./ denom
    raw_denom = integrate(IntegralCoeffs.one, raw_estimator, tracked_responses)
    raw_likelihoods[:, col_idx] = Aggregators.pdf.(Ref(raw_estimator), Ref(tracked_responses), xs) ./ raw_denom
    item_index = tracked_responses.responses.indices[end]
    item_correct = tracked_responses.responses.values[end] > 0
    ir = ItemResponse(item_bank, item_index)
    item_responses[:, col_idx] = pick_outcome.(ir.(xs), item_correct)
    item_difficulties[step, resp_idx] = raw_difficulty(item_bank, item_index)
    item_correctness[step, resp_idx] = item_correct

    col_idx += 1
    step += 1
end)

## Allows hline! on AlgebraOfGraphics plots. May be better way in future.
## See: https://github.com/JuliaPlots/AlgebraOfGraphics.jl/issues/299
function Makie.hlines!(fg::AlgebraOfGraphics.FigureGrid, args...; kws...)
	for axis in fg.grid
		hlines!(axis.axis, args...; kws...)
	end
	return fg
end

plt = (
    data((respondent = respondents, ability_est = ability_ests, step = steps)) *
    visual(Lines) *
    mapping(:step, :ability_est, color = :respondent => nonnumeric)
)
conv_lines_fig = draw(plt)
hlines!(conv_lines_fig, abilities)
conv_lines_fig

# Make an interactive plot, showing how the distribution of the ability
# likelihood evolves.

conv_dist_fig = Figure()
ax = Axis(conv_dist_fig[1, 1])

lsgrid = labelslidergrid!(
    conv_dist_fig,
    ["Respondent", "Time step"],
    [1:3, 1:99];
    formats = ["{:d}", "{:d}"],
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

time = Observable(1)
cur_col_idx = @lift(respondent_step_lookup[($respondent, $time_step)])
cur_likelihood_ys = @lift(@view likelihoods[:, $cur_col_idx])
cur_raw_likelihood_ys = @lift(@view raw_likelihoods[:, $cur_col_idx])
cur_response_ys = @lift(@view item_responses[:, $cur_col_idx])
cur_ability = @lift(abilities[$respondent])
function mk_get_correctness(correct)
    function get_correctness(time_step, respondent)
        difficulty = @view item_difficulties[1:time_step, respondent]
        correctness = @view item_correctness[1:time_step, respondent]
        difficulty[correctness .== correct]
    end
end
cur_prev_correct = lift(mk_get_correctness(true), time_step, respondent)
cur_prev_incorrect = lift(mk_get_correctness(false), time_step, respondent)

posterior_likelihood_line = lines!(ax, xs, cur_likelihood_ys)
raw_likelihood_line = lines!(ax, xs, cur_raw_likelihood_ys)
cur_item_response_curve = lines!(ax, xs, cur_response_ys)
correct_items = scatter!(ax, cur_prev_correct, [0.0], color = :green)
incorrect_items = scatter!(ax, cur_prev_incorrect, [0.0], color = :red)
actual_ability_line = vlines!(ax, cur_ability)

connect!(correct_items.visible, toggle_by_name["previous responses"].active)
connect!(incorrect_items.visible, toggle_by_name["previous responses"].active)
connect!(actual_ability_line.visible, toggle_by_name["actual ability"].active)
connect!(posterior_likelihood_line.visible, toggle_by_name["posterior ability estimate"].active)
connect!(raw_likelihood_line.visible, toggle_by_name["raw ability estimate"].active)
connect!(cur_item_response_curve.visible, toggle_by_name["current item response"].active)

conv_dist_fig