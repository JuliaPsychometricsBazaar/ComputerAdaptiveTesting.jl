using JuliaFormatter
using ComputerAdaptiveTesting

@testset "format" begin
    dir = pkgdir(ComputerAdaptiveTesting)
    @test format(dir * "/src"; overwrite = false)
    @test format(dir * "/test"; overwrite = false)
end
