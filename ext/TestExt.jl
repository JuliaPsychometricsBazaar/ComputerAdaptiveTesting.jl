module TestExt

using Test
using ComputerAdaptiveTesting: Stateful
using FittedItemBanks: AbstractItemBank, ItemResponse, resp_vec

export test_stateful_cat_1d_dich_ib, test_stateful_cat_item_bank_1d_dich_ib

function test_stateful_cat_1d_dich_ib(
        cat::Stateful.StatefulCat,
        item_bank_length;
        supports_ranked_and_criteria = true,
        supports_rollback = true
    )
    if item_bank_length < 3
        error("Item bank length must be at least 3.")
    end
    @testset "response round trip" begin
        responses_before = Stateful.get_responses(cat)
        @test length(responses_before.indices) == 0
        @test length(responses_before.values) == 0

        Stateful.add_response!(cat, 1, false)
        Stateful.add_response!(cat, 2, true)

        responses_after_add = Stateful.get_responses(cat)
        @test length(responses_after_add.indices) == 2
        @test length(responses_after_add.values) == 2

        Stateful.reset!(cat)
        responses_after_reset = Stateful.get_responses(cat)
        @test length(responses_after_reset.indices) == 0
        @test length(responses_after_reset.values) == 0
    end

    # Test the next_item function
    @testset "basic next_item tests" begin
        Stateful.add_response!(cat, 1, false)
        Stateful.add_response!(cat, 2, true)

        item = Stateful.next_item(cat)
        @test isa(item, Integer)
        @test item >= 1
        @test item >= 3
        @test item <= item_bank_length
    end

    if supports_ranked_and_criteria
        @testset "basic ranked/criteria tests" begin
            items = Stateful.ranked_items(cat)
            @test length(items) == item_bank_length

            criteria = Stateful.item_criteria(cat)
            @test length(criteria) == item_bank_length
        end
    end

    if supports_rollback
        @testset "basic rollback tests" begin
            Stateful.reset!(cat)
            Stateful.add_response!(cat, 1, false)
            Stateful.add_response!(cat, 2, true)
            Stateful.rollback!(cat)
            responses_after_rollback = Stateful.get_responses(cat)
            @test length(responses_after_rollback.indices) == 1
            @test length(responses_after_rollback.values) == 1
        end
    end

    @testset "basic get_ability tests" begin
        Stateful.reset!(cat)
        Stateful.add_response!(cat, 1, false)
        Stateful.add_response!(cat, 2, true)
        ability = Stateful.get_ability(cat)
        @test isa(ability, Tuple)
        @test length(ability) == 2
        @test isa(ability[1], Float64)
    end

    if supports_rollback
        @testset "rollback ability tests" begin
            Stateful.reset!(cat)
            Stateful.add_response!(cat, 1, false)
            ability1 = Stateful.get_ability(cat)
            Stateful.add_response!(cat, 2, true)
            ability2 = Stateful.get_ability(cat)
            Stateful.rollback!(cat)
            @test Stateful.get_ability(cat) == ability1
            Stateful.add_response!(cat, 2, true)
            @test Stateful.get_ability(cat) == ability2
        end
    end
end

function test_stateful_cat_item_bank_1d_dich_ib(
    cat::Stateful.StatefulCat,
    item_bank::AbstractItemBank,
    points=[-.78, 0.0, .78],
    margin=0.01,
)
    if length(item_bank) != Stateful.item_bank_size(cat)
        error("Item bank length does not match the cat's item bank size.")
    end
    for i in 1:length(item_bank)
        for point in points
            cat_prob = Stateful.item_response_functions(cat, i, point)
            ib_prob = resp_vec(ItemResponse(item_bank, i), point)
            @test cat_prob ≈ ib_prob  rtol=margin
        end
    end
end

function test_ability(
    cat1::Stateful.StatefulCat,
    cat2::Stateful.StatefulCat,
    item_bank_length;
    margin=0.01
)
    if item_bank_length < 4
        error("Item bank length must be at least 4.")
    end
    for cat in (cat1, cat2)
        Stateful.add_response!(cat, 1, false)
        Stateful.add_response!(cat, 2, true)
        Stateful.add_response!(cat, 3, false)
        Stateful.add_response!(cat, 4, true)
    end
    ability1 = Stateful.get_ability(cat1)
    ability2 = Stateful.get_ability(cat2)
    @test ability1[1] ≈ ability2[1]  rtol=margin
end

end