using ComputerAdaptiveTesting
using Test
using Aqua

Aqua.test_all(ComputerAdaptiveTesting)

@testset "Smoke test" begin
    using ComputerAdaptiveTesting.DummyData: dummy_3pl, std_normal
    Random.seed!(42)
    (item_bank, question_labels, abilities, responses) = dummy_3pl(;num_questions=100, num_testees=3)
end
