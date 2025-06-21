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

## CatRules

This is the main type for configuring a CAT. It contains the item bank, the
next item selection rule, and the stopping rule. `CatRules` has explicit and
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
`ItemStrategyNextItemRule`, which acts as an adapter. The default
`NextItemStrategy` (and currently only) is `ExhaustiveSearch`. When using
the implicit constructors, `ItemCriterion` can therefore be used directly
without wrapping in any place an NextItemRule is expected.

```@docs; canonical=false
ComputerAdaptiveTesting.NextItemRules.ItemStrategyNextItemRule
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
`AbilityVarianceStateCriterion` looks at the variance of the ability ``\theta``
estimate at that state.

### Stopping rules with `TerminationCondition`

Currently the only `TerminationCondition` is `FixedItemsTerminationCondition`, which ends the test after a fixed number of items.

```@docs; canonical=false
ComputerAdaptiveTesting.TerminationConditions.TerminationCondition
```

```@docs; canonical=false
ComputerAdaptiveTesting.TerminationConditions.FixedItemsTerminationCondition
```
