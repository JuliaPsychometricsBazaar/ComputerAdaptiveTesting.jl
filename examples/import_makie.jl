using Makie
import Pkg
if isdefined(Main, :IJulia) && Main.IJulia.inited
    using WGLMakie
elseif "GLMakie" in keys(Pkg.project().dependencies)
    using GLMakie
else
    using CarioMakie
end