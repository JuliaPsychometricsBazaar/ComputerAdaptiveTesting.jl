using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.Aggregators
using FittedItemBanks.DummyData: dummy_full, SimpleItemBankSpec, StdModel3PL,
      VectorContinuousDomain, BooleanResponse, std_normal
using FittedItemBanks
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.TerminationConditions
using ComputerAdaptiveTesting.Sim
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.Optimizers
using Distributions
using Distributions: ZeroMeanIsoNormal, Zeros, ScalMat
using Optim
using Random
using ResumableFunctions

#(item_bank, abilities, responses) = dummy_full(Random.default_rng(42), SimpleItemBankSpec(StdModel4PL(), VectorContinuousDomain(), BooleanResponse()), 2; num_questions=100, num_testees=3)


@testcase "Smoke test 1d" begin
    (item_bank, abilities, true_responses) = dummy_full(
        Random.default_rng(42),
        SimpleItemBankSpec(StdModel3PL(), OneDimContinuousDomain(), BooleanResponse());
        num_questions=4,
        num_testees=2
    )

    function test1d(ability_estimator, bits...)
        rules = CatRules(
            FixedItemsTerminationCondition(2),
            ability_estimator,
            bits...
        )
        for testee_idx in axes(true_responses, 2)
            tracked_responses, ability = run_cat(
                CatLoopConfig(
                    rules=rules,
                    get_response=auto_responder(@view true_responses[:, testee_idx])
                ),
                item_bank
            )
            # Test CAT has run to termination condition
            @test length(tracked_responses.responses.indices) == 2 && length(tracked_responses.responses.values) == 2
            # Test ability within integral/optimization domain
            # TODO: Should mode ability estimator be made to return something in range?
            if !(ability_estimator isa ModeAbilityEstimator) && !(ability_estimator isa Dummy.DummyAbilityEstimator)
                @test -6.1 < ability < 6.1
            end
        end
    end
    for (criterion_needed, mk_criterion) in Dummy.criteria_1d
        for stuff in Dummy.get_stuffs(Set(criterion_needed))
            if stuff == NamedTuple()
                continue
            end
            criterion = mk_criterion(stuff)
            test1d(stuff.est, criterion)
        end
    end
end

#=
@testset "Smoke test 2d" begin
    Random.seed!(42)
    (item_bank, abilities, responses) = dummy_mirt_4pl(2; num_questions=4, num_testees=2)
end
=#
