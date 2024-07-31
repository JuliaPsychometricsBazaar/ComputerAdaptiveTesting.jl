using JuliaFormatter

@testcase "format" begin
    @test format("src"; overwrite = false)
    @test format("test"; overwrite = false)
end
