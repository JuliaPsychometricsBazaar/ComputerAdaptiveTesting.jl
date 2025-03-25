using JET
using Optim: Optim

@testset "jet" begin
    rep = report_package(
        ComputerAdaptiveTesting;
        target_modules = (
            ComputerAdaptiveTesting,
        ),
        mode = :typo
    )
    @show rep
    @test length(JET.get_reports(rep)) == 0
end
