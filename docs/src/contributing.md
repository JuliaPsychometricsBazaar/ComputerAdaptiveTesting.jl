# Contributing

Contributions are welcome. Please discuss any larger changes in the issues
before making a pull request to avoid wasted work.

## Running tests

You can run tests locally like so:

```
julia --project=test test/runtests.jl
```

Unfortunately, `Pkg.test()` does not work properly at the moment. See [this
issue](https://github.com/frankier/ComputerAdaptiveTesting.jl/issues/52).
