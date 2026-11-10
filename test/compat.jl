@testset "Compat" begin
    using FittedItemBanks.DummyData: dummy_full
    using FittedItemBanks: OneDimContinuousDomain, SimpleItemBankSpec, StdModel3PL,
                        BooleanResponse
    using ComputerAdaptiveTesting.Aggregators: TrackedResponses, NullAbilityTracker
    using ComputerAdaptiveTesting.TerminationConditions: FixedLength
    using ComputerAdaptiveTesting.NextItemRules: RandomNextItemRule
    using ComputerAdaptiveTesting.Responses: BareResponses, ResponseType
    using ComputerAdaptiveTesting: Stateful
    using ComputerAdaptiveTesting: require_testext
    using ComputerAdaptiveTesting.NextItemRules: best_item
    using ComputerAdaptiveTesting: Compat
    using Test: @test, @testset

    #include("./dummy.jl")
    #using .Dummy
    using Random

    (item_bank, abilities, true_responses) = dummy_full(
        Random.Xoshiro(42),
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
        tracked_responses = TrackedResponses(half_responses, item_bank, NullAbilityTracker())
        for method in ("EAP", "MAP", "ML")
            @testset "Ability estimation $method" begin
                rules = Compat.MirtCAT.assemble_rules(;
                    criteria="MI",
                    method
                )
                # EAP uses the integration interval. MAP and ML use the optimizer's bounds.
                limit = method == "EAP" ? 6.0 : 20.0
                @test -limit <= rules.ability_estimator(tracked_responses) <= limit
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
