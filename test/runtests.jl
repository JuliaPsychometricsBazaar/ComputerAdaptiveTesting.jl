using XUnit

include("./dummy.jl")
using .Dummy


@testset "aqua" begin
    include("./aqua.jl")
end

@testset "abilest_1d" begin
    include("./ability_estimator_1d.jl")
end

@testset "abilest_2d" begin
    include("./ability_estimator_2d.jl")
end

@testset "smoke" begin
    include("./smoke.jl")
end
