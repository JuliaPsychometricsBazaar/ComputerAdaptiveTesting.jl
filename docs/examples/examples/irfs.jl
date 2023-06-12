#md # Item Response Functions

using Makie
import Pkg
using Distributions: Normal, cdf
using PsychometricsBazaarBase.ConstDistributions: normal_scaled_logistic
using CATPlots

@automakie()

# Typically, the logistic c.d.f. is used as the transfer function in IRT.
# However, it in an IRT context, a scaled version intended to be close to a
# normal c.d.f. is often used. The main advantage is that this is usually faster
# to compute. ComputerAdaptiveTesting provides normal_scaled_logistic, which is
# also used by default, for this purpose:

xs = -8:0.05:8
lines(xs, cdf.(Normal(), xs))
lines!(xs, cdf.(normal_scaled_logistic, xs))
current_figure()
