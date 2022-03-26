module Interpolators

using Interpolations

function interp(xs, ys)
    extrapolate(
        interpolate(
            xs,
            ys,
            SteffenMonotonicInterpolation()
        ),
        Interpolations.Flat()
    )
end

end