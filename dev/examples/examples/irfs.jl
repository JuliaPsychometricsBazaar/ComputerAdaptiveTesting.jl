using Makie
import Pkg
using Distributions: Normal, cdf
using ComputerAdaptiveTesting.ExtraDistributions: NormalScaledLogistic
using CATPlots

@automakie()

xs = -8:0.05:8
lines(xs, cdf.(Normal(), xs))
lines!(xs, cdf.(NormalScaledLogistic(), xs))
current_figure()

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl

