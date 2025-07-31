# ComputerAdaptiveTesting.jl Architecture

## Overview

ComputerAdaptiveTesting.jl is organized into several interconnected modules that implement various aspects of Computer Adaptive Testing. The architecture follows a modular design with clear separation of concerns.

## Core Module Structure

### 1. Base Layer

#### ConfigBase (`src/ConfigBase.jl`)
- Defines `CatConfigBase` abstract type
- Provides `walk` function for traversing configuration trees
- Foundation for all configuration structs

#### Responses (`src/Responses.jl`)
- `Response`: Individual test response
- `BareResponses`: Collection of responses
- `AbilityLikelihood`: Likelihood calculation for abilities
- Response type handling for boolean and multinomial responses

### 2. Aggregation Layer

#### Aggregators (`src/Aggregators/`)
Main module for ability estimation and tracking:
- **Ability Estimators**:
  - `LikelihoodAbilityEstimator`: Maximum likelihood estimation
  - `PosteriorAbilityEstimator`: Bayesian estimation with priors
  - `MeanAbilityEstimator`: Expected a posteriori (EAP)
  - `ModeAbilityEstimator`: Maximum a posteriori (MAP)
- **Ability Trackers**:
  - `NullAbilityTracker`: No tracking
  - `PointAbilityTracker`: Tracks point estimates
  - `GriddedAbilityTracker`: Grid-based tracking
  - `ClosedFormNormalAbilityTracker`: Analytical normal approximation
- **Integration**: Various integrators for numerical integration
- **Optimization**: Optimizers for finding maximum likelihood/posterior

### 3. CAT Logic Layer

#### NextItemRules (`src/NextItemRules/`)
Implements item selection algorithms:
- **Strategies**:
  - `ExhaustiveSearch`: Evaluates all items
  - `RandomNextItemRule`: Random selection
  - `RandomesqueStrategy`: Top-k random selection
  - `BalancedStrategy`: Content balancing
- **Criteria**:
  - `InformationItemCriterion`: Fisher information
  - `AbilityVariance`: Minimize ability estimate variance
  - `UrryItemCriterion`: Difficulty matching
  - `ExpectationBasedItemCriterion`: Expected criteria values
- **Multi-dimensional support**: D-Rule, T-Rule for MIRT

#### TerminationConditions (`src/TerminationConditions.jl`)
- `FixedLength`: Stop after N items
- `RunForever`: No termination
- `TerminationTest`: Custom termination logic

### 4. Execution Layer

#### Rules (`src/Rules.jl`)
- `CatRules`: Main configuration struct combining:
  - Next item selection rule
  - Termination condition
  - Ability estimator
  - Ability tracker

#### Sim (`src/Sim/`)
Simulation and execution:
- `CatLoop`: Configuration for running a CAT
- `run_cat`: Main execution function
- `CatRecorder`: Recording CAT sessions
- Response callbacks and hooks

### 5. Advanced Features

#### DecisionTree (`src/DecisionTree/`)
- Pre-computation of CAT decisions into decision trees
- `MaterializedDecisionTree`: Stored decision tree
- Memory-mapped storage for large trees

#### Stateful (`src/Stateful.jl`)
Stateful interface for CAT implementations:
- `StatefulCat`: Abstract interface
- `StatefulCatRules`: Implementation using CatRules
- Methods: `next_item`, `add_response!`, `get_ability`, etc.

#### Comparison (`src/Comparison/`)
Tools for comparing CAT configurations:
- Execution strategies for benchmarking
- Statistical comparison tools
- Watchdog for timeout handling

#### Compatibility (`src/Compat/`)
- `CatR`: Compatibility with R's catR package
- `MirtCAT`: Compatibility with R's mirtCAT package

### 6. Support Modules

#### ItemBanks (`src/logitembank.jl`)
- `LogItemBank`: Logarithmic scale item banks
- Temporary workaround to get logprobs, likely to be removed later on

#### Precompilation (`src/precompiles.jl`)
- Precompilation workloads for faster package loading

## Key Design Patterns

### 1. Configuration Trees
Most components use a tree structure of configuration objects:
```julia
CatRules(
    next_item = ItemCriterionRule(...),
    termination_condition = FixedLength(20),
    ability_estimator = MeanAbilityEstimator(...),
    ability_tracker = GriddedAbilityTracker(...)
)
```

### 2. Implicit Constructors
Many types support implicit construction where components are automatically selected:
```julia
# Explicit
MeanAbilityEstimator(PosteriorAbilityEstimator(), integrator)

# Implicit - finds appropriate components
MeanAbilityEstimator(bits...)
```

### 3. Preallocatable Pattern
Components can be preallocated for performance:
```julia
rule = preallocate(next_item_rule)
```

### 4. Tracked Responses
Responses are wrapped with tracking information:
```julia
TrackedResponses(
    responses::BareResponses,
    item_bank::AbstractItemBank,
    ability_tracker::AbilityTracker
)
```

## Performance Optimizations

1. **Preallocation**: Many components support preallocation
2. **Specialization**: Type-stable code with concrete types
3. **Threading**: Thread-safe operations with `init_thread`
4. **Integration caching**: Grid-based integrators cache evaluations
5. **Log-space computations**: Avoid numerical underflow

## Extension Points

1. **Custom Item Selection**: Extend `ItemCriterion` or `NextItemRule`
2. **Custom Ability Estimation**: Extend `AbilityEstimator`
3. **Custom Termination**: Implement `TerminationCondition`
4. **Custom Item Banks**: Via FittedItemBanks.jl interface

## Testing Architecture

- Unit tests for individual components
- Integration tests for complete CAT runs
- Smoke tests for various configurations
- Aqua.jl for code quality
- JET.jl for type stability

## Documentation Structure

- API documentation via Documenter.jl
- Examples using Literate.jl
- Interactive demos with Makie.jl plots
- Compatibility with R packages documented
