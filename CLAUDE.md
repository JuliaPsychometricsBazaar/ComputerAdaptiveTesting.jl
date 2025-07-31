# Claude Code Assistant Guide for ComputerAdaptiveTesting.jl

## Overview

ComputerAdaptiveTesting.jl is a Julia package that implements Computer Adaptive Testing (CAT) algorithms. The package provides fast implementations of well-known CAT approaches with flexible scaffolding to support new approaches and non-standard item banks.

## Development Workflow

This project uses a **pull request workflow**. All changes should be made in feature branches and submitted via pull requests for review.

### Steps for Contributing:

1. **Create a feature branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following the project structure and conventions

3. **Run tests** before committing:
   ```bash
   julia --project=test test/runtests.jl
   ```

4. **Commit your changes** with descriptive commit messages

5. **Push to your branch** and create a pull request

6. **Wait for review** before merging

## Project Structure

See @ARCHITECTURE.md for detailed information about the codebase structure.

## Key Areas for Assistance

### 1. Core Modules
- **Aggregators**: Ability estimation and tracking
- **NextItemRules**: Item selection algorithms
- **Responses**: Response handling and storage
- **Sim**: Simulation and CAT execution

### 2. Testing
- Tests are in the `test/` directory
- Run tests with `julia --project=test test/runtests.jl`
- Note: `Pkg.test()` currently doesn't work (see issue #52)

### 3. Documentation
- Documentation source is in `docs/src/`
- Examples are in `docs/examples/`
- Build docs with `julia --project=docs docs/make.jl`

## Common Tasks

### Adding a New Item Selection Rule
1. Create new file in `src/NextItemRules/criteria/`
2. Implement the criterion interface
3. Add tests in `test/`
4. Update documentation

### Adding a New Ability Estimator
1. Create new file in `src/Aggregators/`
2. Extend the `AbilityEstimator` abstract type
3. Implement required methods
4. Add integration tests

### Working with Item Banks
- Item banks are provided by FittedItemBanks.jl
- See examples in `test/dummy.jl` for creating test data

## Code Style Guidelines

1. Use Julia formatting conventions
2. Follow the [SciML style](https://docs.sciml.ai/SciMLStyle/stable/)
2. Add docstrings for public functions using DocStringExtensions
3. Keep functions focused and modular
4. Use meaningful variable names (except in performance-critical inner loops)

## Performance Considerations

- The package is designed for speed with large item banks
- Use `@benchmark` from BenchmarkTools.jl for performance testing
- Profile with `profile/next_items.jl` for optimization work
- Other benchmarks are in the external CATExperiment
  - This area is in flux and could be improved

## Dependencies

Key dependencies include:
- FittedItemBanks.jl for item bank management
- PsychometricsBazaarBase.jl for baseline utilities for the PsychometricsBazaar ecosystem
- Distributions.jl for statistical distributions
- ForwardDiff.jl for automatic differentiation

## Useful Resources

- [Package Documentation](https://juliapsychometricsbazaar.github.io/ComputerAdaptiveTesting.jl/dev/)
- [catR](https://cran.r-project.org/web/packages/catR/index.html) - R alternative
- [mirtCAT](https://cran.r-project.org/web/packages/mirtCAT/index.html) - Another R alternative

## Getting Help

- Check existing issues on GitHub
- Review the test files for usage examples
- Consult the documentation for API details
