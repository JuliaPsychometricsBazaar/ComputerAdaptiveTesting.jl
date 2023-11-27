mutable struct ClosedFormNormalAbilityTracker <: AbilityTracker
    cur_ability::VarNormal
end

function ClosedFormNormalAbilityTracker(prior_ability_estimator::PriorAbilityEstimator)
    @warn "ClosedFormNormalAbilityTracker is based on equations from Liden 1998 / Owen 1975, but these appear to give poor results"
    prior = prior_ability_estimator.prior
    if !(prior isa Normal)
        error("ClosedFormNormalAbilityTracker only works with Normal priors")
    end
    ClosedFormNormalAbilityTracker(VarNormal(prior.μ, prior.σ^2))
end

function ClosedFormNormalAbilityTracker(mean, var)
    ClosedFormNormalAbilityTracker(VarNormal(mean, var))
end

function track!(responses, ability_tracker::ClosedFormNormalAbilityTracker)
    resp_idx = responses.responses.indices[end]
    resp_val = responses.responses.values[end]
    ability_tracker.cur_ability = update_normal_approx(ability_tracker.cur_ability,
        item_params(responses.item_bank, resp_idx),
        resp_val)
end

ϕ(x) = Distributions.pdf(std_normal, x)
Φ(x) = Distributions.cdf(std_normal, x)

function update_normal_approx(ability, new_item, response)
    # * 1.702
    a = new_item.discrimination
    b = new_item.difficulty
    c = new_item.guess
    mean = ability.mean
    var = ability.var
    #=
    if response > 0
        # A3
        new_mean = mean - 0.5 * var * (a ^ -2 + var) ^ 0.5
        # A4
        factor = 1 - (1 + a ^ -2 * var ^ -1) ^ -1
    else
        # A5
        new_mean = mean + 0.5 * var * (a ^ -2 + var) ^ 0.5 * (1 - c ^ 2)
        # A6
        factor = 1 - (1 + a ^ -2 * var ^ -1) ^ -1 * (1 + c) ^ -2
    end
    new_var = var * factor
    =#
    ξ = (b - mean) / sqrt(a^-2 + var)
    if response > 0
        # Liden 1998 has the following but Owen 1975 put the sign the other way
        #ζ = c + (1 - c) * Φ(ξ)
        ζ = c + (1 - c) * Φ(-ξ)
        # This ζ is expanded in both Linden and Owen
        mean_shift = (1 - c) * var * (a^-2 + var)^-0.5 * ϕ(ξ) * ζ
        var_factor = 1 -
                     (1 - c) * (1 + a^-2 * var^-1)^-1 * ϕ(ξ) * ((1 - c) * ϕ(ξ) / ζ - ξ) / ζ
        @info "U=1" mean_shift var_factor
    else
        # Liden 1998 has the following but Owen 1975 divided instead of multipied
        #mean_shift = -(var * (a ^ -2 + var) ^ -0.5 * ϕ(ξ) * Φ(ξ))
        mean_shift = -(var * (a^-2 + var)^-0.5 * ϕ(ξ) / Φ(ξ))
        # In Linden 1998 the ϕ(ξ) term is missing versus Owen 1975
        # var_factor = 1 - (1 + a ^ -2 * var ^ -1) ^ -1 * (ϕ(ξ) / Φ(ξ) + ξ) / Φ(ξ)
        var_factor = 1 - (1 + a^-2 * var^-1)^-1 * ϕ(ξ) * (ϕ(ξ) / Φ(ξ) + ξ) / Φ(ξ)
        @info "U=0" mean_shift var_factor
    end
    new_mean = mean + mean_shift
    new_var = var * var_factor
    VarNormal(new_mean, new_var)
end
