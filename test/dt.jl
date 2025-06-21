(item_bank, abilities, true_responses) = dummy_full(
    Random.default_rng(42),
    SimpleItemBankSpec(StdModel3PL(), OneDimContinuousDomain(), BooleanResponse());
    num_questions = 20,
    num_testees = 1
)
integrator = FunctionIntegrator(Integrators.even_grid(-6, 6, 61))
ability_estimator = MeanAbilityEstimator(LikelihoodAbilityEstimator(), integrator)
get_response = auto_responder(@view true_responses[:, 1])

@testset "decision tree round trip" begin
    next_item_rule = ItemStrategyNextItemRule(
        AbilityVarianceStateCriterion(
            distribution_estimator(ability_estimator), integrator),
        ability_estimator = ability_estimator
    )
    termination_condition = FixedItemsTerminationCondition(4)

    cat_rules = CatRules(
        next_item = next_item_rule,
        termination_condition = termination_condition,
        ability_estimator = ability_estimator
    )
    cat_loop_config = CatLoop(
        rules = cat_rules,
        get_response = get_response
    )
    tracked_responses_cat, final_ability_cat = run_cat(cat_loop_config, item_bank)

    dt_generation_config = DecisionTreeGenerationConfig(
        max_depth = UInt(3),
        next_item = next_item_rule,
        ability_estimator = ability_estimator
    )
    dt_materialized = generate_dt_cat(dt_generation_config, item_bank)
    dt_loop_config = CatLoop(
        rules = dt_materialized,
        get_response = get_response
    )
    responses_dt, final_ability_dt = run_cat(dt_loop_config, item_bank)

    @test tracked_responses_cat == responses_dt
    @test final_ability_cat == final_ability_dt

    tempdir = mktempdir()
    save_mmap(tempdir, dt_materialized)
    dt_rt = load_mmap(tempdir)
    dt_rt_loop_config = CatLoop(
        rules = dt_rt,
        get_response = get_response
    )
    tracked_responses_dt_rt, final_ability_dt_rt = run_cat(dt_rt_loop_config, item_bank)

    @test tracked_responses_cat == tracked_responses_dt_rt
    @test final_ability_cat == final_ability_dt_rt
end
