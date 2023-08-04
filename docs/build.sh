#!/bin/sh

julia --project=. ./fix_r_preferences.jl
USE_CAIRO_MAKIE=1 julia --project=. make.jl
