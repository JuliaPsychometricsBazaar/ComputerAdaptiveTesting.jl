# Contributing

Contributions are welcome. Please discuss any larger changes in the issues
before making a pull request to avoid wasted work.

Development conventions (code style, testing, git workflow) are documented in
`AGENTS.md`
at the repository root. A devcontainer is provided in `.devcontainer/` for a
ready-made development environment.

## Running tests

You can run tests locally like so:

```
julia --project=test test/runtests.jl
```

Unfortunately, `Pkg.test()` does not work properly at the moment. See [this
issue](https://github.com/JuliaPsychometricsBazaar/ComputerAdaptiveTesting.jl/issues/52).
