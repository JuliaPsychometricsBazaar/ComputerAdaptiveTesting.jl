```@meta
CurrentModule = ComputerAdaptiveTesting
```

# Creating a CAT

This guide gives a brief overview of how to create a CAT using the
configuration structs in `ComputerAdaptiveTesting.jl`.

## API design

The configuration of a CAT is built up as a tree of configuration structs.
These structs are all subtypes of `CatConfigBase`.

```@docs; canonical=false
ComputerAdaptiveTesting.ConfigBase.CatConfigBase
```

The constructors for the configuration structs in this package tend to have
smart defaults. In general most constructors have two forms. The first is an
explicit keyword constructor form, where all arguments are given:

```
ConfigurationObject(
  field1=value1,
  field1=value2,
)
```

The second is an implicit form, where arguments are given in any order. If
possible, they will be used together will appropriately guessed defaults to
construct the configuration:

```
ConfigurationObject(value2, value1)
```

The implicit form is particularly useful for quick prototyping. Implicit form
constructors are also available for some abstract types. In this case, they
will return a concrete type that is a reasonable default for the abstract type.

After using the implicit form, you can print the object to see what values have
been filled in. This may be useful in case you want to modify some of the
defaults or switch to the explicit form.

## Item banks

Item banks are the source of items for the test. The basic definitions are
provided by
[FittedItemBanks.jl](https://juliapsychometricsbazaar.github.io/FittedItemBanks.jl/)
and can be fit to data using
[RIrtWrappers.jl](https://juliapsychometricsbazaar.github.io/RIrtWrappers.jl/stable/).
See the documentation pages of those packages for more information.

## Choosing linear or log-space integration

Give the distribution estimator a `LogSpace()` config bit to use stable
log-density integration. The default is `LinSpace()`. The same policy is used
by direct composition and by the flat `CatRules` constructor:

```jldoctest space_configuration
julia> using ComputerAdaptiveTesting, ComputerAdaptiveTesting.Aggregators,
           ComputerAdaptiveTesting.NextItemRules,
           ComputerAdaptiveTesting.TerminationConditions,
           PsychometricsBazaarBase.Integrators, Distributions

julia> dist = PosteriorAbilityEstimator(Normal(), LogSpace());

julia> grid = FixedGridIntegrator(range(-6, 6; length=121));

julia> ability = MeanAbilityEstimator(dist, grid);

julia> ability.integrator isa LogGridIntegrator
true

julia> rules = CatRules(MeanAbilityEstimator, dist, grid,
           GriddedAbilityTracker, AbilityVariance, FixedLength(20));

julia> rules.ability_estimator.integrator isa LogGridIntegrator
true

julia> rules.next_item.criterion.criterion.integrator === rules.ability_estimator.integrator
true

julia> rules.ability_estimator.integrator.tracker isa LogGridAbilityTracker
true
```

`AbilityVariance` here constructs expected post-response variance item selection.
Use `InformationItemCriterion` in its place for information-based selection.
The resolved point estimator supplies defaults to newly constructed criteria;
compatible criteria reuse its integrator and tracker. The integration-space
choice does not change point predictions into posterior-predictive predictions.

Tracking is optional: omit `GriddedAbilityTracker` to calculate weights on demand.
With `LogSpace()`, requesting a grid tracker constructs `LogGridAbilityTracker`.
Shared trackers are registered once, including when also used by a stopping
criterion, and remain shared after `preallocate(rules)`.

Continuous log integration additionally needs an optimizer to choose a reference
log density:

```jldoctest space_configuration
julia> using PsychometricsBazaarBase.Optimizers: NativeOneDimOptimOptimizer

julia> backend = QuadGKIntegrator(; lo=-8.0, hi=8.0);

julia> optimizer = NativeOneDimOptimOptimizer(; lo=-8.0, hi=8.0);

julia> MeanAbilityEstimator(dist, backend, optimizer).integrator isa LogFunctionIntegrator
true
```

Supported backends and their limitations are listed in the
[API reference](api.md#Continuous-log-density-integration). Missing optimizers
and unsupported automatic log-space adapters cause construction errors.
Equal-weight grid integration preserves the backend's sum convention; other
weighting schemes such as `MidpointIntegrator` are not automatically converted.

Explicitly supplied ability integrators and already constructed criteria retain
their settings. For example, `MeanAbilityEstimator(dist, FunctionIntegrator(grid))`
explicitly uses ordinary density integration even though `dist` prefers log space.
Printing the rules shows both the distribution's policy and the actual adapter.
To change a component, reconstruct it with the desired policy or adapter.

Both `pdf` and `logpdf` remain available in either space, and MLE/MAP continue
to maximize the log density. Reported abilities, normalized moments and
probability predictions retain their ordinary meanings. Raw masses returned by
log integrators use logarithmic numbers to preserve their absolute scale.

## CatRules

For stable mean and uncertainty estimates over a fixed grid, use
`Aggregators.LogGridIntegrator(grid)` with a distribution estimator. To reuse
the grid density across calculations, construct
`tracker = Aggregators.LogGridAbilityTracker(distribution_estimator, grid)` and
pass `Aggregators.LogGridIntegrator(tracker)` to `MeanAbilityEstimator`.
`CatRules` collects that tracker automatically. See
[Fixed-grid log normalization and tracking](@ref) for an executable example,
supported grids and normalization semantics.

For continuous quadrature, wrap a backend and a maximization optimizer in
`Aggregators.LogFunctionIntegrator(backend, optimizer)` and pass it to
`MeanAbilityEstimator` or other distribution-based criteria. It rescales native
log densities before integration and preserves the scale of raw masses and
quadrature errors. See [Continuous log-density integration](@ref) for an example
and the supported backends.

This is the main type for configuring a CAT. It contains ability estimation,
the next item selection rule, and the stopping rule. The item bank is supplied
when running the CAT. `CatRules` has explicit and
implicit constructors.

```@docs; canonical=false
ComputerAdaptiveTesting.CatRules
```

### Next item selection with `NextItemRule`

The next item selection rule is the most important part of the CAT. Each rule
extends the `NextItemRule` abstract type.

```@docs; canonical=false
ComputerAdaptiveTesting.NextItemRules.NextItemRule
```

A sort of null hypothesis next item selection rule is `RandomNextItemRule`, which 

```@docs; canonical=false
ComputerAdaptiveTesting.NextItemRules.RandomNextItemRule
```

Other rules are created by combining a `ItemCriterion` -- which somehow rates
items according to how good they are -- with a `NextItemStrategy` using an
`ItemCriterionRule`, which acts as an adapter. The default
`NextItemStrategy` (and currently only) is `ExhaustiveSearch`. When using
the implicit constructors, `ItemCriterion` can therefore be used directly
without wrapping in any place an NextItemRule is expected.

```@docs; canonical=false
ComputerAdaptiveTesting.NextItemRules.ItemCriterionRule
```

```@docs; canonical=false
ComputerAdaptiveTesting.NextItemRules.ItemCriterion
```

```@docs; canonical=false
ComputerAdaptiveTesting.NextItemRules.NextItemStrategy
```

```@docs; canonical=false
ComputerAdaptiveTesting.NextItemRules.ExhaustiveSearch
```

### Evaluating item and state merit with `ItemCriterion` and `StateCriterion`

The `ItemCriterion` abstract type is used to rate items according to how good
they are as a candidate for the next item. A typical example is
`InformationItemCriterion`, which using the current ability estimate ``\theta``
and the item response function ```irf``` to calculate each item's information
``\frac{irf_θ'^2}{irf_θ * (1 - irf_θ)}``.

Within this, you can use `ExpectationBasedItemCriterion` as an adapter. It
takes a `ResponseExpectation`: either `PointResponseExpectation` or
`DistributionResponseExpectation` and a a `StateCriterion`, which evaluates how
good a particular state is in terms getting a good estimate of the test takers
ability. They look one ply ahead to get the expected value of the
``StateCriterion`` after selecting the given item. The
`AbilityVariance` looks at the variance of the ability ``\theta``
estimate at that state.

### Stopping rules with `TerminationCondition`

Currently the only `TerminationCondition` is `FixedLength`, which ends the test after a fixed number of items.

```@docs; canonical=false
ComputerAdaptiveTesting.TerminationConditions.TerminationCondition
```

```@docs; canonical=false
ComputerAdaptiveTesting.TerminationConditions.FixedLength
```
