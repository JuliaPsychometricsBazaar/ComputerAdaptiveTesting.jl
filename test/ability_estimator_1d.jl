using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.Aggregators
using FittedItemBanks
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.TerminationConditions
using ComputerAdaptiveTesting.Sim
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.Optimizers
using Distributions

"""
First 4 questions are centered on ability 1.
The next ones are used to sanity check information/variance.
"""
function mk_dummy_1d_data()
    item_bank = ItemBank2PL(
        [0.8, 0.9, 1.1, 1.2, 0.99, 0.0, 0.99, 0.99],
        [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 2.0, 0.5]
    )
    responses = BareResponses(
        ResponseType(item_bank),
        [1, 2, 3, 4],
        [false, false, true, true]
    )
    (item_bank, responses)
end

item_bank_1d, responses_1d = mk_dummy_1d_data()
tracked_responses_1d = TrackedResponses(responses_1d, item_bank_1d, NullAbilityTracker())

integrator_1d = AbilityIntegrator(FixedGKIntegrator(-6.0, 6.0, 61))
optimizer_1d = AbilityOptimizer(OneDimOptimOptimizer(-6.0, 6.0, NelderMead()))
lh_est_1d = LikelihoodAbilityEstimator()
pa_est_1d = PosteriorAbilityEstimator(Normal(1.0, 0.2))
eap_1d = MeanAbilityEstimator(pa_est_1d, integrator_1d)
map_1d = ModeAbilityEstimator(pa_est_1d, optimizer_1d)
mle_mean_1d = MeanAbilityEstimator(lh_est_1d, integrator_1d)
mle_mode_1d = ModeAbilityEstimator(lh_est_1d, optimizer_1d)

@testset "abilest_1d" begin
    @testset "Estimator: single dim MAP" begin
        @test map_1d(tracked_responses_1d)≈1.0 atol=0.001
    end

    @testset "Estimator: single dim EAP" begin
        @test eap_1d(tracked_responses_1d)≈1.0 atol=0.001
    end

    @testset "Estimator: single mle mean" begin
        @test mle_mean_1d(tracked_responses_1d)≈1.0 atol=0.001
    end

    @testset "Estimator: single mle mode" begin
        @test mle_mode_1d(tracked_responses_1d)≈1.0 atol=0.001
    end

    information_item_criterion = InformationItemCriterion(mle_mean_1d)

    @testset "1 dim neg information smaller closer to current estimate" begin
        @test (
            compute_criterion(information_item_criterion, tracked_responses_1d, 5) <
            compute_criterion(information_item_criterion, tracked_responses_1d, 6)
        )
    end

    @testset "1 dim neg information smaller with igher discrimination" begin
        @test (
            compute_criterion(information_item_criterion, tracked_responses_1d, 7) <
            compute_criterion(information_item_criterion, tracked_responses_1d, 5) <
            compute_criterion(information_item_criterion, tracked_responses_1d, 8)
        )
    end

    ability_variance_state_criterion = AbilityVarianceStateCriterion(
        lh_est_1d, integrator_1d)
    ability_variance_item_criterion = ExpectationBasedItemCriterion(
        mle_mean_1d,
        ability_variance_state_criterion
    )

    @testset "postposterior 1 dim variance smaller closer to current estimate" begin
        @test (
            compute_criterion(ability_variance_item_criterion, tracked_responses_1d, 5) <
            compute_criterion(ability_variance_item_criterion, tracked_responses_1d, 6)
        )
    end

    @testset "postposterior 1 dim variance smaller with higher discrimination" begin
        @test (
            compute_criterion(ability_variance_item_criterion, tracked_responses_1d, 7) <
            compute_criterion(ability_variance_item_criterion, tracked_responses_1d, 5) <
            compute_criterion(ability_variance_item_criterion, tracked_responses_1d, 8)
        )
    end

    @testset "1 dim variance decreases with new responses" begin
        orig_var = compute_criterion(ability_variance_state_criterion, tracked_responses_1d)
        next_responses = deepcopy(tracked_responses_1d)
        add_response!(next_responses, Response(ResponseType(item_bank_1d), 5, 0))
        new_var = compute_criterion(ability_variance_state_criterion, next_responses)
        @test new_var < orig_var
    end
end
