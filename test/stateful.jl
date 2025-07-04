@testset "Stateful" begin
    using ComputerAdaptiveTesting: CatRules
    using FittedItemBanks.DummyData: dummy_full
    using FittedItemBanks: OneDimContinuousDomain, SimpleItemBankSpec, StdModel3PL,
                        BooleanResponse
    using ComputerAdaptiveTesting.TerminationConditions: FixedLength
    using ComputerAdaptiveTesting.NextItemRules: RandomNextItemRule
    using ComputerAdaptiveTesting: Stateful
    using ComputerAdaptiveTesting: require_testext
    using Test: @test, @testset

    include("./dummy.jl")
    using .Dummy
    using Random

    rng = Random.default_rng(42)

    # Create test data
    (item_bank, abilities, true_responses) = dummy_full(
        rng,
        SimpleItemBankSpec(StdModel3PL(), OneDimContinuousDomain(), BooleanResponse());
        num_questions = 4,
        num_testees = 2
    )

    @testset "StatefulCatRules basic usage" begin
        rules = CatRules(
            FixedLength(2),
            Dummy.DummyAbilityEstimator(0.0),
            RandomNextItemRule()
        )

        # Initialize config
        cat_config = Stateful.StatefulCatRules(rules, item_bank)

        # Test initialization state
        @test isempty(Stateful.get_responses(cat_config))

        # Add responses and check state
        Stateful.add_response!(cat_config, 1, true)
        Stateful.add_response!(cat_config, 2, false)

        @test length(Stateful.get_responses(cat_config).indices) == 2

        # Test ability estimation
        ability, _ = Stateful.get_ability(cat_config)
        @test ability isa Real

        # Test reset
        Stateful.reset!(cat_config)
        @test isempty(Stateful.get_responses(cat_config))
    end

    @testset "Stateful next item selection" begin
        rules = CatRules(
            FixedLength(2),
            Dummy.DummyAbilityEstimator(0.0),
            RandomNextItemRule()
        )
        cat_config = Stateful.StatefulCatRules(rules, item_bank)

        # Test first item selection
        first_item = Stateful.next_item(cat_config)
        @test 1 <= first_item <= 4

        # Add response and test next item
        Stateful.add_response!(cat_config, first_item, true)
        second_item = Stateful.next_item(cat_config)
        @test 1 <= second_item <= 4
        @test second_item != first_item  # Should select different item
    end

    @testset "Standard interface tests" begin
        rules = CatRules(
            FixedLength(2),
            Dummy.DummyAbilityEstimator(0.0),
            RandomNextItemRule()
        )

        # Initialize config
        cat_config = Stateful.StatefulCatRules(rules, item_bank)

        # Run the standard interface tests
        TestExt = require_testext()
        TestExt.test_stateful_cat_1d_dich_ib(
            cat_config,
            4;
            supports_ranked_and_criteria = false,
        )
        TestExt.test_stateful_cat_item_bank_1d_dich_ib(cat_config, item_bank)
    end
end
