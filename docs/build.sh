#!/bin/sh

julia --project=. ./setup_r.jl
USE_CAIRO_MAKIE=1 julia --project=. make.jl
