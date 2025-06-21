using ComputerAdaptiveTesting.DummyData: dummy_3pl,
    dummy_mirt_4pl, std_normal, std_mv_normal
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.Integrators
using ComputerAdaptiveTesting.NextItemRules
import Profile
import PProf
using Distributions: Normal
using ArgParse
using StatProfilerHTML
using StatsBase: sample
using BenchmarkTools

function get_ability_estimator(multidim)
    if multidim
        integrator = MultiDimFixedGKIntegrator([-6.0, -6.0, -6.0], [6.0, 6.0, 6.0])
        dist = std_mv_normal(3)
    else
        integrator = FixedGKIntegrator(-6.0, 6.0)
        dist = Normal()
    end
    return PosteriorAbilityEstimator(dist, integrator)
end

function prepare_empty(item_bank, actual_responses, ability_tracker)
    responses = TrackedResponses(BareResponses([], []),
        item_bank,
        ability_tracker)
    (item_bank, actual_responses, responses)
end

function prepare_0(ability_estimator)
    (item_bank, question_labels_, abilities_, actual_responses) = dummy_3pl(;
        num_questions = 100,
        num_testees = 1)
    prepare_empty(item_bank, actual_responses, PointAbilityTracker(ability_estimator, NaN))
end

function prepare_0_mirt(ability_estimator)
    (item_bank, question_labels_, abilities_, actual_responses) = dummy_mirt_4pl(3;
        num_questions = 100,
        num_testees = 1)
    prepare_empty(item_bank,
        actual_responses,
        PointAbilityTracker(ability_estimator, [NaN, NaN, NaN]))
end

function prepare_50(ability_estimator)
    (item_bank, question_labels_, abilities_, actual_responses) = dummy_3pl(;
        num_questions = 100,
        num_testees = 1)
    idxs = sample(1:100, 50)
    responses = TrackedResponses(BareResponses(idxs,
            actual_responses[idxs, 1]),
        item_bank,
        PointAbilityTracker(ability_estimator, NaN))
    (item_bank, actual_responses, responses)
end

function run_all(dummy_data, objective)
    (item_bank, actual_responses, responses) = dummy_data
    track!(responses)
    criterion_state = init_thread(objective, responses)
    for item_idx in eachindex(item_bank)
        objective(criterion_state, responses, item_idx)
    end
end

function run_single(dummy_data, objective)
    (item_bank, actual_responses, responses) = dummy_data
    criterion_state = init_thread(objective, responses)
    objective(criterion_state, responses, 1)
end

function profile_objective(run_profile::RunProfile,
        pre_bench::PrepBench,
        run_bench::RunBench,
        objective::Objective,
        ability_estimator) where {RunProfile, PrepBench, RunBench, Objective}
    dummy_data = pre_bench(ability_estimator)
    run() = run_bench(dummy_data, objective)
    @info "init run"
    run()
    @info "benchmark run"
    run_profile(run)
end

#=
if isdefined(Profile, :Allocs)
    run_pprof_allocs = function(run)
        Profile.Allocs.@profile run()
        prof = Profile.Allocs.fetch()
        PProf.Allocs.pprof(prof)
    end
end
=#

function get_cmdline()
    if Sys.iswindows()
        String.(split(unsafe_string(ccall(:GetCommandLineA, Cstring, ())), " "))
    elseif Sys.isapple()
        String.(split(strip(read(`/bin/ps -p $(getpid()) -o command=`, String)), " "))
    elseif Sys.isunix()
        String.(split(read(joinpath("/", "proc", string(getpid()), "cmdline"), String),
            "\x00";
            keepempty = false))
    else
        j_cmd = String.(split(Base.julia_cmd(), " "))
        args_joined = join(ARGS, " ")
        [j_cmd..., PROGRAM_FILE, args_joined...]
    end
end

function run_track_allocs(run_bench::F) where {F}
    Profile.clear_malloc_data()
    run_bench()
end

function run_profile(run::F) where {F}
    Profile.@profile run()
    prof = Profile.fetch()
    PProf.pprof(prof)
end

function run_time(run::F) where {F}
    @time run()
end

function run_btime(run_bench::F) where {F}
    t = @benchmark $(run_bench)() evals=1000 samples=1000
    dump(t)
end

function run_statprofilerhtml(run::F) where {F}
    @profilehtml run()
end

PROFILERS = Dict("track_allocs" => run_track_allocs,
    "profile" => run_profile,
    "time" => run_time,
    "btime" => run_btime,
    "profilehtml" => run_statprofilerhtml)

BENCHES = Dict("all0" => (prepare_0, run_all),
    "allmirt" => (prepare_0_mirt, run_all),
    "all50" => (prepare_50, run_all),
    "single50" => (prepare_50, run_single))
#=
if isdefined(Profile, :Allocs)
    PROFILERS["pprof_allocs"] = run_pprof_allocs
end
=#

function objective(next_item_rule::NextItemRule)
    next_item_rule.criterion
end

function get_next_item_rule(rule_name, ability_estimator)
    if rule_name == "drule"
        NextItemRule(DRuleItemCriterion(ability_estimator))
    else
        catr_next_item_aliases[rule_name](ability_estimator)
    end
end

function main()
    settings = ArgParseSettings()
    @add_arg_table settings begin
        "profiling_mode"
        help = "The profiling mode to use. Can be 'pprof_allocs', 'track_allocs', 'profile', or 'time'."
        required = true
        "next_item_rule"
        help = "The next item rule to use"
        required = true
        "bench"
        help = "The benchmark to use"
        required = true
    end
    args = parse_args(settings)
    ability_estimator = get_ability_estimator(args["next_item_rule"] == "drule")
    point_ability_estimator = ModeAbilityEstimator(ability_estimator)
    next_item_rule = get_next_item_rule(args["next_item_rule"], point_ability_estimator)
    if args["profiling_mode"] == "track_allocs" && !haskey(ENV, "TRACK_ALLOCS")
        cmdline = get_cmdline()
        insert!(cmdline,
            findfirst(x -> endswith(x, ".jl"), cmdline),
            "--track-allocation=all")
        cmd = Cmd(Cmd(cmdline), env = ("TRACK_ALLOCS" => "TRUE",))
        @info "Running subprocess to track allocs" cmd
        Base.run(cmd)
        return
    end
    (pre_bench, run_bench) = BENCHES[args["bench"]]
    profile_objective(PROFILERS[args["profiling_mode"]],
        pre_bench,
        run_bench,
        objective(next_item_rule),
        point_ability_estimator)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
