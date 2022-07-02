var documenterSearchIndex = {"docs":
[{"location":"examples/examples/irfs/#Item-Response-Functions","page":"Item Response Functions","title":"Item Response Functions","text":"","category":"section"},{"location":"examples/examples/irfs/","page":"Item Response Functions","title":"Item Response Functions","text":"(Image: Source code) (Image: notebook)","category":"page"},{"location":"examples/examples/irfs/","page":"Item Response Functions","title":"Item Response Functions","text":"Item Response Functions","category":"page"},{"location":"examples/examples/irfs/","page":"Item Response Functions","title":"Item Response Functions","text":"using Makie\nimport Pkg\nusing Distributions: Normal, cdf\nusing ComputerAdaptiveTesting.ExtraDistributions: NormalScaledLogistic\nusing CATPlots\n\n@automakie()","category":"page"},{"location":"examples/examples/irfs/","page":"Item Response Functions","title":"Item Response Functions","text":"Typically, the logistic c.d.f. is used as the transfer function in IRT. However, it in an IRT context, a scaled version intended to be close to a normal c.d.f. is often used. The main advantage is that this is usually faster to compute. ComputerAdaptiveTesting provides NormalScaledLogistic, which is also used by default, for this purpose:","category":"page"},{"location":"examples/examples/irfs/","page":"Item Response Functions","title":"Item Response Functions","text":"xs = -8:0.05:8\nlines(xs, cdf.(Normal(), xs))\nlines!(xs, cdf.(NormalScaledLogistic(), xs))\ncurrent_figure()","category":"page"},{"location":"examples/examples/irfs/","page":"Item Response Functions","title":"Item Response Functions","text":"","category":"page"},{"location":"examples/examples/irfs/","page":"Item Response Functions","title":"Item Response Functions","text":"This page was generated using DemoCards.jl and Literate.jl.","category":"page"},{"location":"examples/examples/ability_convergence_3pl/#How-abilities-converge-on-simulated-3PL-data","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"","category":"section"},{"location":"examples/examples/ability_convergence_3pl/","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"(Image: Source code) (Image: notebook)","category":"page"},{"location":"examples/examples/ability_convergence_3pl/","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"How abilities converge on simulated 3PL data","category":"page"},{"location":"examples/examples/ability_convergence_3pl/#Running-a-CAT-based-on-a-synthetic-correct/incorrect-3PL-IRT-model","page":"How abilities converge on simulated 3PL data","title":"Running a CAT based on a synthetic correct/incorrect 3PL IRT model","text":"","category":"section"},{"location":"examples/examples/ability_convergence_3pl/","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"This example shows how to run a CAT based on a synthetic correct/incorrect 3PL IRT model.","category":"page"},{"location":"examples/examples/ability_convergence_3pl/","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"Import order is important. We put ComputerAdaptiveTesting last so we get the extra dependencies.","category":"page"},{"location":"examples/examples/ability_convergence_3pl/","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"using Makie\nimport Pkg\nimport Random\nusing Distributions: Normal, cdf\nusing AlgebraOfGraphics\nusing ComputerAdaptiveTesting\nusing ComputerAdaptiveTesting.ExtraDistributions: NormalScaledLogistic\nusing ComputerAdaptiveTesting.Sim: auto_responder\nusing ComputerAdaptiveTesting.NextItemRules: AbilityVarianceStateCriterion\nusing ComputerAdaptiveTesting.TerminationConditions: FixedItemsTerminationCondition\nusing ComputerAdaptiveTesting.Aggregators: PriorAbilityEstimator, MeanAbilityEstimator, LikelihoodAbilityEstimator\nusing ComputerAdaptiveTesting.ItemBanks\nusing ComputerAdaptiveTesting.Integrators\nimport ComputerAdaptiveTesting.IntegralCoeffs\nusing CATPlots\n\n@automakie()","category":"page"},{"location":"examples/examples/ability_convergence_3pl/","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"Now we are read to generate our synthetic data using the supplied DummyData module. We generate an item bank with 100 items and fake responses for 3 testees.","category":"page"},{"location":"examples/examples/ability_convergence_3pl/","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"using ComputerAdaptiveTesting.DummyData: dummy_3pl, std_normal\nRandom.seed!(42)\n(item_bank, question_labels, abilities, responses) = dummy_3pl(;num_questions=100, num_testees=3)","category":"page"},{"location":"examples/examples/ability_convergence_3pl/","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"Simulate a CAT for each testee and record it using CatRecorder. CatRecorder collects information which can be used to draw different types of plots.","category":"page"},{"location":"examples/examples/ability_convergence_3pl/","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"const max_questions = 99\nconst integrator = FixedGKIntegrator(-6, 6, 80)\nconst dist_ability_est = PriorAbilityEstimator(std_normal)\nconst ability_estimator = MeanAbilityEstimator(dist_ability_est, integrator)\nconst rules = CatRules(\n    ability_estimator,\n    AbilityVarianceStateCriterion(dist_ability_est, integrator),\n    FixedItemsTerminationCondition(max_questions)\n)\n\nconst points = 500\nxs = range(-2.5, 2.5, length=points)\nraw_estimator = LikelihoodAbilityEstimator()\nrecorder = CatRecorder(xs, responses, integrator, raw_estimator, ability_estimator)\nfor testee_idx in axes(responses, 2)\n    tracked_responses, θ = run_cat(\n        CatLoopConfig(\n            rules=rules,\n            get_response=auto_responder(@view responses[:, testee_idx]),\n            new_response_callback=(tracked_responses, terminating) -> recorder(tracked_responses, testee_idx, terminating),\n        ),\n        item_bank\n    )\n    true_θ = abilities[testee_idx]\n    abs_err = abs(θ - true_θ)\nend","category":"page"},{"location":"examples/examples/ability_convergence_3pl/","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"Make a plot showing how the estimated value evolves during the CAT. We also plot the 'true' values used to generate the responses.","category":"page"},{"location":"examples/examples/ability_convergence_3pl/","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"conv_lines_fig = ability_evolution_lines(recorder; abilities=abilities)\nconv_lines_fig","category":"page"},{"location":"examples/examples/ability_convergence_3pl/","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"Make an interactive plot, showing how the distribution of the ability likelihood evolves.","category":"page"},{"location":"examples/examples/ability_convergence_3pl/","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"conv_dist_fig = lh_evoluation_interactive(recorder; abilities=abilities)\nconv_dist_fig","category":"page"},{"location":"examples/examples/ability_convergence_3pl/","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"","category":"page"},{"location":"examples/examples/ability_convergence_3pl/","page":"How abilities converge on simulated 3PL data","title":"How abilities converge on simulated 3PL data","text":"This page was generated using DemoCards.jl and Literate.jl.","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"Here are the examples!","category":"page"},{"location":"examples/#Examples","page":"Examples","title":"Examples","text":"","category":"section"},{"location":"examples/","page":"Examples","title":"Examples","text":"<div class=\"list-card-section\">","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"<div class=\"list-card\">\n<table>\n  <td valign=\"bottom\"><div class=\"list-card-cover\">","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"(Image: list-card-cover-image)","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"  </div></td>\n  <td><div class=\"list-card-text\">","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"How abilities converge on simulated 3PL data","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"</div>\n    <div class=\"list-card-description\">","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"This example shows how to run a CAT based on a synthetic correct/incorrect 3PL IRT model.","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"    </div>\n  </td>\n</tbody></table>\n</div>","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"<div class=\"list-card\">\n<table>\n  <td valign=\"bottom\"><div class=\"list-card-cover\">","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"(Image: list-card-cover-image)","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"  </div></td>\n  <td><div class=\"list-card-text\">","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"How abilities converge on simulated MIRT data","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"</div>\n    <div class=\"list-card-description\">","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"This example shows how to run a CAT based on a synthetic correct/incorrect MIRT model.","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"    </div>\n  </td>\n</tbody></table>\n</div>","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"<div class=\"list-card\">\n<table>\n  <td valign=\"bottom\"><div class=\"list-card-cover\">","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"(Image: list-card-cover-image)","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"  </div></td>\n  <td><div class=\"list-card-text\">","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"Item Response Functions","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"</div>\n    <div class=\"list-card-description\">","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"Typically, the logistic c.d.f. is used as the transfer function in IRT. However, it in an IRT context, a scaled version intended to be close to a normal c.d.f. is often used. The main advantage is that this is usually faster to compute. ComputerAdaptiveTesting provides NormalScaledLogistic, which is also used by default, for this purpose:","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"    </div>\n  </td>\n</tbody></table>\n</div>","category":"page"},{"location":"examples/","page":"Examples","title":"Examples","text":"</div>","category":"page"},{"location":"examples/examples/ability_convergence_mirt/#How-abilities-converge-on-simulated-MIRT-data","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"","category":"section"},{"location":"examples/examples/ability_convergence_mirt/","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"(Image: Source code) (Image: notebook)","category":"page"},{"location":"examples/examples/ability_convergence_mirt/","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"How abilities converge on simulated MIRT data","category":"page"},{"location":"examples/examples/ability_convergence_mirt/#Running-a-CAT-based-on-a-synthetic-correct/incorrect-MIRT-model","page":"How abilities converge on simulated MIRT data","title":"Running a CAT based on a synthetic correct/incorrect MIRT model","text":"","category":"section"},{"location":"examples/examples/ability_convergence_mirt/","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"This example shows how to run a CAT based on a synthetic correct/incorrect MIRT model.","category":"page"},{"location":"examples/examples/ability_convergence_mirt/","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"Import order is important. We put ComputerAdaptiveTesting last so we get the extra dependencies.","category":"page"},{"location":"examples/examples/ability_convergence_mirt/","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"using Makie\nimport Pkg\nimport Random\nusing Distributions: Normal, cdf\nusing AlgebraOfGraphics\nusing ComputerAdaptiveTesting\nusing ComputerAdaptiveTesting.ExtraDistributions: NormalScaledLogistic\nusing ComputerAdaptiveTesting.Sim: auto_responder\nusing ComputerAdaptiveTesting.NextItemRules: DRuleItemCriterion\nusing ComputerAdaptiveTesting.TerminationConditions: FixedItemsTerminationCondition\nusing ComputerAdaptiveTesting.Aggregators: PriorAbilityEstimator, MeanAbilityEstimator, LikelihoodAbilityEstimator\nusing ComputerAdaptiveTesting.ItemBanks\nusing ComputerAdaptiveTesting.Integrators\nimport ComputerAdaptiveTesting.IntegralCoeffs\nusing CATPlots\n\n@automakie()","category":"page"},{"location":"examples/examples/ability_convergence_mirt/","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"Now we are read to generate our synthetic data using the supplied DummyData module. We generate an item bank with 100 items and fake responses for 3 testees.","category":"page"},{"location":"examples/examples/ability_convergence_mirt/","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"const dims = 3\nusing ComputerAdaptiveTesting.DummyData: dummy_mirt_4pl, std_mv_normal\nRandom.seed!(42)\n(item_bank, question_labels, abilities, responses) = dummy_mirt_4pl(dims; num_questions=10, num_testees=2)","category":"page"},{"location":"examples/examples/ability_convergence_mirt/","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"Simulate a CAT for each testee and record it using CatRecorder. CatRecorder collects information which can be used to draw different types of plots.","category":"page"},{"location":"examples/examples/ability_convergence_mirt/","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"const max_questions = 9\nconst integrator = MultiDimFixedGKIntegrator([-6.0, -6.0, -6.0], [6.0, 6.0, 6.0])\nconst ability_estimator = MeanAbilityEstimator(PriorAbilityEstimator(std_mv_normal(3)), integrator)\nconst rules = CatRules(\n    ability_estimator,\n    DRuleItemCriterion(ability_estimator),\n    FixedItemsTerminationCondition(max_questions)\n)\n\nconst points = 500\nxs = repeat(range(-2.5, 2.5, length=points)', dims, 1)\nraw_estimator = LikelihoodAbilityEstimator()\nrecorder = CatRecorder(xs, responses, integrator, raw_estimator, ability_estimator)\nfor testee_idx in axes(responses, 2)\n    @debug \"Running for testee\" testee_idx\n    tracked_responses, θ = run_cat(\n        CatLoopConfig(\n            rules=rules,\n            get_response=auto_responder(@view responses[:, testee_idx]),\n            new_response_callback=(tracked_responses, terminating) -> recorder(tracked_responses, testee_idx, terminating),\n        ),\n        item_bank\n    )\n    true_θ = abilities[testee_idx]\n    abs_err = sum(abs.(θ .- true_θ))\nend","category":"page"},{"location":"examples/examples/ability_convergence_mirt/","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"Make a plot showing how the estimated value evolves during the CAT. We also plot the 'true' values used to generate the responses.","category":"page"},{"location":"examples/examples/ability_convergence_mirt/","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"conv_lines_fig = ability_evolution_lines(recorder; abilities=abilities)\nconv_lines_fig","category":"page"},{"location":"examples/examples/ability_convergence_mirt/","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"Make an interactive plot, showing how the distribution of the ability likelihood evolves.","category":"page"},{"location":"examples/examples/ability_convergence_mirt/","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"conv_dist_fig = lh_evoluation_interactive(recorder; abilities=abilities)\nconv_dist_fig","category":"page"},{"location":"examples/examples/ability_convergence_mirt/","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"","category":"page"},{"location":"examples/examples/ability_convergence_mirt/","page":"How abilities converge on simulated MIRT data","title":"How abilities converge on simulated MIRT data","text":"This page was generated using DemoCards.jl and Literate.jl.","category":"page"},{"location":"","page":"Home","title":"Home","text":"CurrentModule = ComputerAdaptiveTesting","category":"page"},{"location":"#ComputerAdaptiveTesting","page":"Home","title":"ComputerAdaptiveTesting","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for ComputerAdaptiveTesting.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [ComputerAdaptiveTesting, ComputerAdaptiveTesting.Aggregators, ComputerAdaptiveTesting.ItemBanks, ComputerAdaptiveTesting.Postprocess, ComputerAdaptiveTesting.ConfigBase, ComputerAdaptiveTesting.Responses, ComputerAdaptiveTesting.Sim, ComputerAdaptiveTesting.TerminationConditions, ComputerAdaptiveTesting.NextItemRules, ComputerAdaptiveTesting.Integrators, ComputerAdaptiveTesting.IntegralCoeffs, ComputerAdaptiveTesting.CatConfig, CATPlots]","category":"page"}]
}