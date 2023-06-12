using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.Aggregators
using FittedItemBanks
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.TerminationConditions
using ComputerAdaptiveTesting.Sim
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.Optimizers
using Distributions: ScalMat

"""
First 4 questions are centered on ability 1.
The next ones are used to sanity check information/variance.
"""
function mk_dummy_2d_data()
    item_bank = ItemBankMirt2PL(
        [0.8, 0.9, 1.1, 1.2, 0.99, 0.0, 0.99, 0.99],
        [
            1.0 1.0 1.0 1.0 1.0 1.0 2.0 1.0;
            1.0 1.0 1.0 1.0 1.0 1.0 1.0 2.0
        ]
    )
    responses = BareResponses(
        ResponseType(item_bank),
        [1, 2, 3, 4],
        [false, false, true, true]
    )
    (item_bank, responses)
end

item_bank_2d, responses_2d = mk_dummy_2d_data()
tracked_responses_2d = TrackedResponses(responses_2d, item_bank_2d, NullAbilityTracker())

integrator_2d = AbilityIntegrator(MultiDimFixedGKIntegrator([-6.0, -6.0], [6.0, 6.0], 61))
optimizer_2d = AbilityOptimizer(MultiDimOptimOptimizer([-6.0, -6.0], [6.0, 6.0], NelderMead()))
lh_est_2d = LikelihoodAbilityEstimator()
pa_est_2d = PriorAbilityEstimator(MvNormal([1.0, 1.0], ScalMat(2, 0.2)))
eap_2d = MeanAbilityEstimator(pa_est_2d, integrator_2d)
map_2d = ModeAbilityEstimator(pa_est_2d, optimizer_2d)
mle_mean_2d = MeanAbilityEstimator(lh_est_2d, integrator_2d)
mle_mode_2d = ModeAbilityEstimator(lh_est_2d, optimizer_2d)

@testset "Estimator: 2 dim MAP" begin
    @test map_2d(tracked_responses_2d) ≈ [1.0, 1.0] atol=0.001
end

@testset "Estimator: 2 dim EAP" begin
    @test eap_2d(tracked_responses_2d) ≈ [1.0, 1.0] atol=0.001
end

# XXX: Why are these failing?
@testset "Estimator: 2 mle mean" begin
    @test mle_mean_2d(tracked_responses_2d) ≈ [1.0, 1.0] atol=0.001 broken=true
end

@testset "Estimator: 2 mle mode" begin
    @test mle_mode_2d(tracked_responses_2d) ≈ [1.0, 1.0] atol=0.001 broken=true
end

# TODO
#=
@testset "2 dim information higher closer to current estimate" begin
end

@testset "2 dim variance smaller closer to current estimate" begin
end
=#