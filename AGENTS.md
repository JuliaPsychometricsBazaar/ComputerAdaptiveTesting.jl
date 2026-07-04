# AGENTS.md

ComputerAdaptiveTesting.jl implements Computer Adaptive Testing (CAT) in
Julia: composable building blocks for item selection, ability estimation,
termination rules, and simulation. See the [README](README.md) for motivation
and installation, `docs/src/` for tutorials, and docstrings/block comments in
`src/` for specifics — keep those up to date as you change code; they are the
primary documentation for humans too.

## Layout

- `src/ComputerAdaptiveTesting.jl` includes each submodule: `Aggregators`
  (ability estimation), `NextItemRules` (item selection), `TerminationConditions`,
  `Sim` (simulation loop), `Stateful` (step-wise interface), `DecisionTree`,
  `Compat`/`Comparison` (R catR/mirtCAT shims and cross-checks).
- Workspaces: `test/` and `docs/` have their own `Project.toml` (Julia 1.12
  workspace feature).

## Style — DRY and reuse first

Follow the patterns already in the codebase rather than inventing new ones:

- **Config composition**: user-facing constructors take a varargs "bag of
  config bits" resolved with `@requiresome`/`@returnsome`/`find1_instance`
  from `PsychometricsBazaarBase.ConfigTools` (see
  `src/Aggregators/ability_estimator.jl`, `src/NextItemRules/`). Extend this
  machinery; don't hand-roll keyword plumbing.
- **Dispatch over branching**: use trait/marker types (`DomainType`,
  `IntValue`) and multiple dispatch instead of `if`/`isa` chains.
- **Composable wrappers**: prefer wrapper types (e.g.
  `GuardedAbilityEstimator`) over conditionals embedded at call sites.
  Configs are functors — callable strategy objects rooted at `CatConfigBase`.
- **Sister packages**: item banks come from FittedItemBanks.jl; integrators,
  optimizers, and config machinery from PsychometricsBazaarBase.jl. Never
  duplicate their functionality here.
- **Docstrings**: use DocStringExtensions (`$(TYPEDEF)`, `$(SIGNATURES)`);
  see `src/NextItemRules/prelude/abstract.jl` for house style. New public API
  must appear in `docs/src/api.md`.

## Build, test, docs

- Julia 1.12 (`Project.toml` compat; CI tests only 1.12).
- Test: `julia --project=test test/runtests.jl` (includes Aqua and JET
  checks). `Pkg.test()` currently does not work — see issue #52.
- Docs: `cd docs && ./build.sh` (needs R via CondaPkg; CI uses
  `JULIA_CONDAPKG_BACKEND=System` with conda).

## Workflow

Work in a git worktree per task, never directly on `main`:

```sh
git worktree add ../ComputerAdaptiveTesting.jl-<task> -b <task>
```

Commit there, push with `git push -u origin <task>`, and open a pull request
with `gh pr create`. Clean up with `git worktree remove` after merge.
