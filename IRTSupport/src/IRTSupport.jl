module IRTSupport

"""
This package contains various support functions for the ComputerAdaptiveTesting
package. Currently it does not fit IRT models itself but instead provides various utilities
including:
 * `Wrap`: Wrappers for IRT packages written in R 
 * `Postprocess`: Functions to postprocess IRT models
 * `Datasets`: Item-response datasets
"""

include("./wrap/Wrap.jl")
include("./datasets/Datasets.jl")
include("./postprocess/Postprocess.jl")

export Datasets
export Postprocess
export Wrap

end