```@meta
CurrentModule = ComputerAdaptiveTesting
```

# API reference

## Density integration policies

`PosteriorAbilityEstimator(prior, LogSpace())` and
`LikelihoodAbilityEstimator(LogSpace())` select log-density integration when
constructing an integrator from a numerical backend. Config bits may be given
in either order; omitting the space defaults to `LinSpace()`.
`SafeLikelihoodAbilityEstimator(LogSpace(); ncomp=2)` applies the same policy to
both its likelihood and prior fallback branches.

`MeanAbilityEstimator(dist, grid)` selects `LogGridIntegrator` for a log-space
estimator and a supported equal-weight grid. With a supported continuous backend,
also supply a maximizing optimizer: `MeanAbilityEstimator(dist, backend, optimizer)`.
An explicitly constructed `AbilityIntegrator` overrides the default policy.
Both `pdf` and `logpdf` remain available in either space; density modes continue
to maximize `logpdf`. Normalized moments remain ordinary numbers.

```@docs
Aggregators.CalculationSpace
Aggregators.LinSpace
Aggregators.LogSpace
Aggregators.calculation_space
```

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
value is precision, not standard deviation. Custom distribution estimators used for log-density optimization
implement the two-argument `logpdf` method; there is no automatic fallback through
`log(pdf(...))`.

## Fixed-grid log normalization and tracking

`Aggregators.LogGridIntegrator` opts into stable fixed-grid inference. Wrap a
`PsychometricsBazaarBase.Integrators.FixedGridIntegrator`, its preallocated form,
or an `IterativeFixedGridIntegrator`. These are **equal-weight sums**, without a
grid-spacing factor; normalized expectations are unaffected by that common
factor. Adaptive quadrature and unequal quadrature weights are not supported by
this wrapper.

The wrapper evaluates the estimator's native `logpdf` on the grid, subtracts
the largest log density, exponentiates, and normalizes the resulting weights.
Means, variances, covariance matrices and response predictions reuse that
normalization. Signed moments are calculated with ordinary numbers. It returns
ordinary values for expectations, but logarithmic numbers for raw integrals and
`normdenom`, preserving their unnormalized scale. `Float64(mass)` may underflow;
`log(mass)` preserves the log mass. An explicit denominator supplied to
`expectation` is still an unnormalized denominator, not a log denominator.

Use `LogGridAbilityTracker` to cache the grid log densities, normalized weights,
and normalization scale across calculations. Both new constructors accept config
bits in any order. Attach the tracker to `TrackedResponses`, or let `CatRules`
collect it from the integrator embedded in the ability estimator.

```jldoctest
julia> using ComputerAdaptiveTesting.Aggregators, ComputerAdaptiveTesting.Responses,
           FittedItemBanks, Distributions, PsychometricsBazaarBase.Integrators

julia> bank = ItemBank2PL([0.0], [1.0]);

julia> dist = PosteriorAbilityEstimator(Normal());

julia> grid = FixedGridIntegrator(collect(-6.0:0.05:6.0));

julia> tracker = LogGridAbilityTracker(dist, grid);

julia> integral = LogGridIntegrator(tracker);

julia> history = BareResponses(ResponseType(bank), fill(1, 2000),
                              repeat([false, true], 1000));

julia> tracked = TrackedResponses(history, bank, tracker); track!(tracked);

julia> abs(MeanAbilityEstimator(dist, integral)(tracked)) < 1e-10
true

julia> isfinite(variance(integral, dist, tracked))
true

julia> sum(response_expectation(dist, integral, tracked, 1)) ≈ 1
true
```

`LogGridIntegrator(grid)` works without a tracker, recomputing the weights on
each calculation. Before a tracker's first `track!`, it also computes temporary
weights. Adding, popping or clearing tracked responses refreshes the tracker.
Integrating a different history (including a speculative response), bank or
estimator computes temporary weights without modifying the live cache. The
cache includes a snapshot of response indices and values, so bare-history edits
cannot reuse stale weights. Treat grid coordinates, item parameters and prior
parameters as fixed; explicitly refresh with `track!` after changing them.
Parallel reads are supported; concurrent mutation of the tracker is not.

Predictions evaluate every response category directly, including nominal
categories, avoiding cancellation from `1 - P(true)`. Tabulated dichotomous
banks use their log-likelihood arrays and require an exactly matching grid.
No probability-space fallback is supplied for custom estimators lacking
`logpdf`. An empty grid, a grid with zero density everywhere, or `NaN`/`+Inf`
log densities raise errors. A grid with insufficient resolution can still miss
the posterior peak: stable normalization does not correct quadrature error.

## Continuous log-density integration

`Aggregators.LogFunctionIntegrator(backend, optimizer)` opts into stable
continuous integration. Both arguments are config bits and may be supplied in
either order. It reuses PsychometricsBazaarBase's quadrature and maximization
implementations; it does not change the existing `FunctionIntegrator` default.
The estimator must implement native `Distributions.logpdf`.

```jldoctest
julia> using ComputerAdaptiveTesting.Aggregators, ComputerAdaptiveTesting.Responses,
           FittedItemBanks, Distributions, PsychometricsBazaarBase.Integrators

julia> using PsychometricsBazaarBase.Optimizers: NativeOneDimOptimOptimizer

julia> bank = ItemBank2PL([0.0], [1.0]);

julia> tracked = TrackedResponses(BareResponses(ResponseType(bank)), bank);

julia> backend = QuadGKIntegrator(; lo=-8.0, hi=8.0, rtol=1e-8);

julia> optimizer = NativeOneDimOptimOptimizer(; lo=-8.0, hi=8.0);

julia> integral = LogFunctionIntegrator(backend, optimizer);

julia> dist = PosteriorAbilityEstimator(Normal(-0.7, 1.0));

julia> abs(MeanAbilityEstimator(dist, integral)(tracked) + 0.7) < 1e-8
true

julia> abs(variance(integral, dist, tracked) - 1) < 1e-8
true
```

Supported backends are `QuadGKIntegrator`, `FixedGKIntegrator`,
`MultiDimFixedGKIntegrator`, `HCubatureIntegrator` and `CubatureIntegrator`.
Their domain, tolerances and scalar/vector/matrix output restrictions still
apply. For example, use HCubature for vector and matrix moments. The optimizer
must maximize its input function and search a region containing a representative
density peak inside the integration domain. It may use a finite search interval
when the quadrature domain is infinite.

Each expectation prepares one log density and chooses a reference value `c`
using the optimizer. Both numerator and denominator integrate against
`exp(log_density(x) - c)` using ordinary arithmetic, then divide before restoring
any absolute scale. Signed moments stay ordinary numbers. A separate calculation
prepares a fresh reference, so response-history edits and speculative histories
cannot reuse stale density state. Predictions integrate every response category
directly rather than subtracting a probability from one.

Raw integration returns the backend's result type with its value **and error**
multiplied by `exp(c)` using logarithmic numbers. `normdenom` remains the absolute,
unnormalized mass. Inspect it with `log(mass)`; converting it to `Float64` can
underflow or overflow. An explicit denominator supplied to `expectation` is
an absolute mass, not a log mass or a rescaled mass.

Use `IntPassthrough()` (from `PsychometricsBazaarBase.Integrators`) with
`expectation` to inspect its ordinary-valued result and error via `intval` and
`interr`, or `IntMeasurement()` for a normalized measurement. When both integrals
provide errors, the ratio estimate includes both numerator and normalization
error. It treats an explicitly supplied scalar denominator as fixed. These
estimates depend on the backend's error estimates; they are not certified bounds.
Backends without error estimates retain `BareIntegrationResult` semantics.

A nonfinite reference, invalid log density, overflow after rescaling, or zero or
nonfinite normalization mass raises `DomainError`. Normalization also rejects a
mass error estimate as large as the mass itself. Coefficients must be defined at
the reference point; zero-density integration points skip their evaluation.
Choosing a log scale does not ensure the optimizer or quadrature finds every
peak, resolve an inadequate integration range, or make an improper density
integrable. Adjust the domain, optimizer or quadrature when needed.

```@docs
ComputerAdaptiveTesting.DerivedMeasures.LaplaceApproxEstimator
```

```@index
```

```@autodocs
Modules = [ComputerAdaptiveTesting, ComputerAdaptiveTesting.Aggregators, ComputerAdaptiveTesting.Responses, ComputerAdaptiveTesting.Sim, ComputerAdaptiveTesting.TerminationConditions, ComputerAdaptiveTesting.NextItemRules, ComputerAdaptiveTesting.Rules, ComputerAdaptiveTesting.Stateful, ComputerAdaptiveTesting.DecisionTree, ComputerAdaptiveTesting.Compat, ComputerAdaptiveTesting.Comparison, ComputerAdaptiveTesting.ConfigBase]
```
