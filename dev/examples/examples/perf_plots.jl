using Makie
import Pkg
using CSV
using DataFrames
using CategoricalArrays: levels
using IterTools: chain
using ComputerAdaptiveTesting
using CATPlots
using CATPlots: LabelledToggleGrid, MenuGrid

DOCS_DATA = pkgdir(ComputerAdaptiveTesting) * "/docs/data/"

@automakie()

df = CSV.read(
	(DOCS_DATA * "integrator_benchmark_results.csv"),
	DataFrame;
	types=Dict(
		"value" => Float64,
		"err" => Float64,
		"bytes" => Int64,
		"response" => Int32,
		"item_bank" => Int32,
		"dim" => Int32,
		"trial" => Int32,
		"time" => Float64,
		"gctime" => Float64,
		"rtol" => Float64,
	)
)

function plot(df)
	fig = Figure()
	ax = Axis(fig[1, 1])

	groupables = ["item_bank", "response", "trial", "dim", "integrator"]
	regressables = ["integrator", "dim", "rtol", "value", "err", "bytes", "gctime"]

	Menu(fig, options = ["none", groupables...], default = "none")
	toggles = []
	sliders = []
	slider_idxs = []
	menus = []
	menu_idxs = []
	for (idx, groupable) in enumerate(groupables)
		push!(toggles, (
			label = groupable,
		))
		opts = sort(levels(df[!, groupable]))
		if eltype(opts) <: AbstractString
			push!(slider_idxs, idx)
			push!(menus, (
				label = groupable,
				options = opts
			))
		else
			push!(menu_idxs, idx)
			push!(sliders, (
				label = groupable,
				range = opts
			))
		end
	end
	tgrid = LabelledToggleGrid(
		fig,
		toggles...,
		width = 350,
		tellheight = false
	)
	lsgrid = SliderGrid(
		fig,
		sliders...,
		width = 350,
		tellheight = false
	)
	mgrid = MenuGrid(
		fig,
		menus...,
		width = 350,
		tellheight = false
	)

	working_df = Observable(nothing)
	function update_working_df(_)
		df_prime = df
		slider_menu_vals = Vector{Any}(undef, length(sliders) + length(menus))
		slider_menu_vals[slider_idxs] = [slider.value for slider in lsgrid.sliders]
		slider_menu_vals[menu_idxs] = [menu.selection for menu in mgrid.menus]
		for (groupable, toggle, value) in zip(groupables, tgrid.toggles, slider_menu_vals)
			if !toggle.value
				continue
			end
			df_prime = filter(working_df, groupable => value)
		end
		working_df[] = df_prime
	end

	for observable in chain(
		(t.active for t in tgrid.toggles),
		(s.value for s in lsgrid.sliders),
		(m.selection for m in mgrid.menus)
	)
		on(update_working_df, observable)
	end

	x_var_menu = Menu(fig, options = regressables)
	y_var_menu = Menu(fig, options = regressables)
	coded_menu = Menu(fig, options = regressables)

	xs = @lift($working_df !== nothing && $(x_var_menu.selection) !== nothing ? $working_df[$(x_var_menu.selection)] : nothing)
	ys = @lift($working_df !== nothing && $(y_var_menu.selection) !== nothing ? $working_df[$(y_var_menu.selection)] : nothing)

	scatter = @lift(
		$xs !== nothing && $ys !== nothing && $(coded_menu.selection) !== nothing ?
			lines!(
				ax,
				$xs,
				$ys;
				color=$(coded_menu.selection)
			) : nothing
	)

	fig
end

plot(df)

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl

