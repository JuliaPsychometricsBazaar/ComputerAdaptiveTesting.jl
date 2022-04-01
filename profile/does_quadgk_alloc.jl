using QuadGK
using Distributions
using Profile

const INT_TOL = 1e-6
const std_norm = Normal()
norm_cdf = x -> cdf(std_norm, x)
quadgk(norm_cdf, -10.0, 1.0, INT_TOL)[1]
Profile.clear_malloc_data() 
quadgk(norm_cdf, -10.0, 1.0, INT_TOL)[1]