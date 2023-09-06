using Makie
import Pkg
using Distributions: Normal, cdf
using PsychometricsBazaarBase.ConstDistributions: normal_scaled_logistic
using CATPlots

@automakie()

xs = -8:0.05:8
lines(xs, cdf.(Normal(), xs))
lines!(xs, cdf.(normal_scaled_logistic, xs))
current_figure()

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
