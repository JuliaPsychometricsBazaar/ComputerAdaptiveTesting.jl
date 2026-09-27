```@meta
CurrentModule = ComputerAdaptiveTesting
```

# API reference

## Log-density interface

`Responses.AbilityLogLikelihood` wraps an `AbilityLikelihood`, or can be
constructed directly from an item bank and `BareResponses`, or from
`Aggregators.TrackedResponses`. Calling it sums the item bank's native
`FittedItemBanks.log_resp` values. It does not first multiply probabilities.

`Distributions.logpdf(est, tracked_responses)` returns a callable log density;
`Distributions.logpdf(est, tracked_responses, θ)` evaluates it at `θ`. Likelihood,
posterior and guarded distribution estimators support this interface. Posterior
log densities add `Distributions.logpdf(prior, θ)` directly. Like the existing
`pdf` interface, these densities are **unnormalized**.

```jldoctest
julia> using ComputerAdaptiveTesting.Responses, ComputerAdaptiveTesting.Aggregators,
           FittedItemBanks, Distributions

julia> bank = ItemBank2PL([0.0, 0.0], [1.0, 1.0]);

julia> history = BareResponses(ResponseType(bank), [1, 2], [false, true]);

julia> tracked = TrackedResponses(history, bank);

julia> AbilityLogLikelihood(tracked)(0.0) ≈ log(0.25)
true

julia> est = PosteriorAbilityEstimator(Normal());

julia> logpdf(est, tracked)(0.0) ≈ logpdf(est, tracked, 0.0) ≈ log(0.25) + logpdf(Normal(), 0.0)
true
```

For tabulated dichotomous banks, `Responses.function_log_ys(likelihood)` returns
log likelihoods on `Responses.function_xs(likelihood)`. Equivalently,
`Responses.function_ys(AbilityLogLikelihood(likelihood))` returns these log values.
An empty response history returns zeros; impossible responses produce `-Inf`.
Use `FittedItemBanks.DichotomousPointsWithLogsItemBank` to reuse the item log cache
across calls. Constructing logs from a table cannot recover probabilities that
were already rounded to zero or one.

This interface does not change the algorithms used by mean/mode estimators or
integrators. Custom distribution estimators implement the two-argument `logpdf`
method; there is no automatic fallback through `log(pdf(...))`.

```@index
```

```@autodocs
Modules = [ComputerAdaptiveTesting, ComputerAdaptiveTesting.Aggregators, ComputerAdaptiveTesting.Responses, ComputerAdaptiveTesting.Sim, ComputerAdaptiveTesting.TerminationConditions, ComputerAdaptiveTesting.NextItemRules, ComputerAdaptiveTesting.Rules, ComputerAdaptiveTesting.Stateful, ComputerAdaptiveTesting.DecisionTree, ComputerAdaptiveTesting.Compat, ComputerAdaptiveTesting.Comparison, ComputerAdaptiveTesting.ConfigBase]
```
