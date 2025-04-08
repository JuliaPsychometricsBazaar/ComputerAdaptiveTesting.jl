using PrecompileTools

@setup_workload begin
    using PsychometricsBazaarBase: Integrators
    using FittedItemBanks: SimpleItemBankSpec, StdModel2PL, OneDimContinuousDomain, BooleanResponse
    using FittedItemBanks.DummyData: dummy_item_bank
    using Random: default_rng
    using .Aggregators: LikelihoodAbilityEstimator, MeanAbilityEstimator, GriddedAbilityTracker,
                        AbilityIntegrator
    using .NextItemRules: catr_next_item_aliases, preallocate
    using .Stateful: Stateful

    rng = default_rng(42)
    spec = SimpleItemBankSpec(StdModel2PL(), OneDimContinuousDomain(), BooleanResponse())
    item_bank = dummy_item_bank(rng, spec, 2)
    @compile_workload begin
        integrator = Integrators.even_grid(-6.0, 6.0, 61)
        lh_ability_est = LikelihoodAbilityEstimator()
        lh_grid_tracker = GriddedAbilityTracker(lh_ability_est, integrator)
        ability_integrator = AbilityIntegrator(integrator, lh_grid_tracker)
        ability_estimator = MeanAbilityEstimator(lh_ability_est, ability_integrator)
        next_item_rule = catr_next_item_aliases["MEPV"](ability_estimator)
        cat = Stateful.StatefulCatConfig(CatConfig.CatRules(;
            next_item=next_item_rule,
            termination_condition=TerminationConditions.RunForeverTerminationCondition(),
            ability_estimator=ability_estimator
        ), item_bank)
        Stateful.add_response!(cat, 1, 0)
        Stateful.next_item(cat)
    end
end