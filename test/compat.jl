@testset "Compat" begin
    using FittedItemBanks.DummyData: dummy_full
    using FittedItemBanks: OneDimContinuousDomain, SimpleItemBankSpec, StdModel3PL,
                        BooleanResponse
    using ComputerAdaptiveTesting.Aggregators: TrackedResponses, NullAbilityTracker
    using ComputerAdaptiveTesting.TerminationConditions: FixedItemsTerminationCondition
    using ComputerAdaptiveTesting.NextItemRules: RandomNextItemRule
    using ComputerAdaptiveTesting.Responses: BareResponses, ResponseType
    using ComputerAdaptiveTesting: Stateful
    using ComputerAdaptiveTesting: require_testext
    using ComputerAdaptiveTesting.ItemBanks: LogItemBank
    using ComputerAdaptiveTesting.NextItemRules: best_item
    using ComputerAdaptiveTesting: Compat
    using Test: @test, @testset

    #include("./dummy.jl")
    #using .Dummy
    using Random

    rng = Random.default_rng(42)
    (item_bank, abilities, true_responses) = dummy_full(
        Random.default_rng(42),
        SimpleItemBankSpec(StdModel3PL(), OneDimContinuousDomain(), BooleanResponse());
        num_questions = 4,
        num_testees = 1
    )
    half_responses = BareResponses(
        ResponseType(item_bank),
        [1, 2],
        Vector{Bool}(true_responses[1:2, 1])
    )

    @testset "CatJL" begin
        log_item_bank = LogItemBank(item_bank)
        tracked_responses = TrackedResponses(half_responses, log_item_bank, NullAbilityTracker())
        for method in ("EAP", "MAP", "ML")
            @testset "Ability estimation $method" begin
                rules = Compat.MirtCAT.assemble_rules(;
                    criteria="MI",
                    method
                )
                @test -6.0 <= rules.ability_estimator(tracked_responses) <= 6.0
            end
        end
        for criteria in ("MI", "MEPV")
            @testset "Next item $criteria" begin
                rules = Compat.MirtCAT.assemble_rules(;
                    criteria,
                    method="EAP"
                )
                @test best_item(rules.next_item, tracked_responses) in 3:4
            end
        end
    end

    @testset "CatR" begin
        tracked_responses = TrackedResponses(half_responses, item_bank, NullAbilityTracker())
        for method in ("EAP", "BM", "ML")
            @testset "Ability estimation $method" begin
                rules = Compat.CatR.assemble_rules(;
                    criterion="MFI",
                    method
                )
                @test -6.0 <= rules.ability_estimator(tracked_responses) <= 6.0
            end
        end
        for criterion in ("MFI", "bOpt", "MEPV", "MEI")
            @testset "Next item $criterion" begin
                rules = Compat.CatR.assemble_rules(;
                    criterion,
                    method="EAP"
                )
                @test best_item(rules.next_item, tracked_responses) in 3:4
            end
        end
    end
end