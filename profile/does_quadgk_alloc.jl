using QuadGK
using Distributions
using Profile

const int_tol = 1e-6
const std_norm = Normal()
norm_cdf = x -> cdf(std_norm, x)
quadgk(norm_cdf, -10.0, 1.0, int_tol)[1]
Profile.clear_malloc_data() 
quadgk(norm_cdf, -10.0, 1.0, int_tol)[1]