# ComputerAdaptiveTesting

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://frankier.github.io/ComputerAdaptiveTesting.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://frankier.github.io/ComputerAdaptiveTesting.jl/dev)
[![Build Status](https://github.com/frankier/ComputerAdaptiveTesting.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/frankier/ComputerAdaptiveTesting.jl/actions/workflows/CI.yml?query=branch%3Amain)

## What is it?

In Computer Adaptive Testing (CAT), examinees are given tailored tests which at
each stage present questions chosen to estimate their ability accurately, based
on a provisional estimate. For a brief introduction, see [the Wikipedia
page](https://en.wikipedia.org/wiki/Computerized_adaptive_testing).

This package gives implementations of well-known approaches to CAT in Julia,
which are fast enough to support interactive use when scaling to large item
banks. It also provides flexible scaffolding to support new approaches to CAT
as well as non-standard item banks and difficulty-ability scales.

For a more in-depth introduction to CATs, I recommend the following article
(which outlines the basic definitions before introducing and R package mirtCAT)
and book (which contains various topical chapters detailing different aspects
of CATs).

[Chalmers, R. P. (2016).
*Generating adaptive and non-adaptive test interfaces for multidimensional item
response theory applications.*
Journal of Statistical Software, 71, 1-38.](https://doi.org/10.18637/JSS.V071.I05)

[van der Linden, W. J. & Glas C. A. W. (Eds.) (2010).
*Elements of adaptive testing.*
Statistics for Social and Behavioral Sciences.](https://doi.org/10.1007/978-0-387-85461-8)

## Installation

The package is available through `Pkg`. Install like so:

```
julia> using Pkg
julia> Pkg.add("ComputerAdaptiveTesting")
```

For the current development version (e.g. before filing an issue), install like so:

```
julia> using Pkg
julia> Pkg.add(PackageSpec(url = "https://github.com/frankier/ComputerAdaptiveTesting.jl.git"))
```

## How does this package differ from the alternatives?

The main (open source software library) alternatives are
[catR](https://cran.r-project.org/web/packages/catR/index.html) and
[mirtCAT](https://cran.r-project.org/web/packages/mirtCAT/index.html) in R and
[catsim](https://github.com/douglasrizzo/catsim) in Python.

Of these, mirtCAT is the most complete. At the moment, mirtCAT is more complete
than ComputerAdaptiveTesting.jl. However, this package is already beginning to
have some advantages in terms of flexibility:

 * Flexibility in allowing the lowest level "building blocks" of the algorithm,
   namely optimization and integration algorithms to be freely configured and
   replaced, allowing various levels of speed/accuracy trade off to be reached.
 * Flexibility in allowing a wide variety of item banks to be used. The
   architecture supports (TODO: implement) for example, item banks with
   parameter estimation uncertainties (e.g. from MCMC estimation) and item
   banks with item banks based on hierarchical modelling.

There are two long term goals for the project. The first is to allow and
provide fast implementations of otherwise computationally heavy scenarios and
techniques such as those with large item banks, high dimensionality or many-ply
lookaheads. The second is composability with complimentary Julia packages to
allow for item banks based a wide variety of ways of mixing and matching
model-based and machine learning -based techniques to utilised for CATs and
evaluated in a CAT setting.

## What next?

You can [read the
documentation](https://juliapsychometricsbazaar.github.io/ComputerAdaptiveTesting.jl/dev/) which
also contains a number of examples.

## Repo organisation

 * `/docs/examples`, Example code
 * `/docs`, Documentation source code, build with Documenter.jl
 * `/src`, Source code for the main ComputerAdaptiveTesting.jl package
 * `/CATPlots`, Source code for the plotting CATPlots.jl package
 * `/experiments`, Some experiments, benchmarks and example code. All of these
   are more computationally heavy than `/docs/examples` and may need HPC and/or
   patience.
