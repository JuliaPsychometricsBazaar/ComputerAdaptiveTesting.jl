using Test

include("./utils.jl")

using .CATTestUtils: @namedtestset

@namedtestset aqua "Aqua automated quality checks" begin
    include("./aqua.jl")
end

@namedtestset ability_estimator_1d "1-dimensional ability estimators" begin
    include("./ability_estimator_1d.jl")
end

@namedtestset ability_estimator_2d "1-dimensional ability estimators" begin
    include("./ability_estimator_2d.jl")
end

@namedtestset smoke "Smoke tests" begin
    include("./smoke.jl")
end
