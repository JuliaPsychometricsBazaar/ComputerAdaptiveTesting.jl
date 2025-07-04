# Stateful interface

```@meta
CurrentModule = ComputerAdaptiveTesting
```

```@docs
Stateful.Stateful
```

## Interface

```@docs
Stateful.StatefulCat
Stateful.next_item
Stateful.ranked_items
Stateful.item_criteria
Stateful.add_response!
Stateful.rollback!
Stateful.reset!
Stateful.set_item_bank!
Stateful.get_responses
Stateful.get_ability
```

## CatRules implementation

There is an implementation in terms of [CatRules](@ref):

```@docs
Stateful.StatefulCatRules
```

## Usage

Just as [CatLoop](@ref) can wrap [CatRules](@ref), you can also use it with any implementor of [Stateful.StatefulCat](@ref), and run using [Sim.run_cat](@ref).