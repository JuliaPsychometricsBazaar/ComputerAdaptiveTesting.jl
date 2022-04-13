#!/bin/sh

julia --project ../install_pkgs.jl
julia --project make.jl
echo '[deps]' > Project.toml
