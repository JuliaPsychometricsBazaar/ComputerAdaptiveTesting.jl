using Makie
import Pkg
if isdefined(Main, :IJulia) && Main.IJulia.inited
    using WGLMakie
elseif "GLMakie" in keys(Pkg.project().dependencies)
    using GLMakie
else
    using CairoMakie
end
using Distributions: Normal, cdf
using ComputerAdaptiveTesting.ExtraDistributions: NormalScaledLogistic

xs = -8:0.05:8
lines(xs, cdf.(Normal(), xs))
lines!(xs, cdf.(NormalScaledLogistic(), xs))
current_figure()

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl

