using Pkg
Pkg.develop(path=@__DIR__)
using ComputerAdaptiveTesting: install_extra
install_extra("all")
Pkg.add(url="https://github.com/JuliaMath/QuadGK.jl.git", rev="298f76e71be8a36d6e3f16715f601c3d22c2241c")