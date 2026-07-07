#=
This file contains some specialised ways to calculate information.
For some models analytical solutions are possible for information.
Most are simple applications of the chain rule
However, I haven't taken a systematic approach yet yet.
So these are just from equations in the literature.

There aren't really any type guards on these so its up to the caller to make sure they are using the right ones.
=#

function alt_expected_1d_item_information(ir::ItemResponse, θ)
    """
    This is a special case of the expected_item_information function for
        * 1-dimensional ability
        * Dichotomous items
        * It should be valid for at least up to the 3PL model, probably others too

    TODO: citation
    """
    # irθ_prime = ForwardDiff.derivative(ir, θ)
    irθ_prime = ForwardDiff.derivative(x -> resp(ir, x), θ)
    irθ = resp(ir, θ)
    if irθ_prime == 0.0
        return 0.0
    else
        return (irθ_prime * irθ_prime) / (irθ * (1 - irθ))
    end
end

function alt_expected_mirt_item_information(ir::ItemResponse, θ)
    """
    This is a special case of the expected_item_information function for
        * Multidimensional
        * Dichotomous items
        * It should be valid for at least up to the 3PL model, probably others too

    TODO: citation
    """
    irθ_prime = ForwardDiff.gradient(x -> resp(ir, x), θ)
    pθ = resp(ir, θ)
    qθ = 1 - pθ
    (irθ_prime * irθ_prime') / (pθ * qθ)
end

function alt_expected_mirt_3pl_item_information(ir::ItemResponse, θ)
    """
    This is a special case of the expected_item_information function for
        * Multidimensional
        * Dichotomous items
        * 3PL model only

    Mulder J, van der Linden WJ.
    Multidimensional Adaptive Testing with Optimal Design Criteria for Item Selection.
    Psychometrika. 2009 Jun;74(2):273-296. doi: 10.1007/s11336-008-9097-5.
    Equation 4
    """
    # XXX: Should avoid using item_params
    params = item_params(ir.item_bank.discriminations, ir.index)
    pθ = resp(ir, θ)
    qθ = 1 - pθ
    a = params.discrimination
    c = params.guess
    common_factor = (qθ * (pθ - c)^2) / (pθ * (1 - c)^2)
    common_factor * (a * a')
end
