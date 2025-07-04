"""
This calculates the pointwise information criterion for an item response model.
"""
struct ObservedInformationPointwiseItemCategoryCriterion <: PointwiseItemCategoryCriterion end

function compute_criterion(
    ::ObservedInformationPointwiseItemCategoryCriterion,
    ir::ItemResponse,
    ability,
    category
)
    actual = -double_derivative((ability -> log_resp(ir, category, ability)), ability) .* resp(ir, category, ability)
    -actual
end

function compute_criterion_vec(
    ::ObservedInformationPointwiseItemCategoryCriterion,
    ir::ItemResponse,
    ability
)
    actual = -double_derivative((ability -> log_resp_vec(ir, ability)), ability) .* resp_vec(ir, ability)
    -actual
end

function show(io::IO, ::MIME"text/plain", ::ObservedInformationPointwiseItemCategoryCriterion)
    println(io, "Observed pointwise item-category information")
end

"""
See EmpiricalInformationPointwiseItemCategoryCriterion for more details.
"""
struct RawEmpiricalInformationPointwiseItemCategoryCriterion <: PointwiseItemCategoryCriterion end

function compute_criterion(
    ::RawEmpiricalInformationPointwiseItemCategoryCriterion,
    ir::ItemResponse,
    ability,
    category
)
    actual = ForwardDiff.derivative(ability -> resp(ir, category, ability), ability) ^ 2 / resp(ir, category, ability)
    -actual
end

function compute_criterion_vec(
    ::RawEmpiricalInformationPointwiseItemCategoryCriterion,
    ir::ItemResponse,
    ability
)
    actual = ForwardDiff.derivative(ability -> resp_vec(ir, ability), ability) .^ 2 ./ resp_vec(ir, ability)
    -actual
end


function show(io::IO, ::MIME"text/plain", ::RawEmpiricalInformationPointwiseItemCategoryCriterion)
    println(io, "Raw empirical pointwise item-category information")
end

"""
In equation 10 of [1] we see that we can compute information using 2nd derivatives of log likelihood or 1st derivative squared.
For single categories, we need to an extra term which disappears when we calculate the total see [2].
For this reason
`RawEmpiricalInformationPointwiseItemCategoryCriterion`
computes without this factor, while
`EmpiricalInformationPointwiseItemCategoryCriterion`
computes with it.

So in general, only use the former with `TotalItemInformation`

[1]
``Information Functions of the Generalized Partial Credit Model''
Eiji Muraki
https://doi.org/10.1177/014662169301700403

[2]
https://mark.reid.name/blog/fisher-information-and-log-likelihood.html
"""
struct EmpiricalInformationPointwiseItemCategoryCriterion <: PointwiseItemCategoryCriterion end

function compute_criterion(
    ::EmpiricalInformationPointwiseItemCategoryCriterion,
    ir::ItemResponse,
    ability,
    category
)
    actual = -compute_criterion(
        RawEmpiricalInformationPointwiseItemCategoryCriterion(),
        ir,
        ability,
        category
    ) .- double_derivative((ability -> resp(ir, category, ability)), ability)
    -actual
end

function compute_criterion_vec(
    ::EmpiricalInformationPointwiseItemCategoryCriterion,
    ir::ItemResponse,
    ability
)
    actual = -compute_criterion_vec(
        RawEmpiricalInformationPointwiseItemCategoryCriterion(),
        ir,
        ability
    ) .- double_derivative((ability -> resp_vec(ir, ability)), ability)
    -actual
end

function show(io::IO, ::MIME"text/plain", ::EmpiricalInformationPointwiseItemCategoryCriterion)
    println(io, "Empirical pointwise item-category information")
end

#=
"""
This implements Fisher information as a pointwise item criterion.
It uses ForwardDiff to find the second derivative of the log prob for the current item and ability estimate.
It then uses the expected outcome at the given ability estimate to weight the outcomes.

\[
E_{\thetaHAT}(log(\frac{d^2 log\thetaHAT}{d\theta))
\]
"""
=#
struct TotalItemInformation{PointwiseItemCategoryCriterionT <: PointwiseItemCategoryCriterion} <: PointwiseItemCriterion
    pcic::PointwiseItemCategoryCriterionT
end

function compute_criterion(
    tii::TotalItemInformation,
    ir::ItemResponse,
    ability
)
    sum(compute_criterion_vec(tii.pcic, ir, ability))
end

function show(io::IO, ::MIME"text/plain", rule::TotalItemInformation)
    if rule.pcic isa ObservedInformationPointwiseItemCategoryCriterion
        println(io, "Observed pointwise item information")
    elseif rule.pcic isa RawEmpiricalInformationPointwiseItemCategoryCriterion
        println(io, "Raw empirical pointwise item information")
    elseif rule.pcic isa EmpiricalInformationPointwiseItemCategoryCriterion
        println(io, "Empirical pointwise item information")
    else
        print(io, "Total ")
        show(io, MIME("text/plain"), rule.pcic)
    end
end