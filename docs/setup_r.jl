ENV["R_HOME"] = "*"

using RCall
using Conda

Conda.add("r-mirt"; channel="conda-forge")
params = R"""
library(mirt)
"""