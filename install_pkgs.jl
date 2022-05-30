using Pkg
if !(length(ARGS) >= 2 && ARGS[2] == "skipcat")
  Pkg.develop(path=@__DIR__)
end
using ComputerAdaptiveTesting: install_extra

install_extra(length(ARGS) > 0 && ARGS[1] == "headless" ? "all_headless" : "all")
Pkg.add(
  url="https://github.com/JuliaMath/QuadGK.jl.git",
  rev="298f76e71be8a36d6e3f16715f601c3d22c2241c"
)
