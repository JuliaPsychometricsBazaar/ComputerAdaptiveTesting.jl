using ComputerAdaptiveTesting.DummyData: dummy_3pl, std_normal, dummy_mirt_4pl

const optimizers_1d = [
    FunctionOptimizer(OneDimOptimOptimizer(-6.0, 6.0, NelderMead())),
]
const integrators_1d = [
    FunctionIntegrator(QuadGKIntegrator(-6, 6, 5)),
    FunctionIntegrator(FixedGKIntegrator(-6, 6, 80)),
]
const ability_estimators_1d = [
    (integrator, optimizer) -> MeanAbilityEstimator(PriorAbilityEstimator(std_normal), integrator),
    (integrator, optimizer) -> ModeAbilityEstimator(PriorAbilityEstimator(std_normal), optimizer),
    (integrator, optimizer) -> MeanAbilityEstimator(LikelihoodAbilityEstimator(), integrator),
    (integrator, optimizer) -> ModeAbilityEstimator(LikelihoodAbilityEstimator(), optimizer),
]
const criteria_1d = [
    (integrator, optimizer, est) -> AbilityVarianceStateCriterion(MeanAbilityEstimator(distribution_estimator(est), integrator)),
    (integrator, optimizer, est) -> InformationItemCriterion(est),
    (integrator, optimizer, est) -> UrryItemCriterion(est),
]

@testset "Smoke test 1d" begin
    Random.seed!(42)
    (item_bank, question_labels, abilities, true_responses) = dummy_3pl(; num_questions=4, num_testees=2)
    for optimizer in optimizers_1d
        for integrator in integrators_1d
            for mk_ability_estimator in ability_estimators_1d
                ability_estimator = mk_ability_estimator(integrator, optimizer)
                for mk_criterion in criteria_1d
                    criterion = mk_criterion(integrator, optimizer, ability_estimator)
                    rules = CatRules(
                        ability_estimator,
                        criterion,
                        FixedItemsTerminationCondition(2)
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
                        if !(ability_estimator isa ModeAbilityEstimator)
                            @test -6.1 < ability < 6.1
                        end
                    end
                end
            end
        end
    end
end

#=
@testset "Smoke test 2d" begin
    Random.seed!(42)
    (item_bank, question_labels, abilities, responses) = dummy_mirt_4pl(2; num_questions=4, num_testees=2)
end
=#