#!/bin/sh

julia --project ../install_pkgs.jl headless
julia --project make.jl
echo '[deps]' > Project.toml
