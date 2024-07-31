using JET

@testset "JET checks" begin
    rep = report_package(ComputerAdaptiveTesting)
    @show rep
    @test length(JET.get_reports(rep)) <= 43
    @test_broken length(JET.get_reports(rep)) == 0
end
