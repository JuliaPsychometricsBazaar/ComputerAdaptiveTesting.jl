using JET
using Optim: Optim

@testset "JET checks" begin
    rep = report_package(
        ComputerAdaptiveTesting;
        ignored_modules=(
            ComputerAdaptiveTesting.Comparison,
            ComputerAdaptiveTesting.PushVectors,
            Base.Broadcast,
            Optim
        ),
        mode=:typo
    )
    @show rep
    @test length(JET.get_reports(rep)) == 5
    @test_broken length(JET.get_reports(rep)) == 0
end
