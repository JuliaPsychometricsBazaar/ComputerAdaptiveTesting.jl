```@meta
CurrentModule = ComputerAdaptiveTesting
```

# API reference

## Likelihood-weighted criteria

`NextItemRules.LikelihoodWeightedItemCriterion` and
`NextItemRules.LikelihoodWeightedItemCategoryCriterion` integrate their
pointwise criterion against an unnormalized ability density. Their ability
integrator applies the response likelihood and, when using a posterior
estimator, the prior once. The pointwise criterion supplies only its value at
the ability being integrated.

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

`Aggregators.ModeAbilityEstimator` with `Aggregators.FunctionOptimizer` maximizes
this log density directly for MLE/MAP. This also applies to the explicit
`optimizer(IntegralCoeffs.one, distribution_estimator, tracked_responses)` call.
General coefficient-weighted objectives, including signed objectives, and
the two-argument `optimizer(coefficient, density_function)` interface retain
their probability-space product semantics. Custom `AbilityOptimizer`s control
their own objective evaluation.

`DerivedMeasures.LaplaceApproxEstimator` evaluates log-density curvature directly
at the mode. Its result remains `(mode, negative_second_derivative)`: the second
value is precision, not standard deviation. Mean estimators and integrators
are unchanged. Custom distribution estimators used for log-density optimization
implement the two-argument `logpdf` method; there is no automatic fallback through
`log(pdf(...))`.

```@docs
ComputerAdaptiveTesting.DerivedMeasures.LaplaceApproxEstimator
```

```@index
```

```@autodocs
Modules = [ComputerAdaptiveTesting, ComputerAdaptiveTesting.Aggregators, ComputerAdaptiveTesting.Responses, ComputerAdaptiveTesting.Sim, ComputerAdaptiveTesting.TerminationConditions, ComputerAdaptiveTesting.NextItemRules, ComputerAdaptiveTesting.Rules, ComputerAdaptiveTesting.Stateful, ComputerAdaptiveTesting.DecisionTree, ComputerAdaptiveTesting.Compat, ComputerAdaptiveTesting.Comparison, ComputerAdaptiveTesting.ConfigBase]
```
